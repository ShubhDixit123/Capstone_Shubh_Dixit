{% snapshot snap_campaign %}

{{
    config(
        target_schema='SILVER',
        unique_key='campaign_id',
        strategy='timestamp',
        updated_at='last_modified_date',
        invalidate_hard_deletes=True
    )
}}

WITH flattened_campaigns AS (

    SELECT

        campaign_item.value AS campaign_record,

        LOADED_AT,
        SOURCE_FILE,
        BATCH_ID

    FROM {{ ref('br_campaign') }},

         LATERAL FLATTEN(
             input => RAW_DATA:campaigns_data
         ) campaign_item

),

processed_campaigns AS (

    SELECT

        /* =================================================
           CAMPAIGN KEY
        ================================================= */

        TRIM(
            campaign_record:campaign_id::STRING
        ) AS campaign_id,


        /* =================================================
           LAST MODIFIED DATE
        ================================================= */

        TRY_TO_TIMESTAMP_NTZ(
            campaign_record:last_modified_date::STRING
        ) AS last_modified_date,


        /* =================================================
           COMPLETE RAW CAMPAIGN RECORD
        ================================================= */

        campaign_record AS raw_data,

        LOADED_AT,

        SOURCE_FILE,

        BATCH_ID

    FROM flattened_campaigns

)

SELECT

    campaign_id,

    last_modified_date,

    raw_data,

    LOADED_AT,

    SOURCE_FILE,

    BATCH_ID

FROM processed_campaigns

WHERE campaign_id IS NOT NULL
  AND campaign_id <> ''

QUALIFY ROW_NUMBER() OVER (

    PARTITION BY campaign_id

    ORDER BY
        last_modified_date DESC,
        LOADED_AT DESC

) = 1

{% endsnapshot %}