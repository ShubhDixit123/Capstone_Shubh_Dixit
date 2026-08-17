{% snapshot snap_customer %}

{{
    config(
        target_schema='SILVER',
        unique_key='customer_id',
        strategy='timestamp',
        updated_at='last_modified_date',
        invalidate_hard_deletes=True
    )
}}

WITH flattened_customers AS (

    SELECT
        customer_row.value AS customer_record,
        LOADED_AT,
        SOURCE_FILE,
        BATCH_ID

    FROM {{ ref('br_customer') }},
         LATERAL FLATTEN(input => RAW_DATA:customers_data) customer_row

),

transformed_customers AS (

    SELECT

        customer_record:customer_id::STRING AS customer_id,

        TRY_TO_TIMESTAMP_NTZ(
            customer_record:last_modified_date::STRING
        ) AS last_modified_date,

        customer_record AS raw_data,

        LOADED_AT,
        SOURCE_FILE,
        BATCH_ID

    FROM flattened_customers

)

SELECT *

FROM transformed_customers

WHERE customer_id IS NOT NULL
  AND TRIM(customer_id) <> ''

QUALIFY ROW_NUMBER() OVER (
    PARTITION BY customer_id
    ORDER BY last_modified_date DESC, LOADED_AT DESC
) = 1

{% endsnapshot %}