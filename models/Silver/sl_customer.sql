{{ config(
    materialized='table',
    schema='SILVER'
) }}

WITH source_customers AS (

    SELECT

        customer_id,
        last_modified_date,
        raw_data,
        LOADED_AT,
        SOURCE_FILE,
        BATCH_ID

    FROM {{ ref('snap_customer') }}

),

extracted_customers AS (

    SELECT

        customer_id,

        last_modified_date,

        raw_data:first_name::STRING AS first_name,

        raw_data:last_name::STRING AS last_name,

        raw_data:birth_date::STRING AS birth_date_raw,

        raw_data:email::STRING AS email_raw,

        raw_data:phone::STRING AS phone_raw,

        raw_data:address:street::STRING AS street,

        raw_data:address:city::STRING AS city,

        raw_data:address:state::STRING AS state,

        raw_data:address:zip_code::STRING AS zip_code,

        raw_data:address:country::STRING AS country,

        raw_data:income_bracket::STRING AS income_bracket,

        raw_data:loyalty_tier::STRING AS loyalty_tier,

        raw_data:marketing_opt_in::BOOLEAN AS marketing_opt_in,

        raw_data:occupation::STRING AS occupation,

        raw_data:preferred_communication::STRING AS preferred_communication,

        raw_data:preferred_payment_method::STRING AS preferred_payment_method,

        TRY_TO_DATE(
            raw_data:birth_date::STRING,
            'YYYY-MM-DD'
        ) AS birth_date_yyyy_mm_dd,

        TRY_TO_DATE(
            raw_data:birth_date::STRING,
            'DD-MM-YYYY'
        ) AS birth_date_dd_mm_yyyy,

        TRY_TO_DATE(
            raw_data:birth_date::STRING,
            'DD/MM/YYYY'
        ) AS birth_date_dd_slash_mm,

        TRY_TO_DATE(
            raw_data:birth_date::STRING,
            'MM/DD/YYYY'
        ) AS birth_date_mm_slash_dd,

        LOADED_AT,
        SOURCE_FILE,
        BATCH_ID,

        raw_data

    FROM source_customers

),

normalized_customers AS (

    SELECT

        customer_id,

        last_modified_date,

        TRIM(first_name) AS first_name_clean,

        TRIM(last_name) AS last_name_clean,

        COALESCE(
            birth_date_yyyy_mm_dd,
            birth_date_dd_mm_yyyy,
            birth_date_dd_slash_mm,
            birth_date_mm_slash_dd
        ) AS birth_date,

        LOWER(TRIM(email_raw)) AS email_id_candidate,

        REGEXP_REPLACE(
            TRIM(phone_raw),
            '[^0-9]',
            ''
        ) AS phone_digits,

        TRIM(street) AS street_clean,

        INITCAP(TRIM(city)) AS city_clean,

        UPPER(TRIM(state)) AS state_clean,

        TRIM(zip_code) AS zip_code_clean,

        INITCAP(TRIM(country)) AS country_clean,

        income_bracket,

        loyalty_tier,

        marketing_opt_in,

        TRIM(occupation) AS occupation,

        LOWER(TRIM(preferred_communication))
            AS preferred_communication,

        LOWER(TRIM(preferred_payment_method))
            AS preferred_payment_method,

        LOADED_AT,
        SOURCE_FILE,
        BATCH_ID,

        raw_data

    FROM extracted_customers

),

validated_customers AS (

    SELECT

        *,



        CASE

            WHEN email_id_candidate IS NOT NULL
             AND email_id_candidate <> ''
             AND REGEXP_LIKE(
                    email_id_candidate,
                    '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
                 )

            THEN email_id_candidate

            ELSE NULL

        END AS email_id,

        CASE

            WHEN email_id_candidate IS NOT NULL
             AND email_id_candidate <> ''
             AND REGEXP_LIKE(
                    email_id_candidate,
                    '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
                 )

            THEN TRUE

            ELSE FALSE

        END AS email_id_is_valid,



        CASE

            /* 11-digit US number beginning with 1 */
            WHEN REGEXP_LIKE(
                    phone_digits,
                    '^1[2-9][0-9]{9}$'
                 )

            THEN SUBSTR(phone_digits, 2)

            /* Standard 10-digit US number */
            WHEN REGEXP_LIKE(
                    phone_digits,
                    '^[2-9][0-9]{9}$'
                 )

            THEN phone_digits

            ELSE NULL

        END AS phn_no,

        CASE

            WHEN REGEXP_LIKE(
                    phone_digits,
                    '^1[2-9][0-9]{9}$'
                 )
              OR REGEXP_LIKE(
                    phone_digits,
                    '^[2-9][0-9]{9}$'
                 )

            THEN TRUE

            ELSE FALSE

        END AS phn_no_is_valid

    FROM normalized_customers

),

final_customers AS (

    SELECT


        customer_id,



        TRIM(
            CONCAT(
                COALESCE(first_name_clean, ''),
                ' ',
                COALESCE(last_name_clean, '')
            )
        ) AS full_name,

        first_name_clean AS first_name,

        last_name_clean AS last_name,



        birth_date,




        CASE

            WHEN birth_date IS NULL THEN NULL

            ELSE
                DATEDIFF(
                    'year',
                    birth_date,
                    CURRENT_DATE()
                )
                -
                IFF(
                    DATEADD(
                        'year',
                        DATEDIFF(
                            'year',
                            birth_date,
                            CURRENT_DATE()
                        ),
                        birth_date
                    ) > CURRENT_DATE(),
                    1,
                    0
                )

        END AS customer_age,


        /* =================================================
           CUSTOMER SEGMENT
           18-35  = Young
           36-55  = Middle-aged
           56+    = Senior
        ================================================= */

        CASE

            WHEN birth_date IS NULL THEN 'Unknown'

            WHEN
                (
                    DATEDIFF(
                        'year',
                        birth_date,
                        CURRENT_DATE()
                    )
                    -
                    IFF(
                        DATEADD(
                            'year',
                            DATEDIFF(
                                'year',
                                birth_date,
                                CURRENT_DATE()
                            ),
                            birth_date
                        ) > CURRENT_DATE(),
                        1,
                        0
                    )
                ) BETWEEN 18 AND 35
            THEN 'Young'

            WHEN
                (
                    DATEDIFF(
                        'year',
                        birth_date,
                        CURRENT_DATE()
                    )
                    -
                    IFF(
                        DATEADD(
                            'year',
                            DATEDIFF(
                                'year',
                                birth_date,
                                CURRENT_DATE()
                            ),
                            birth_date
                        ) > CURRENT_DATE(),
                        1,
                        0
                    )
                ) BETWEEN 36 AND 55
            THEN 'Middle-aged'

            WHEN
                (
                    DATEDIFF(
                        'year',
                        birth_date,
                        CURRENT_DATE()
                    )
                    -
                    IFF(
                        DATEADD(
                            'year',
                            DATEDIFF(
                                'year',
                                birth_date,
                                CURRENT_DATE()
                            ),
                            birth_date
                        ) > CURRENT_DATE(),
                        1,
                        0
                    )
                ) >= 56
            THEN 'Senior'

            ELSE 'Under 18'

        END AS customer_segment,



        TRIM(
            CONCAT(
                COALESCE(street_clean, ''),
                IFF(
                    street_clean IS NOT NULL
                    AND city_clean IS NOT NULL,
                    ', ',
                    ''
                ),
                COALESCE(city_clean, ''),
                IFF(
                    city_clean IS NOT NULL
                    AND state_clean IS NOT NULL,
                    ', ',
                    ''
                ),
                COALESCE(state_clean, ''),
                IFF(
                    state_clean IS NOT NULL
                    AND zip_code_clean IS NOT NULL,
                    ' ',
                    ''
                ),
                COALESCE(zip_code_clean, ''),
                IFF(
                    (
                        street_clean IS NOT NULL
                        OR city_clean IS NOT NULL
                        OR state_clean IS NOT NULL
                        OR zip_code_clean IS NOT NULL
                    )
                    AND country_clean IS NOT NULL,
                    ', ',
                    ''
                ),
                COALESCE(country_clean, '')
            )
        ) AS standardized_address,

        street_clean AS street,

        city_clean AS city,

        state_clean AS state,

        zip_code_clean AS zip_code,

        country_clean AS country,



        email_id,

        email_id_is_valid,




        phn_no,

        phn_no_is_valid,



        income_bracket,

        loyalty_tier,

        marketing_opt_in,

        occupation,

        preferred_communication,

        preferred_payment_method,

        last_modified_date,

        LOADED_AT,

        SOURCE_FILE,

        BATCH_ID,

        raw_data

    FROM validated_customers

)

SELECT *

FROM final_customers

WHERE customer_id IS NOT NULL
  AND TRIM(customer_id) <> ''