WITH account_metrics AS (
    SELECT
        s.date AS date,
        sp.country,
        a.send_interval,
        a.is_verified,
        a.is_unsubscribed,


        COUNT(DISTINCT a.id) AS account_cnt,
        0 AS sent_msg,
        0 AS open_msg,
        0 AS visit_msg


    FROM `DA.account` a
    JOIN `DA.account_session` acs
        ON a.id = acs.account_id
    JOIN `DA.session` s
        ON acs.ga_session_id = s.ga_session_id
    JOIN `DA.session_params` sp
        ON s.ga_session_id = sp.ga_session_id


    GROUP BY
        s.date,
        sp.country,
        a.send_interval,
        a.is_verified,
        a.is_unsubscribed
),


email_metrics AS (
    SELECT
        DATE_ADD(s.date, INTERVAL es.sent_date DAY) AS date,
        sp.country,
        a.send_interval,
        a.is_verified,
        a.is_unsubscribed,


        0 AS account_cnt,


        COUNT(DISTINCT es.id_message) AS sent_msg,


        COUNT(DISTINCT eo.id_message) AS open_msg,


        COUNT(DISTINCT ev.id_message) AS visit_msg


    FROM `DA.email_sent` es


    JOIN `DA.account` a
        ON es.id_account = a.id


    JOIN `DA.account_session` acs
        ON a.id = acs.account_id


    JOIN `DA.session` s
    ON acs.ga_session_id = s.ga_session_id


JOIN `DA.session_params` sp
    ON acs.ga_session_id = sp.ga_session_id


    LEFT JOIN `DA.email_open` eo
        ON es.id_message = eo.id_message


    LEFT JOIN `DA.email_visit` ev
        ON es.id_message = ev.id_message


   GROUP BY
    DATE_ADD(s.date, INTERVAL es.sent_date DAY),
    sp.country,
    a.send_interval,
    a.is_verified,
    a.is_unsubscribed
),


union_data AS (
    SELECT * FROM account_metrics


    UNION ALL


    SELECT * FROM email_metrics
),


final_metrics AS (
    SELECT
        date,
        country,
        send_interval,
        is_verified,
        is_unsubscribed,


        SUM(account_cnt) AS account_cnt,
        SUM(sent_msg) AS sent_msg,
        SUM(open_msg) AS open_msg,
        SUM(visit_msg) AS visit_msg


    FROM union_data


    GROUP BY
        date,
        country,
        send_interval,
        is_verified,
        is_unsubscribed
),


country_totals AS (
    SELECT
        country,


        SUM(account_cnt) AS total_country_account_cnt,
        SUM(sent_msg) AS total_country_sent_cnt


    FROM final_metrics


    GROUP BY country
),


ranked_data AS (
    SELECT
        fm.date,
        fm.country,
        fm.send_interval,
        fm.is_verified,
        fm.is_unsubscribed,


        fm.account_cnt,
        fm.sent_msg,
        fm.open_msg,
        fm.visit_msg,


        ct.total_country_account_cnt,
        ct.total_country_sent_cnt,


        DENSE_RANK() OVER (
            ORDER BY ct.total_country_account_cnt DESC
        ) AS rank_total_country_account_cnt,


        DENSE_RANK() OVER (
            ORDER BY ct.total_country_sent_cnt DESC
        ) AS rank_total_country_sent_cnt


    FROM final_metrics fm
    JOIN country_totals ct
        ON fm.country = ct.country
)


SELECT *
FROM ranked_data
WHERE
    rank_total_country_account_cnt <= 10
    OR rank_total_country_sent_cnt <= 10
ORDER BY
    country,
    date;
