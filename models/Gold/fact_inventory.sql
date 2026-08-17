{{ config(
    materialized='table',
    schema='GOLD'
) }}


WITH source_inventory AS (

    SELECT *

    FROM {{ ref('sl_inventory') }}

),

/* =========================================================
   COMPLETED SALES AT DAILY GRAIN PER STORE
   ========================================================= */

completed_sales_daily AS (

    SELECT

        UPPER(
            TRIM(
                order_item.value:product_id::STRING
            )
        ) AS product_id,

        UPPER(
            TRIM(
                order_snapshot.raw_data:store_id::STRING
            )
        ) AS store_id,

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

      AND order_snapshot.raw_data:store_id IS NOT NULL

      AND TRY_TO_NUMBER(
            order_item.value:quantity::STRING
          ) IS NOT NULL

    GROUP BY
        1,
        2,
        3

),

store_sales AS (

    SELECT

        inventory_record.product_id,

        inventory_record.snapshot_date,

        sales_record.store_id,

        SUM(sales_record.sold_quantity) AS sold_quantity

    FROM source_inventory inventory_record

    INNER JOIN completed_sales_daily sales_record

        ON inventory_record.product_id =
           sales_record.product_id

       AND sales_record.sold_date
           > inventory_record.previous_snapshot_date

       AND sales_record.sold_date
           <= inventory_record.snapshot_date

    GROUP BY

        inventory_record.product_id,

        inventory_record.snapshot_date,

        sales_record.store_id

),

inventory_by_store AS (

    SELECT

        inventory_record.product_id,

        inventory_record.snapshot_date,

        store_sales_record.store_id,

        inventory_record.beginning_stock,

        inventory_record.purchased_quantity,

        store_sales_record.sold_quantity,

        inventory_record.ending_stock

    FROM source_inventory inventory_record

    LEFT JOIN store_sales store_sales_record

        ON inventory_record.product_id =
           store_sales_record.product_id

       AND inventory_record.snapshot_date =
           store_sales_record.snapshot_date

),

/* =========================================================
   TOTAL PURCHASED QUANTITY PER DAY
   ========================================================= */

daily_purchase_totals AS (

    SELECT

        snapshot_date,

        SUM(
            GREATEST(
                purchased_quantity,
                0
            )
        ) AS total_purchased_all_products

    FROM source_inventory

    GROUP BY snapshot_date

),

/* =========================================================
   SUPPLIER PURCHASED QUANTITY PER DAY
   ========================================================= */

supplier_purchase_totals AS (

    SELECT

        inventory_record.snapshot_date,

        product_record.supplier_id,

        SUM(
            GREATEST(
                inventory_record.purchased_quantity,
                0
            )
        ) AS supplier_purchased_quantity

    FROM source_inventory inventory_record

    LEFT JOIN {{ ref('dim_product') }} product_record

        ON inventory_record.product_id =
           product_record.product_id

    GROUP BY

        inventory_record.snapshot_date,

        product_record.supplier_id

),

/* =========================================================
   DIMENSION ENRICHMENT
   ========================================================= */

enriched_inventory AS (

    SELECT

        inventory_record.product_id,

        inventory_record.store_id,

        inventory_record.snapshot_date,


        /* =================================================
           DIMENSION SURROGATE KEYS
        ================================================= */

        CAST(
            product_record.product_key AS VARCHAR
        ) AS product_key,

        CAST(
            date_record.date_key AS VARCHAR
        ) AS date_key,

        CAST(
            store_record.store_key AS VARCHAR
        ) AS store_key,

        CAST(
            supplier_record.supplier_key AS VARCHAR
        ) AS supplier_key,


        /* =================================================
           SUPPLIER
        ================================================= */

        product_record.supplier_id,


        /* =================================================
           INVENTORY MEASURES
        ================================================= */

        inventory_record.beginning_stock,

        inventory_record.purchased_quantity,

        COALESCE(
            inventory_record.sold_quantity,
            0
        ) AS sold_quantity,

        inventory_record.ending_stock,


        /* =================================================
           INVENTORY VALUE
        ================================================= */

        inventory_record.ending_stock
        * product_record.cost_price
            AS inventory_value

    FROM inventory_by_store inventory_record

    LEFT JOIN {{ ref('dim_product') }} product_record

        ON inventory_record.product_id =
           product_record.product_id

    LEFT JOIN {{ ref('dim_supplier') }} supplier_record

        ON product_record.supplier_id =
           supplier_record.supplier_id

    LEFT JOIN {{ ref('dim_date') }} date_record

        ON inventory_record.snapshot_date =
           date_record.full_date

    LEFT JOIN {{ ref('dim_store') }} store_record

        ON inventory_record.store_id =
           UPPER(TRIM(store_record.store_id))

),

/* =========================================================
   INVENTORY PERFORMANCE METRICS
   ========================================================= */

inventory_metrics AS (

    SELECT

        *,

        CASE

            WHEN (
                beginning_stock
                + ending_stock
            ) > 0

            THEN

                sold_quantity
                /
                (
                    (
                        beginning_stock
                        + ending_stock
                    ) / 2.0
                )

            ELSE NULL

        END AS stock_turnover_ratio

    FROM enriched_inventory

)

SELECT

    /* =====================================================
       INVENTORY SURROGATE KEY
       ===================================================== */

    CAST(
        {{ dbt_utils.generate_surrogate_key(
            [
                'inventory_metrics.product_id',
                'inventory_metrics.store_id',
                'inventory_metrics.snapshot_date'
            ]
        ) }}
        AS VARCHAR
    ) AS inventory_key,


    /* =====================================================
       DIMENSION SURROGATE KEYS
       ===================================================== */

    CAST(
        product_key AS VARCHAR
    ) AS product_key,

    CAST(
        date_key AS VARCHAR
    ) AS date_key,

    CAST(
        store_key AS VARCHAR
    ) AS store_key,

    CAST(
        supplier_key AS VARCHAR
    ) AS supplier_key,


    /* =====================================================
       INVENTORY MEASURES
       ===================================================== */

    beginning_stock AS beginning_inventory,

    purchased_quantity,

    sold_quantity,

    ending_stock AS ending_inventory,

    inventory_value,

    stock_turnover_ratio,


    /* =====================================================
       SUPPLIER CONTRIBUTION
       ===================================================== */

    ROUND(

        CASE

            WHEN daily_purchase.total_purchased_all_products > 0

            THEN

                (
                    supplier_purchase.supplier_purchased_quantity
                    /
                    daily_purchase.total_purchased_all_products
                ) * 100

            ELSE NULL

        END,

        2

    ) AS supplier_contribution_percentage

FROM inventory_metrics inventory_metrics

LEFT JOIN daily_purchase_totals daily_purchase

    ON inventory_metrics.snapshot_date =
       daily_purchase.snapshot_date

LEFT JOIN supplier_purchase_totals supplier_purchase

    ON inventory_metrics.snapshot_date =
       supplier_purchase.snapshot_date

   AND inventory_metrics.supplier_id =
       supplier_purchase.supplier_id