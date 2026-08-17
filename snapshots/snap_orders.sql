{% snapshot snap_orders %}

{{
    config(
        target_schema='SILVER',
        unique_key='order_id_clean',
        strategy='timestamp',
        updated_at='last_modified_date_clean',
        invalidate_hard_deletes=True
    )
}}

WITH flattened_orders AS (

    SELECT

        order_item.value AS order_record,

        LOADED_AT,
        SOURCE_FILE,
        BATCH_ID

    FROM {{ ref('br_orders') }},
         LATERAL FLATTEN(input => RAW_DATA:orders_data) order_item

),

parsed_orders AS (

    SELECT

        order_record:order_id::STRING AS order_identifier,

        order_record AS raw_data,

        LOADED_AT,
        SOURCE_FILE,
        BATCH_ID

    FROM flattened_orders

),

normalized_orders AS (

    SELECT

        *,

        TRIM(order_identifier) AS order_id_clean,

        LOADED_AT AS last_modified_date_clean

    FROM parsed_orders

)

SELECT *

FROM normalized_orders

WHERE order_id_clean IS NOT NULL
  AND order_id_clean <> ''

QUALIFY ROW_NUMBER() OVER (

    PARTITION BY order_id_clean

    ORDER BY LOADED_AT DESC

) = 1

{% endsnapshot %}