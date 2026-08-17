{% snapshot snap_store %}

{{
    config(
        target_schema='SILVER',
        unique_key='store_id',
        strategy='timestamp',
        updated_at='last_modified_date',
        invalidate_hard_deletes=True
    )
}}

WITH flattened_stores AS (

    SELECT
        store_item.value AS store_record,
        LOADED_AT,
        SOURCE_FILE,
        BATCH_ID

    FROM {{ ref('br_store') }},
         LATERAL FLATTEN(input => RAW_DATA:stores_data) store_item

),

processed_stores AS (

    SELECT

        store_record:store_id::STRING AS store_id,

        TRY_TO_TIMESTAMP_NTZ(
            store_record:last_modified_date::STRING
        ) AS last_modified_date,

        store_record AS raw_data,

        LOADED_AT,
        SOURCE_FILE,
        BATCH_ID

    FROM flattened_stores

)

SELECT *

FROM processed_stores

WHERE store_id IS NOT NULL
  AND TRIM(store_id) <> ''

QUALIFY ROW_NUMBER() OVER (
    PARTITION BY store_id
    ORDER BY last_modified_date DESC, LOADED_AT DESC
) = 1

{% endsnapshot %}