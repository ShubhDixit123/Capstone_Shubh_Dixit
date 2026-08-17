{{ config(
    materialized='table',
    schema='GOLD'
) }}

WITH source_suppliers AS (

    SELECT *

    FROM {{ ref('sl_supplier') }}

),

final_suppliers AS (

    SELECT

        /* =================================================
           SURROGATE KEY
        ================================================= */

        {{ dbt_utils.generate_surrogate_key(
            ['supplier_id']
        ) }} AS supplier_key,


        /* =================================================
           NATURAL KEY
        ================================================= */

        supplier_id,


        /* =================================================
           SUPPLIER DETAILS
        ================================================= */

        supplier_name,

        supplier_type,

        contact_information,

        payment_terms,


        /* =================================================
           ADDITIONAL SUPPLIER ATTRIBUTES
        ================================================= */

        credit_rating,

        is_active,

        last_order_date,

        lead_time_days,

        minimum_order_quantity,

        preferred_carrier,

        tax_id,

        website,

        year_established,

        categories_supplied,


        /* =================================================
           CONTRACT
        ================================================= */

        contract_id,

        contract_start_date,

        contract_end_date,

        contract_exclusivity,

        contract_renewal_option,


        /* =================================================
           PERFORMANCE
        ================================================= */

        average_delay_days,

        defect_rate,

        on_time_delivery_rate,

        quality_rating,

        response_time_hours,

        returns_percentage,


        /* =================================================
           METADATA
        ================================================= */

        last_modified_date,

        LOADED_AT,

        SOURCE_FILE,

        BATCH_ID

    FROM source_suppliers

    WHERE supplier_id IS NOT NULL
      AND TRIM(supplier_id) <> ''

)

SELECT *

FROM final_suppliers