
SELECT

    dp.category,

    dsp.supplier_id,
    dsp.supplier_name,

    SUM(
        fi.purchased_quantity
    ) AS purchased_quantity,

    (
        SUM(fi.purchased_quantity)
        /
        NULLIF(
            SUM(
                SUM(fi.purchased_quantity)
            ) OVER (
                PARTITION BY dp.category
            ),
            0
        )
    ) * 100 AS supplier_contribution_percentage

FROM {{ ref('fact_inventory') }} fi

LEFT JOIN {{ ref('dim_product') }} dp
    ON fi.product_key = dp.product_key

LEFT JOIN {{ ref('dim_supplier') }} dsp
    ON fi.supplier_key = dsp.supplier_key

GROUP BY

    dp.category,

    dsp.supplier_id,
    dsp.supplier_name