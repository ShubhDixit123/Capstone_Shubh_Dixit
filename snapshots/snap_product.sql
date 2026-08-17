{% snapshot snap_product %}

{{
    config(
        target_schema='SILVER',
        unique_key='product_id',
        strategy='timestamp',
        updated_at='last_modified_date',
        invalidate_hard_deletes=True
    )
}}

WITH flattened_products AS (

    SELECT
        product_item.value AS product_record,
        LOADED_AT,
        SOURCE_FILE,
        BATCH_ID

    FROM {{ ref('br_product') }},
         LATERAL FLATTEN(input => RAW_DATA:products_data) product_item

),

processed_products AS (

    SELECT

        product_record:product_id::STRING AS product_id,

        TRY_TO_TIMESTAMP_NTZ(
            product_record:last_modified_date::STRING
        ) AS last_modified_date,

        product_record AS raw_data,

        LOADED_AT,
        SOURCE_FILE,
        BATCH_ID

    FROM flattened_products

)

SELECT *

FROM processed_products

WHERE product_id IS NOT NULL
  AND TRIM(product_id) <> ''

QUALIFY ROW_NUMBER() OVER (
    PARTITION BY product_id
    ORDER BY last_modified_date DESC, LOADED_AT DESC
) = 1

{% endsnapshot %}