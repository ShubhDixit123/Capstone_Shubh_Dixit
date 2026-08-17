{{ config(
    materialized='table',
    schema='SILVER'
) }}

WITH source_stores AS (

    SELECT

        store_id,
        last_modified_date,
        raw_data,
        LOADED_AT,
        SOURCE_FILE,
        BATCH_ID

    FROM {{ ref('snap_store') }}

),

extracted_stores AS (

    SELECT

        store_id,

        last_modified_date,


        raw_data:store_name::STRING AS store_name,

        raw_data:store_type::STRING AS store_type,

        raw_data:size_sq_ft::NUMBER AS size_sq_ft,

        raw_data:opening_date::STRING AS opening_date_raw,


        raw_data:address:street::STRING AS street,

        raw_data:address:city::STRING AS city,

        raw_data:address:state::STRING AS state,

        raw_data:address:zip_code::STRING AS postal_code,

        raw_data:address:country::STRING AS country,



        raw_data:current_sales::NUMBER(18,2) AS current_sales,

        raw_data:sales_target::NUMBER(18,2) AS sales_target,

        raw_data:employee_count::NUMBER AS employee_count,



        raw_data:manager_id::STRING AS manager_id,

        raw_data:monthly_rent::NUMBER(18,2) AS monthly_rent,

        raw_data:is_active::BOOLEAN AS is_active,

        raw_data:region::STRING AS region,

        raw_data:email::STRING AS email,

        raw_data:phone_number::STRING AS phone_number,

        raw_data:store_type::STRING AS store_category,

        LOADED_AT,
        SOURCE_FILE,
        BATCH_ID,

        raw_data

    FROM source_stores

),

normalized_stores AS (

    SELECT

        store_id,

        last_modified_date,



        INITCAP(
            TRIM(store_name)
        ) AS store_name,



        INITCAP(
            TRIM(store_type)
        ) AS store_type,



        size_sq_ft,



        TRY_TO_DATE(
            opening_date_raw
        ) AS opening_date,



        TRIM(street) AS street,

        INITCAP(
            TRIM(city)
        ) AS city,

        UPPER(
            TRIM(state)
        ) AS state,

        TRIM(postal_code) AS postal_code,

        INITCAP(
            TRIM(country)
        ) AS country,



        current_sales,

        sales_target,

        employee_count,



        TRIM(manager_id) AS manager_id,

        monthly_rent,

        is_active,

        INITCAP(
            TRIM(region)
        ) AS region,

        LOWER(
            TRIM(email)
        ) AS email,

        TRIM(phone_number) AS phone_number,

        LOADED_AT,

        SOURCE_FILE,

        BATCH_ID,

        raw_data

    FROM extracted_stores

),

calculated_stores AS (

    SELECT

        *,


        CASE

            WHEN opening_date IS NULL
            THEN NULL

            ELSE
                DATEDIFF(
                    'year',
                    opening_date,
                    CURRENT_DATE()
                )
                -
                IFF(
                    DATEADD(
                        'year',
                        DATEDIFF(
                            'year',
                            opening_date,
                            CURRENT_DATE()
                        ),
                        opening_date
                    ) > CURRENT_DATE(),
                    1,
                    0
                )

        END AS store_age_years,


        /* =================================================
           STORE SIZE CATEGORY

           < 5,000       = Small
           5,000-10,000  = Medium
           > 10,000      = Large
        ================================================= */

        CASE

            WHEN size_sq_ft < 5000
            THEN 'Small'

            WHEN size_sq_ft >= 5000
             AND size_sq_ft <= 10000
            THEN 'Medium'

            WHEN size_sq_ft > 10000
            THEN 'Large'

            ELSE 'Unknown'

        END AS store_size_category,


        TRIM(
            CONCAT_WS(
                ', ',

                NULLIF(
                    TRIM(street),
                    ''
                ),

                NULLIF(
                    INITCAP(TRIM(city)),
                    ''
                ),

                NULLIF(
                    UPPER(TRIM(state)),
                    ''
                ),

                NULLIF(
                    TRIM(postal_code),
                    ''
                ),

                NULLIF(
                    INITCAP(TRIM(country)),
                    ''
                )

            )
        ) AS standardized_address,


        /* =================================================
           POSTAL CODE VALIDATION
           
           US ZIP code:
           exactly 5 numeric digits
        ================================================= */

        CASE

            WHEN REGEXP_LIKE(
                TRIM(postal_code),
                '^[0-9]{5}$'
            )

            THEN TRUE

            ELSE FALSE

        END AS postal_code_is_valid

    FROM normalized_stores

),

performance_metrics AS (

    SELECT

        *,


        CASE

            WHEN sales_target > 0

            THEN (
                current_sales / sales_target
            ) * 100

            ELSE NULL

        END AS sales_target_achievement_percentage,



        CASE

            WHEN size_sq_ft > 0

            THEN current_sales / size_sq_ft

            ELSE NULL

        END AS revenue_per_sq_ft,




        CASE

            WHEN employee_count > 0

            THEN current_sales / employee_count

            ELSE NULL

        END AS employee_efficiency

    FROM calculated_stores

),

final_stores AS (

    SELECT



        store_id,

        store_name,

        store_type,



        size_sq_ft,

        store_size_category,



        opening_date,

        store_age_years,



        standardized_address,

        street,

        city,

        state,

        postal_code,

        postal_code_is_valid,

        country,




        current_sales,

        sales_target,

        sales_target_achievement_percentage,

        revenue_per_sq_ft,

        employee_count,

        employee_efficiency,


        /* =================================================
           PERFORMANCE ISSUE FLAG
           
           Achievement < 90%
        ================================================= */

        CASE

            WHEN sales_target_achievement_percentage < 90
            THEN TRUE

            ELSE FALSE

        END AS has_performance_issue,




        manager_id,

        monthly_rent,

        is_active,

        region,

        email,

        phone_number,



        last_modified_date,

        LOADED_AT,

        SOURCE_FILE,

        BATCH_ID,

        raw_data

    FROM performance_metrics

)

SELECT *

FROM final_stores

WHERE store_id IS NOT NULL
  AND TRIM(store_id) <> ''