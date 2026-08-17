
SELECT

    dc.campaign_type,

    COUNT(
        DISTINCT dc.campaign_id
    ) AS campaign_count,

    SUM(
        fmp.total_sales_influenced
    ) AS total_sales_influenced,

    AVG(
        fmp.roi
    ) AS average_roi

FROM {{ ref('fact_marketing_performance') }} fmp

LEFT JOIN {{ ref('dim_campaign') }} dc
    ON fmp.campaign_key = dc.campaign_key

GROUP BY

    dc.campaign_type