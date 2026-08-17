{{ config(
    materialized='table',
    schema='SILVER'
) }}

WITH source_products AS (

    SELECT

        product_id,
        last_modified_date,
        raw_data,
        LOADED_AT,
        SOURCE_FILE,
        BATCH_ID

    FROM {{ ref('snap_product') }}

),

extracted_products AS (

    SELECT

        product_id,

        last_modified_date,

        raw_data:name::STRING AS product_name,

        raw_data:short_description::STRING AS short_description,

        raw_data:technical_specs::STRING AS technical_specs,

        raw_data:category::STRING AS category,

        raw_data:subcategory::STRING AS subcategory,

        raw_data:product_line::STRING AS product_line,

        raw_data:unit_price::NUMBER(18,2) AS unit_price,

        raw_data:cost_price::NUMBER(18,2) AS cost_price,

        raw_data:stock_quantity::NUMBER AS stock_quantity,

        raw_data:reorder_level::NUMBER AS reorder_level,

        raw_data:brand::STRING AS brand,

        raw_data:color::STRING AS color,

        raw_data:dimensions::STRING AS dimensions,

        raw_data:is_featured::BOOLEAN AS is_featured,

        raw_data:launch_date::STRING AS launch_date,

        raw_data:size::STRING AS size,

        raw_data:supplier_id::STRING AS supplier_id,

        raw_data:warranty_period::STRING AS warranty_period,

        raw_data:weight::STRING AS weight,

        LOADED_AT,
        SOURCE_FILE,
        BATCH_ID,

        raw_data

    FROM source_products

),

normalized_products AS (

    SELECT

        product_id,

        last_modified_date,




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
        ) AS product_line,



        TRIM(short_description) AS short_description,

        TRIM(technical_specs) AS technical_specs,



        unit_price,

        cost_price,



        stock_quantity,

        reorder_level,


        INITCAP(
            TRIM(brand)
        ) AS brand,

        INITCAP(
            TRIM(color)
        ) AS color,

        TRIM(dimensions) AS dimensions,

        is_featured,

        TRY_TO_DATE(
            launch_date
        ) AS launch_date,

        INITCAP(
            TRIM(size)
        ) AS size,

        TRIM(supplier_id) AS supplier_id,

        TRIM(warranty_period) AS warranty_period,

        TRIM(weight) AS weight,

        LOADED_AT,
        SOURCE_FILE,
        BATCH_ID,

        raw_data

    FROM extracted_products

),

final_products AS (

    SELECT


        product_id,



        TRIM(
            CONCAT_WS(
                ' | ',
                product_name,
                short_description,
                technical_specs
            )
        ) AS product_full_description,



        product_name,

        short_description,

        technical_specs,



        TRIM(
            CONCAT_WS(
                ' > ',
                category,
                subcategory,
                product_line
            )
        ) AS product_hierarchy,

        category,

        subcategory,

        product_line,


        /* =================================================
           PROFIT MARGIN PERCENTAGE
           
           ((unit_price - cost_price) / unit_price) * 100
           
           Guard against zero / NULL unit price.
        ================================================= */

        CASE

            WHEN unit_price > 0

            THEN (
                (unit_price - cost_price)
                / unit_price
            ) * 100

            ELSE NULL

        END AS profit_margin_percentage,


        /* =================================================
           LOW STOCK FLAG
           
           TRUE when:
           stock_quantity < reorder_level
        ================================================= */

        CASE

            WHEN stock_quantity < reorder_level
            THEN TRUE

            ELSE FALSE

        END AS is_low_stock,



        unit_price,

        cost_price,

        stock_quantity,

        reorder_level,

        brand,

        color,

        dimensions,

        is_featured,

        launch_date,

        size,

        supplier_id,

        warranty_period,

        weight,

        last_modified_date,

        LOADED_AT,

        SOURCE_FILE,

        BATCH_ID,

        raw_data

    FROM normalized_products

)

SELECT *

FROM final_products

WHERE product_id IS NOT NULL
  AND TRIM(product_id) <> ''