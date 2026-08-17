
SELECT

    dd.date_key,
    dd.full_date,

    dp.product_id,
    dp.product_name,

    ds.store_id,
    ds.store_name,

    dsp.supplier_id,
    dsp.supplier_name,

    SUM(
        fi.ending_inventory
    ) AS ending_inventory,

    SUM(
        fi.inventory_value
    ) AS inventory_value

FROM {{ ref('fact_inventory') }} fi

LEFT JOIN {{ ref('dim_product') }} dp
    ON fi.product_key = dp.product_key

LEFT JOIN {{ ref('dim_store') }} ds
    ON fi.store_key = ds.store_key

LEFT JOIN {{ ref('dim_supplier') }} dsp
    ON fi.supplier_key = dsp.supplier_key

LEFT JOIN {{ ref('dim_date') }} dd
    ON fi.date_key = dd.date_key

GROUP BY

    dd.date_key,
    dd.full_date,

    dp.product_id,
    dp.product_name,

    ds.store_id,
    ds.store_name,

    dsp.supplier_id,
    dsp.supplier_name