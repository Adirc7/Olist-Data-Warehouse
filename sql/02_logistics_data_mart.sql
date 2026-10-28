-- Logistics Data Mart: monthly, per-state aggregates of orders, freight cost and delivery delay
CREATE VIEW logistic_data_mart AS
SELECT
    d.year,
    d.month,
    c.customer_state,
    COUNT(DISTINCT f.order_id)                              AS total_orders,
    SUM(f.freight_value)                                    AS total_freight_cost,
    AVG(CAST(f.delivery_delay_days AS DECIMAL(10,2)))       AS avg_delivery_delay_days
FROM fact_order_items f
INNER JOIN dim_customer c ON f.customer_key = c.customer_key
INNER JOIN dim_date d     ON f.order_purchase_date_key = d.date_key
GROUP BY
    d.year,
    d.month,
    c.customer_state;
GO

SELECT TOP 15 * FROM logistic_data_mart ORDER BY total_orders DESC;
