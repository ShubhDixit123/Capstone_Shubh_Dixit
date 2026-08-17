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



        {{ dbt_utils.generate_surrogate_key(
            ['campaign_id']
        ) }} AS campaign_key,



        campaign_id,



        campaign_name,

        campaign_type,

        channel,

        description,



        start_date,

        end_date,

        last_modified_date,



        target_audience,

        audience_segment,

        audience_age_range,

        audience_location,



        campaign_duration_days,



        budget,

        total_cost,

        total_revenue,



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