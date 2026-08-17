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

        /* =================================================
           SURROGATE KEY
        ================================================= */

        {{ dbt_utils.generate_surrogate_key(
            ['customer_id']
        ) }} AS customer_key,


        /* =================================================
           NATURAL KEY
        ================================================= */

        customer_id,


        /* =================================================
           CUSTOMER NAME
        ================================================= */

        full_name,

        first_name,

        last_name,


        /* =================================================
           CUSTOMER DEMOGRAPHICS
        ================================================= */

        birth_date,

        customer_age,

        customer_segment,


        /* =================================================
           ADDRESS
        ================================================= */

        standardized_address,

        street,

        city,

        state,

        zip_code,

        country,


        /* =================================================
           CONTACT INFORMATION
        ================================================= */

        email_id,

        email_id_is_valid,

        phn_no,

        phn_no_is_valid,


        /* =================================================
           CUSTOMER ATTRIBUTES
        ================================================= */

        income_bracket,

        loyalty_tier,

        marketing_opt_in,

        occupation,

        preferred_communication,

        preferred_payment_method,


        /* =================================================
           AUDIT / METADATA
        ================================================= */

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