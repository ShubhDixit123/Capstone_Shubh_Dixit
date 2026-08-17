{{ config(
    materialized='table',
    schema='GOLD'
) }}

WITH completed_orders AS (

    SELECT

        order_id,

        customer_id,

        campaign_id,

        order_date,

        line_revenue
        * (
            1 - (
                order_discount_amount / 100.0
            )
        ) AS net_sales_amount

    FROM {{ ref('sl_orders') }}

    WHERE order_status = 'completed'

),

customer_first_purchase AS (

    SELECT

        customer_id,

        MIN(order_date) AS first_purchase_date

    FROM completed_orders

    GROUP BY customer_id

),

campaign_order_activity AS (

    SELECT

        order_record.order_id,

        order_record.customer_id,

        order_record.campaign_id,

        order_record.order_date,

        order_record.net_sales_amount,

        CASE

            WHEN order_record.order_date =
                 purchase_record.first_purchase_date

            THEN TRUE

            ELSE FALSE

        END AS is_first_purchase,

        CASE

            WHEN order_record.order_date !=
                 purchase_record.first_purchase_date

            THEN TRUE

            ELSE FALSE

        END AS is_repeat_purchase

    FROM completed_orders order_record

    INNER JOIN customer_first_purchase purchase_record

        ON order_record.customer_id =
           purchase_record.customer_id

    WHERE order_record.campaign_id IS NOT NULL

),

campaign_activity_bounded AS (

    SELECT

        campaign_activity.*,

        campaign_dimension.campaign_key,

        campaign_dimension.total_cost

    FROM campaign_order_activity campaign_activity

    INNER JOIN {{ ref('dim_campaign') }} campaign_dimension

        ON campaign_activity.campaign_id =
           campaign_dimension.campaign_id

       AND campaign_dimension.dbt_valid_to IS NULL

       AND campaign_activity.order_date
           BETWEEN campaign_dimension.start_date
           AND campaign_dimension.end_date

),

daily_campaign_metrics AS (

    SELECT

        campaign_key,

        total_cost,

        CAST(
            order_date AS DATE
        ) AS activity_date,

        SUM(
            net_sales_amount
        ) AS daily_sales_influenced,

        COUNT(
            DISTINCT
            CASE
                WHEN is_first_purchase
                THEN customer_id
            END
        ) AS daily_new_customers,

        COUNT(
            DISTINCT
            CASE
                WHEN is_repeat_purchase
                THEN customer_id
            END
        ) AS daily_repeat_customers,

        COUNT(
            DISTINCT
            CASE
                WHEN is_first_purchase
                THEN customer_id
            END
        ) AS daily_first_purchase_customers

    FROM campaign_activity_bounded

    GROUP BY

        campaign_key,

        total_cost,

        CAST(
            order_date AS DATE
        )

),

campaign_cumulative_metrics AS (

    SELECT

        *,

        SUM(
            daily_sales_influenced
        ) OVER (

            PARTITION BY campaign_key

            ORDER BY activity_date

            ROWS BETWEEN
                UNBOUNDED PRECEDING
                AND CURRENT ROW

        ) AS cumulative_sales_influenced,

        SUM(
            daily_repeat_customers
        ) OVER (

            PARTITION BY campaign_key

            ORDER BY activity_date

            ROWS BETWEEN
                UNBOUNDED PRECEDING
                AND CURRENT ROW

        ) AS cumulative_repeat_customers,

        SUM(
            daily_first_purchase_customers
        ) OVER (

            PARTITION BY campaign_key

            ORDER BY activity_date

            ROWS BETWEEN
                UNBOUNDED PRECEDING
                AND CURRENT ROW

        ) AS cumulative_first_purchase_customers

    FROM daily_campaign_metrics

)

SELECT

    /* =====================================================
       MARKETING PERFORMANCE SURROGATE KEY
    ===================================================== */

    {{ dbt_utils.generate_surrogate_key(
        [
            'campaign_metrics.campaign_key',
            'campaign_metrics.activity_date'
        ]
    ) }} AS marketing_performance_key,


    /* =====================================================
       DIMENSION KEYS
    ===================================================== */

    campaign_metrics.campaign_key,

    date_dimension.date_key,


    /* =====================================================
       DAILY CAMPAIGN PERFORMANCE
    ===================================================== */

    campaign_metrics.daily_sales_influenced
        AS total_sales_influenced,

    campaign_metrics.daily_new_customers
        AS new_customers_acquired,


    /* =====================================================
       REPEAT PURCHASE RATE
    ===================================================== */

    CASE

        WHEN campaign_metrics.cumulative_first_purchase_customers > 0

        THEN ROUND(

            100.0
            * campaign_metrics.cumulative_repeat_customers
            / campaign_metrics.cumulative_first_purchase_customers,

            2

        )

        ELSE NULL

    END AS repeat_purchase_rate,


    /* =====================================================
       CAMPAIGN ROI
    ===================================================== */

    CASE

        WHEN campaign_metrics.total_cost > 0

        THEN ROUND(

            (
                campaign_metrics.cumulative_sales_influenced
                - campaign_metrics.total_cost
            )
            / campaign_metrics.total_cost
            * 100,

            2

        )

        ELSE NULL

    END AS roi

FROM campaign_cumulative_metrics campaign_metrics

LEFT JOIN {{ ref('dim_date') }} date_dimension

    ON campaign_metrics.activity_date =
       date_dimension.full_date