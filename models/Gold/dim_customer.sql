{{ config(
    materialized='table',
    schema='GOLD'
) }}

WITH source_customer AS (

    SELECT *

    FROM {{ ref('sl_customer') }}

),

customer_dimension AS (

    SELECT


        {{ dbt_utils.generate_surrogate_key(
            ['customer_id']
        ) }} AS customer_key,




        customer_id,



        full_name,

        first_name,

        last_name,


        birth_date,

        customer_age,

        customer_segment,



        standardized_address,

        street,

        city,

        state,

        zip_code,

        country,



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

        loaded_at,

        source_file,

        batch_id,

        raw_data

    FROM source_customer

    WHERE customer_id IS NOT NULL

      AND TRIM(customer_id) <> ''

)

SELECT *

FROM customer_dimension