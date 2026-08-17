{{ config(
    materialized='table',
    schema='GOLD'
) }}

WITH source_products AS (

    SELECT *

    FROM {{ ref('sl_product') }}

),

final_products AS (

    SELECT

        /* =================================================
           SURROGATE KEY
        ================================================= */

        {{ dbt_utils.generate_surrogate_key(
            ['product_id']
        ) }} AS product_key,


        /* =================================================
           NATURAL KEY
        ================================================= */

        product_id,


        /* =================================================
           PRODUCT DETAILS
        ================================================= */

        INITCAP(
            TRIM(product_name)
        ) AS product_name,

        INITCAP(
            TRIM(category)
        ) AS category,

        INITCAP(
            TRIM(subcategory)
        ) AS subcategory,

        INITCAP(
            TRIM(product_line)
        ) AS brand,

        INITCAP(
            TRIM(color)
        ) AS color,

        TRIM(size) AS size,


        /* =================================================
           PRICING
        ================================================= */

        unit_price,

        cost_price,


        /* =================================================
           SUPPLIER INFORMATION
        ================================================= */

        supplier_id,


        /* =================================================
           METADATA
        ================================================= */

        last_modified_date,

        LOADED_AT,

        SOURCE_FILE,

        BATCH_ID

    FROM source_products

    WHERE product_id IS NOT NULL
      AND TRIM(product_id) <> ''

)

SELECT *

FROM final_products