{{ config(
    materialized='table',
    schema='SILVER'
) }}

WITH flattened_products AS (

    SELECT

        UPPER(
            TRIM(
                product_record.value:product_id::STRING
            )
        ) AS product_id,

        TRY_TO_NUMBER(
            product_record.value:stock_quantity::STRING
        ) AS stock_quantity,

        TRY_TO_NUMBER(
            product_record.value:reorder_level::STRING
        ) AS reorder_level,

        TRY_TO_DATE(
            REGEXP_SUBSTR(
                SOURCE_FILE,
                '[0-9]{4}-[0-9]{2}-[0-9]{2}'
            )
        ) AS snapshot_date,

        SOURCE_FILE,

        ROW_NUMBER,

        LOADED_AT,

        BATCH_ID

    FROM {{ ref('br_product') }},

         LATERAL FLATTEN(
             INPUT => RAW_DATA:products_data
         ) product_record

),

deduplicated_snapshots AS (

    SELECT *

    FROM flattened_products

    WHERE product_id IS NOT NULL
      AND snapshot_date IS NOT NULL

    QUALIFY ROW_NUMBER() OVER (

        PARTITION BY
            product_id,
            snapshot_date

        ORDER BY
            LOADED_AT DESC,
            SOURCE_FILE DESC,
            ROW_NUMBER DESC

    ) = 1

),

product_stock_history AS (

    SELECT

        product_id,

        snapshot_date,

        reorder_level,

        stock_quantity AS ending_stock,

        LAG(snapshot_date) OVER (
            PARTITION BY product_id
            ORDER BY snapshot_date
        ) AS previous_snapshot_date,

        LAG(stock_quantity) OVER (
            PARTITION BY product_id
            ORDER BY snapshot_date
        ) AS beginning_stock,

        SOURCE_FILE,

        ROW_NUMBER,

        LOADED_AT,

        BATCH_ID

    FROM deduplicated_snapshots

),

stock_intervals AS (

    SELECT

        product_id,

        snapshot_date,

        previous_snapshot_date,

        beginning_stock,

        ending_stock,

        reorder_level,

        DATEDIFF(
            DAY,
            previous_snapshot_date,
            snapshot_date
        ) AS days_since_last_snapshot,

        SOURCE_FILE,

        ROW_NUMBER,

        LOADED_AT,

        BATCH_ID

    FROM product_stock_history

),


completed_sales AS (

    SELECT

        UPPER(
            TRIM(
                order_item.value:product_id::STRING
            )
        ) AS product_id,

        TRY_TO_TIMESTAMP_NTZ(
            order_snapshot.raw_data:order_date::STRING
        )::DATE AS sold_date,

        SUM(
            TRY_TO_NUMBER(
                order_item.value:quantity::STRING
            )
        ) AS sold_quantity

    FROM {{ ref('snap_orders') }} order_snapshot,

         LATERAL FLATTEN(
             INPUT => order_snapshot.raw_data:order_items
         ) order_item

    WHERE order_snapshot.dbt_valid_to IS NULL

      AND UPPER(
            TRIM(
                COALESCE(
                    order_snapshot.raw_data:status::STRING,
                    order_snapshot.raw_data:order_status::STRING
                )
            )
          ) = 'COMPLETED'

      AND order_item.value:product_id IS NOT NULL

      AND TRY_TO_NUMBER(
            order_item.value:quantity::STRING
          ) IS NOT NULL

    GROUP BY
        1,
        2

),


interval_sales AS (

    SELECT

        stock_interval.product_id,

        stock_interval.snapshot_date,

        stock_interval.previous_snapshot_date,

        stock_interval.beginning_stock,

        stock_interval.ending_stock,

        stock_interval.reorder_level,

        stock_interval.days_since_last_snapshot,

        stock_interval.SOURCE_FILE,

        stock_interval.ROW_NUMBER,

        stock_interval.LOADED_AT,

        stock_interval.BATCH_ID,

        SUM(
            COALESCE(
                completed_sale.sold_quantity,
                0
            )
        ) AS sold_quantity

    FROM stock_intervals stock_interval

    LEFT JOIN completed_sales completed_sale

        ON stock_interval.product_id = completed_sale.product_id

       AND completed_sale.sold_date
           > stock_interval.previous_snapshot_date

       AND completed_sale.sold_date
           <= stock_interval.snapshot_date

    GROUP BY

        stock_interval.product_id,

        stock_interval.snapshot_date,

        stock_interval.previous_snapshot_date,

        stock_interval.beginning_stock,

        stock_interval.ending_stock,

        stock_interval.reorder_level,

        stock_interval.days_since_last_snapshot,

        stock_interval.SOURCE_FILE,

        stock_interval.ROW_NUMBER,

        stock_interval.LOADED_AT,

        stock_interval.BATCH_ID

)

SELECT

    product_id,

    snapshot_date,

    previous_snapshot_date,

    beginning_stock,

    ending_stock,

    sold_quantity,

    (
        ending_stock
        - COALESCE(
            beginning_stock,
            ending_stock
        )
        + sold_quantity
    ) AS purchased_quantity,

    CASE

        WHEN ending_stock IS NOT NULL
         AND reorder_level IS NOT NULL
         AND ending_stock < reorder_level

        THEN TRUE

        ELSE FALSE

    END AS low_stock_flag,

    CASE

        WHEN days_since_last_snapshot > 1

        THEN TRUE

        ELSE FALSE

    END AS stale_snapshot_flag,

    days_since_last_snapshot,

    CASE

        WHEN ending_stock < 0
          OR beginning_stock < 0

        THEN TRUE

        ELSE FALSE

    END AS negative_balance_flag,

    reorder_level,

    SOURCE_FILE,

    ROW_NUMBER,

    LOADED_AT,

    BATCH_ID

FROM interval_sales

WHERE beginning_stock IS NOT NULL