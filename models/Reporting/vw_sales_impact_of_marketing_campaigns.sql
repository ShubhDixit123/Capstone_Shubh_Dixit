
SELECT

    dc.campaign_id,
    dc.campaign_name,
    dc.campaign_type,
    dc.channel,

    dc.start_date,
    dc.end_date,

    SUM(
        fmp.total_sales_influenced
    ) AS total_sales_influenced,

    SUM(
        fmp.new_customers_acquired
    ) AS new_customers_acquired,

    AVG(
        fmp.repeat_purchase_rate
    ) AS average_repeat_purchase_rate,

    AVG(
        fmp.roi
    ) AS average_roi

FROM {{ ref('fact_marketing_performance') }} fmp

LEFT JOIN {{ ref('dim_campaign') }} dc
    ON fmp.campaign_key = dc.campaign_key

GROUP BY

    dc.campaign_id,
    dc.campaign_name,
    dc.campaign_type,
    dc.channel,

    dc.start_date,
    dc.end_date