{{ config(
    materialized='table',
    schema='SILVER'
) }}

WITH source_campaigns AS (

    SELECT *

    FROM {{ ref('snap_campaign') }}

    /* Current active campaign version */

    WHERE dbt_valid_to IS NULL

),

processed_campaigns AS (

    SELECT


        TRIM(
            campaign_id
        ) AS campaign_id,



        TRIM(
            raw_data:campaign_name::STRING
        ) AS campaign_name,

        INITCAP(
            TRIM(
                raw_data:campaign_type::STRING
            )
        ) AS campaign_type,

        INITCAP(
            TRIM(
                raw_data:channel::STRING
            )
        ) AS channel,

        TRIM(
            raw_data:description::STRING
        ) AS description,



        TRY_TO_TIMESTAMP_NTZ(
            raw_data:start_date::STRING
        ) AS start_date,

        TRY_TO_TIMESTAMP_NTZ(
            raw_data:end_date::STRING
        ) AS end_date,

        TRY_TO_TIMESTAMP_NTZ(
            raw_data:last_modified_date::STRING
        ) AS last_modified_date,



        TRIM(
            raw_data:target_audience::STRING
        ) AS target_audience,



        TRY_TO_DECIMAL(
            REGEXP_REPLACE(
                TRIM(
                    raw_data:budget::STRING
                ),
                '[$,]',
                ''
            ),
            18,
            2
        ) AS budget,



        TRY_TO_DECIMAL(
            REGEXP_REPLACE(
                TRIM(
                    raw_data:total_cost::STRING
                ),
                '[$,]',
                ''
            ),
            18,
            2
        ) AS total_cost,



        TRY_TO_DECIMAL(
            REGEXP_REPLACE(
                TRIM(
                    raw_data:total_revenue::STRING
                ),
                '[$,]',
                ''
            ),
            18,
            2
        ) AS total_revenue,



        TRY_TO_DECIMAL(
            TRIM(
                raw_data:roi_calculation::STRING
            ),
            18,
            4
        ) AS roi_calculation,



        LOADED_AT,

        SOURCE_FILE,

        BATCH_ID,

        dbt_valid_from,

        dbt_valid_to

    FROM source_campaigns

),

final_campaigns AS (

    SELECT

        processed_campaigns.*,



        CASE

            WHEN start_date IS NOT NULL
             AND end_date IS NOT NULL

            THEN DATEDIFF(
                DAY,
                start_date,
                end_date
            )

            ELSE NULL

        END AS campaign_duration_days,



        INITCAP(
            TRIM(
                SPLIT_PART(
                    target_audience,
                    ',',
                    1
                )
            )
        ) AS audience_segment,



        TRIM(
            SPLIT_PART(
                target_audience,
                ',',
                2
            )
        ) AS audience_age_range,



        INITCAP(
            TRIM(
                SPLIT_PART(
                    target_audience,
                    ',',
                    3
                )
            )
        ) AS audience_location

    FROM processed_campaigns

)

SELECT *

FROM final_campaigns