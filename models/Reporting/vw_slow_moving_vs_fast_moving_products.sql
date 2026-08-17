
WITH product_movement AS (

    SELECT

        dp.product_id,
        dp.product_name,

        SUM(
            fi.sold_quantity
        ) AS total_sold_quantity,

        AVG(
            fi.stock_turnover_ratio
        ) AS average_stock_turnover_ratio

    FROM {{ ref('fact_inventory') }} fi

    LEFT JOIN {{ ref('dim_product') }} dp
        ON fi.product_key = dp.product_key

    GROUP BY

        dp.product_id,
        dp.product_name

)

SELECT

    product_id,
    product_name,

    total_sold_quantity,

    average_stock_turnover_ratio,

    CASE

        WHEN average_stock_turnover_ratio IS NULL
            THEN 'Unknown'

        WHEN average_stock_turnover_ratio < 1
            THEN 'Slow-Moving'

        ELSE 'Fast-Moving'

    END AS movement_category

FROM product_movement