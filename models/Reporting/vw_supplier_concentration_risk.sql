WITH supplier_purchases AS (

    SELECT

        dsp.supplier_id,
        dsp.supplier_name,

        SUM(
            fi.purchased_quantity
        ) AS purchased_quantity

    FROM {{ ref('fact_inventory') }} fi

    LEFT JOIN {{ ref('dim_supplier') }} dsp
        ON fi.supplier_key = dsp.supplier_key

    GROUP BY

        dsp.supplier_id,
        dsp.supplier_name

),

supplier_share AS (

    SELECT

        supplier_id,
        supplier_name,

        purchased_quantity,

        (
            purchased_quantity
            /
            NULLIF(
                SUM(purchased_quantity) OVER (),
                0
            )
        ) * 100 AS purchase_share_percentage

    FROM supplier_purchases

)

SELECT

    supplier_id,
    supplier_name,

    purchased_quantity,

    ROUND(
        purchase_share_percentage,
        2
    ) AS purchase_share_percentage,

    ROUND(
        POWER(purchase_share_percentage, 2),
        2
    ) AS hhi_contribution,

    CASE

        WHEN purchase_share_percentage >= 50
            THEN 'High Risk'

        WHEN purchase_share_percentage >= 25
            THEN 'Medium Risk'

        ELSE 'Low Risk'

    END AS concentration_risk

FROM supplier_share