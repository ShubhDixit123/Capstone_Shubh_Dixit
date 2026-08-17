{{ config(
    materialized='table',
    schema='GOLD'
) }}

WITH source_campaigns AS (

    SELECT *

    FROM {{ ref('sl_campaign') }}

),

final_campaigns AS (

    SELECT

        /* =================================================
           SURROGATE KEY
        ================================================= */

        {{ dbt_utils.generate_surrogate_key(
            ['campaign_id']
        ) }} AS campaign_key,


        /* =================================================
           NATURAL KEY
        ================================================= */

        campaign_id,


        /* =================================================
           CAMPAIGN DETAILS
        ================================================= */

        campaign_name,

        campaign_type,

        channel,

        description,


        /* =================================================
           CAMPAIGN DATES
        ================================================= */

        start_date,

        end_date,

        last_modified_date,


        /* =================================================
           AUDIENCE
        ================================================= */

        target_audience,

        audience_segment,

        audience_age_range,

        audience_location,


        /* =================================================
           CAMPAIGN DURATION
        ================================================= */

        campaign_duration_days,


        /* =================================================
           FINANCIAL ATTRIBUTES
        ================================================= */

        budget,

        total_cost,

        total_revenue,


        /* =================================================
           METADATA
        ================================================= */

        LOADED_AT,

        SOURCE_FILE,

        BATCH_ID,

        dbt_valid_from,

        dbt_valid_to

    FROM source_campaigns

    WHERE campaign_id IS NOT NULL
      AND TRIM(campaign_id) <> ''

)

SELECT *

FROM final_campaigns