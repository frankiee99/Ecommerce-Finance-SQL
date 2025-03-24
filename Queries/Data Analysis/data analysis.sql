-- Atliq Hardwares Finance and Supply Chain Analytics Project

-- 1. Create report containing Month, Product Name, Variant, Sold Quantity, Gross Price per Item, Gross Price Total
SELECT 
    MONTHNAME(s.date) AS month,
    p.product,
    p.variant,
    s.sold_quantity,
    ROUND(g.gross_price, 2) AS gross_price,
    ROUND(s.sold_quantity * g.gross_price, 2) AS gross_price_total
FROM fact_sales_monthly s
JOIN dim_product p USING (product_code)
JOIN fact_gross_price g 
    ON g.product_code = s.product_code 
    AND g.fiscal_year = GET_FISCAL_YEAR(s.date)
WHERE customer_code = 90002002  
    AND GET_FISCAL_YEAR(s.date) = 2021 
ORDER BY s.date ASC 
LIMIT 1000000;

-- 2. Total Gross Price per Date
SELECT 
    MONTHNAME(s.date) AS month,
    ROUND(SUM(s.sold_quantity * g.gross_price), 2) AS gross_price_total
FROM fact_sales_monthly s
JOIN fact_gross_price g  
    ON g.product_code = s.product_code 
    AND g.fiscal_year = GET_FISCAL_YEAR(s.date)
WHERE customer_code = 90002002  
GROUP BY s.date 
ORDER BY s.date ASC;

-- 3. Total Gross Price per Fiscal Year
SELECT 
    g.fiscal_year,
    ROUND(SUM(s.sold_quantity * g.gross_price) / 1000000, 2) AS "gross_price_total(in mln)"
FROM fact_sales_monthly s
JOIN fact_gross_price g 
    ON s.product_code = g.product_code  
    AND GET_FISCAL_YEAR(s.date) = g.fiscal_year
WHERE customer_code = 90002002 
GROUP BY g.fiscal_year;

-- 4. Top Customers by Net Sales
SELECT 
    c.customer,
    ROUND(SUM(net_sales) / 1000000, 2) AS net_sales_mln
FROM gdb0041.net_sales s  
JOIN dim_customer c USING (customer_code)
WHERE fiscal_year = 2021 
GROUP BY c.customer 
ORDER BY net_sales_mln DESC 
LIMIT 5;

-- 5. Top Markets by Net Sales
SELECT 
    market,
    ROUND(SUM(net_sales) / 1000000, 2) AS net_sales_mln
FROM gdb0041.net_sales 
WHERE fiscal_year = 2021 
GROUP BY market 
ORDER BY net_sales_mln DESC 
LIMIT 5;

-- 6. Top 10 Customers by Net Sales % Contribution
WITH cte AS (
    SELECT 
        c.customer,
        ROUND(SUM(net_sales) / 1000000, 2) AS net_sales_mln
    FROM gdb0041.net_sales s  
    JOIN dim_customer c USING (customer_code)
    WHERE s.fiscal_year = 2021  
    GROUP BY c.customer 
    ORDER BY net_sales_mln DESC 
)
SELECT *, 
    ROUND(net_sales_mln * 100 / SUM(net_sales_mln) OVER (), 2) AS net_sales_perc 
FROM cte 
ORDER BY net_sales_perc DESC 
LIMIT 10;

-- 7. Region-wise Net Sales Breakdown
WITH cte AS (
    SELECT 
        customer,
        SUM(net_sales) AS net_sales 
    FROM net_sales s 
    JOIN dim_customer c USING (customer_code) 
    WHERE s.fiscal_year = 2021 AND region = "APAC" 
    GROUP BY customer 
    ORDER BY net_sales DESC 
)
SELECT 
    customer,
    ROUND(net_sales * 100 / SUM(net_sales) OVER (), 2) AS net_sales_perc 
FROM cte 
LIMIT 10;

-- 8. Retrieve the Top 2 Markets in Every Region by Their Gross Sales Amount in FY 2021
WITH cte1 AS (
    SELECT 
        c.region, 
        c.market,  
        SUM(g.gross_price_total) AS gross_sales_total 
    FROM gdb0041.`gross sales` g 
    JOIN dim_customer c USING (customer_code) 
    GROUP BY 1,2
),
cte2 AS (
    SELECT *, DENSE_RANK() OVER (PARTITION BY region ORDER BY gross_sales_total DESC) AS rnk 
    FROM cte1
)  
SELECT * FROM cte2 
WHERE rnk <= 2;

-- 9. Supply Chain - Forecast Quantity
WITH forecast_err_table AS (
    SELECT 
        s.customer_code AS customer_code, 
        c.customer AS customer_name, 
        c.market AS market, 
        SUM(s.sold_quantity) AS total_sold_qty, 
        SUM(s.forecast_quantity) AS total_forecast_qty, 
        SUM(s.forecast_quantity - s.sold_quantity) AS net_error, 
        ROUND(SUM(s.forecast_quantity - s.sold_quantity) * 100 / SUM(s.forecast_quantity), 1) AS net_error_pct, 
        SUM(ABS(s.forecast_quantity - s.sold_quantity)) AS abs_error, 
        ROUND(SUM(ABS(s.forecast_quantity - s.sold_quantity)) * 100 / SUM(s.forecast_quantity), 2) AS abs_error_pct 
    FROM fact_act_est s 
    JOIN dim_customer c 
        ON s.customer_code = c.customer_code 
    WHERE s.fiscal_year = 2021 
    GROUP BY s.customer_code
)
SELECT *, 
    IF (abs_error_pct > 100, 0, 100.0 - abs_error_pct) AS forecast_accuracy 
FROM forecast_err_table 
ORDER BY forecast_accuracy DESC;
