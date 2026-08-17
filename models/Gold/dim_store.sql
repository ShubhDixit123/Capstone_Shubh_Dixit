{{ config(
    materialized='table',
    schema='GOLD'
) }}

WITH source_stores AS (

    SELECT *

    FROM {{ ref('sl_store') }}

),

final_stores AS (

    SELECT

        /* =================================================
           SURROGATE KEY
        ================================================= */

        {{ dbt_utils.generate_surrogate_key(
            ['store_id']
        ) }} AS store_key,


        /* =================================================
           NATURAL KEY
        ================================================= */

        store_id,


        /* =================================================
           STORE DETAILS
        ================================================= */

        store_name,

        standardized_address AS address,

        region,

        store_type,

        opening_date,

        store_size_category AS size_category,


        /* =================================================
           STORE METRICS
        ================================================= */

        size_sq_ft,

        store_age_years,

        current_sales,

        sales_target,

        sales_target_achievement_percentage,

        revenue_per_sq_ft,

        employee_count,

        employee_efficiency,

        has_performance_issue,


        /* =================================================
           METADATA
        ================================================= */

        last_modified_date,

        LOADED_AT,

        SOURCE_FILE,

        BATCH_ID

    FROM source_stores

    WHERE store_id IS NOT NULL
      AND TRIM(store_id) <> ''

)

SELECT *

FROM final_stores