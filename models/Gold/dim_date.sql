{{ config(
    materialized='table',
    schema='GOLD'
) }}

WITH date_spine AS (

    {{ dbt_utils.date_spine(
        datepart='day',
        start_date="cast('2024-04-01' as date)",
        end_date="cast('2024-09-28' as date)"
    ) }}

),

calendar_dates AS (

    SELECT

        DATE_DAY AS full_date

    FROM date_spine

),

final_dates AS (

    SELECT

        /* =================================================
           SURROGATE DATE KEY
        ================================================= */

        TO_NUMBER(
            TO_CHAR(
                full_date,
                'YYYYMMDD'
            )
        ) AS date_key,


        /* =================================================
           CALENDAR
        ================================================= */

        full_date,

        YEAR(full_date) AS year,

        QUARTER(full_date) AS quarter,

        MONTH(full_date) AS month,

        WEEK(full_date) AS week,

        DAYOFWEEK(full_date) AS day_of_week,


        /* =================================================
           US HOLIDAY FLAG

           Common US federal holidays relevant to the
           requested date range.
        ================================================= */

        CASE

            WHEN
                (MONTH(full_date) = 1 AND DAY(full_date) = 1)

                OR

                (
                    MONTH(full_date) = 6
                    AND DAYOFWEEK(full_date) = 2
                    AND DAY(full_date) BETWEEN 15 AND 21
                )

                OR

                (
                    MONTH(full_date) = 7
                    AND DAY(full_date) = 4
                )

                OR

                (
                    MONTH(full_date) = 12
                    AND DAY(full_date) = 25
                )

            THEN TRUE

            ELSE FALSE

        END AS holiday_flag,


        /* =================================================
           SEASON
        ================================================= */

        CASE

            WHEN MONTH(full_date) IN (12, 1, 2)
                THEN 'Winter'

            WHEN MONTH(full_date) IN (3, 4, 5)
                THEN 'Spring'

            WHEN MONTH(full_date) IN (6, 7, 8)
                THEN 'Summer'

            WHEN MONTH(full_date) IN (9, 10, 11)
                THEN 'Fall'

        END AS season

    FROM calendar_dates

)

SELECT *

FROM final_dates