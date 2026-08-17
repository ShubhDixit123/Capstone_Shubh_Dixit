SELECT

    dd.date_key,
    dd.full_date,

    dp.product_id,
    dp.product_name,

    ds.store_id,
    ds.store_name,

    SUM(fi.beginning_inventory) AS total_beginning_inventory,

    SUM(fi.ending_inventory) AS total_ending_inventory,

    fi.stock_turnover_ratio

FROM {{ ref('fact_inventory') }} fi

LEFT JOIN {{ ref('dim_product') }} dp
    ON fi.product_key = dp.product_key

LEFT JOIN {{ ref('dim_store') }} ds
    ON fi.store_key = ds.store_key

LEFT JOIN {{ ref('dim_date') }} dd
    ON fi.date_key = dd.date_key

GROUP BY

    dd.date_key,
    dd.full_date,

    dp.product_id,
    dp.product_name,

    ds.store_id,
    ds.store_name,

    fi.stock_turnover_ratio 