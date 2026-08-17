{{ config(
    materialized='table',
    schema='SILVER'
) }}

WITH source_orders AS (

    SELECT

        order_id_clean AS order_id,

        raw_data,

        last_modified_date_clean,

        LOADED_AT,

        SOURCE_FILE,

        BATCH_ID

    FROM {{ ref('snap_orders') }}

),

order_details AS (

    SELECT

        order_id,

        last_modified_date_clean,

        LOADED_AT,

        SOURCE_FILE,

        BATCH_ID,

        raw_data:customer_id::STRING AS customer_id,

        raw_data:employee_id::STRING AS employee_id,

        raw_data:store_id::STRING AS store_id,

        raw_data:campaign_id::STRING AS campaign_id,

        raw_data:order_status::STRING AS order_status,

        raw_data:order_source::STRING AS order_source,

        raw_data:payment_method::STRING AS payment_method,

        raw_data:shipping_method::STRING AS shipping_method,

        TRY_TO_TIMESTAMP_NTZ(
            raw_data:created_at::STRING
        ) AS created_at,

        TRY_TO_TIMESTAMP_NTZ(
            raw_data:order_date::STRING
        ) AS order_date,

        TRY_TO_TIMESTAMP_NTZ(
            raw_data:shipping_date::STRING
        ) AS shipping_date,

        TRY_TO_TIMESTAMP_NTZ(
            raw_data:delivery_date::STRING
        ) AS delivery_date,

        TRY_TO_TIMESTAMP_NTZ(
            raw_data:estimated_delivery_date::STRING
        ) AS estimated_delivery_date,

        TRY_TO_NUMBER(
            raw_data:discount_amount::STRING
        ) AS order_discount_amount,

        TRY_TO_NUMBER(
            raw_data:shipping_cost::STRING
        ) AS shipping_cost,

        TRY_TO_NUMBER(
            raw_data:tax_amount::STRING
        ) AS tax_amount,

        TRY_TO_NUMBER(
            raw_data:total_amount::STRING
        ) AS source_total_amount,

        raw_data:billing_address:street::STRING
            AS billing_street,

        raw_data:billing_address:city::STRING
            AS billing_city,

        raw_data:billing_address:state::STRING
            AS billing_state,

        raw_data:billing_address:zip_code::STRING
            AS billing_zip_code,

        raw_data:shipping_address:street::STRING
            AS shipping_street,

        raw_data:shipping_address:city::STRING
            AS shipping_city,

        raw_data:shipping_address:state::STRING
            AS shipping_state,

        raw_data:shipping_address:zip_code::STRING
            AS shipping_zip_code,

        raw_data

    FROM source_orders

),

order_items_flattened AS (

    SELECT

        od.order_id,

        od.last_modified_date_clean,

        od.LOADED_AT,

        od.SOURCE_FILE,

        od.BATCH_ID,

        od.customer_id,

        od.employee_id,

        od.store_id,

        od.campaign_id,

        od.order_status,

        od.order_source,

        od.payment_method,

        od.shipping_method,

        od.created_at,

        od.order_date,

        od.shipping_date,

        od.delivery_date,

        od.estimated_delivery_date,

        od.order_discount_amount,

        od.shipping_cost,

        od.tax_amount,

        od.source_total_amount,

        od.billing_street,

        od.billing_city,

        od.billing_state,

        od.billing_zip_code,

        od.shipping_street,

        od.shipping_city,

        od.shipping_state,

        od.shipping_zip_code,

        item.value:product_id::STRING AS product_id,

        TRY_TO_NUMBER(
            item.value:quantity::STRING
        ) AS quantity,

        TRY_TO_NUMBER(
            item.value:unit_price::STRING
        ) AS unit_price,

        TRY_TO_NUMBER(
            item.value:cost_price::STRING
        ) AS cost_price,

        TRY_TO_NUMBER(
            item.value:discount_amount::STRING
        ) AS item_discount_amount,

        od.raw_data

    FROM order_details od,

         LATERAL FLATTEN(
             input => od.raw_data:order_items
         ) item

),

calculated_line_items AS (

    SELECT

        *,

        /*
         * discount_amount is a RATE/FRACTION.
         * Therefore it is applied multiplicatively.
         */

        quantity
        * unit_price
        * (1 - item_discount_amount)
            AS line_item_revenue,

        quantity
        * cost_price
            AS line_item_cost

    FROM order_items_flattened

),

order_level_aggregation AS (

    SELECT

        order_id,

        MAX(last_modified_date_clean)
            AS last_modified_date,

        MAX(LOADED_AT)
            AS LOADED_AT,

        MAX(SOURCE_FILE)
            AS SOURCE_FILE,

        MAX(BATCH_ID)
            AS BATCH_ID,

        MAX(customer_id)
            AS customer_id,

        MAX(employee_id)
            AS employee_id,

        MAX(store_id)
            AS store_id,

        MAX(campaign_id)
            AS campaign_id,

        MAX(order_status)
            AS order_status,

        MAX(order_source)
            AS order_source,

        MAX(payment_method)
            AS payment_method,

        MAX(shipping_method)
            AS shipping_method,

        MAX(created_at)
            AS created_at,

        MAX(order_date)
            AS order_date,

        MAX(shipping_date)
            AS shipping_date,

        MAX(delivery_date)
            AS delivery_date,

        MAX(estimated_delivery_date)
            AS estimated_delivery_date,

        MAX(order_discount_amount)
            AS order_discount_amount,

        MAX(shipping_cost)
            AS shipping_cost,

        MAX(tax_amount)
            AS tax_amount,

        MAX(source_total_amount)
            AS source_total_amount,

        MAX(billing_street)
            AS billing_street,

        MAX(billing_city)
            AS billing_city,

        MAX(billing_state)
            AS billing_state,

        MAX(billing_zip_code)
            AS billing_zip_code,

        MAX(shipping_street)
            AS shipping_street,

        MAX(shipping_city)
            AS shipping_city,

        MAX(shipping_state)
            AS shipping_state,

        MAX(shipping_zip_code)
            AS shipping_zip_code,

        /*
         * Order-item aggregation
         */

        COUNT(product_id)
            AS total_items,

        SUM(quantity)
            AS total_quantity,

        SUM(
            quantity * unit_price
        )
            AS total_amount_before_item_discount,

        SUM(line_item_revenue)
            AS line_revenue,

        SUM(line_item_cost)
            AS line_cost,

        SUM(item_discount_amount)
            AS total_discount,

        MAX(raw_data)
            AS raw_data

    FROM calculated_line_items

    GROUP BY order_id

),

order_profitability AS (

    SELECT

        *,

        /*
         * Order discount is also a RATE/FRACTION.
         * Apply it multiplicatively after line revenue.
         */

        (
            line_revenue
            * (1 - order_discount_amount)
        )
        - line_cost
        - shipping_cost
        - tax_amount
            AS profit_amount

    FROM order_level_aggregation

),

final_orders AS (

    SELECT


        order_id,

        customer_id,

        employee_id,

        store_id,

        campaign_id,


        order_status,

        order_source,

        payment_method,

        shipping_method,

        created_at,

        order_date,

        shipping_date,

        delivery_date,

        estimated_delivery_date,


        /* =================================================
           ORDER TIME OF DAY
           
           Half-open ranges:
           
           05 <= hour < 12  = Morning
           12 <= hour < 17  = Afternoon
           17 <= hour < 22  = Evening
           Otherwise         = Night
        ================================================= */

        EXTRACT(
            HOUR FROM order_date
        ) AS order_hour,

        CASE

            WHEN EXTRACT(
                    HOUR FROM order_date
                 ) >= 5
             AND EXTRACT(
                    HOUR FROM order_date
                 ) < 12

            THEN 'Morning'

            WHEN EXTRACT(
                    HOUR FROM order_date
                 ) >= 12
             AND EXTRACT(
                    HOUR FROM order_date
                 ) < 17

            THEN 'Afternoon'

            WHEN EXTRACT(
                    HOUR FROM order_date
                 ) >= 17
             AND EXTRACT(
                    HOUR FROM order_date
                 ) < 22

            THEN 'Evening'

            ELSE 'Night'

        END AS order_time_of_day,




        EXTRACT(
            WEEK FROM order_date
        ) AS order_week,

        EXTRACT(
            MONTH FROM order_date
        ) AS order_month,

        EXTRACT(
            QUARTER FROM order_date
        ) AS order_quarter,

        EXTRACT(
            YEAR FROM order_date
        ) AS order_year,



        total_items,

        total_quantity,

        total_amount_before_item_discount,

        line_revenue,

        line_cost,

        total_discount,

        order_discount_amount,



        profit_amount,

        CASE

            WHEN line_revenue > 0

            THEN (
                profit_amount / line_revenue
            ) * 100

            ELSE NULL

        END AS profit_margin_percentage,




        shipping_cost,

        tax_amount,

        source_total_amount,




        DATEDIFF(
            DAY,
            order_date,
            shipping_date
        ) AS processing_days,

        DATEDIFF(
            DAY,
            shipping_date,
            delivery_date
        ) AS shipping_days,



        CASE

            WHEN delivery_date IS NOT NULL
             AND delivery_date <= estimated_delivery_date

            THEN 'On Time'

            WHEN delivery_date IS NOT NULL
             AND delivery_date > estimated_delivery_date

            THEN 'Delayed'

            WHEN delivery_date IS NULL
             AND CURRENT_DATE() > estimated_delivery_date

            THEN 'Potentially Delayed'

            ELSE 'In Transit'

        END AS delivery_status,



        billing_street,

        billing_city,

        billing_state,

        billing_zip_code,



        shipping_street,

        shipping_city,

        shipping_state,

        shipping_zip_code,




        last_modified_date,

        LOADED_AT,

        SOURCE_FILE,

        BATCH_ID,

        raw_data

    FROM order_profitability

)

SELECT *

FROM final_orders

WHERE order_id IS NOT NULL
  AND TRIM(order_id) <> ''