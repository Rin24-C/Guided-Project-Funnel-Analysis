-- Create new table with correct columns and load file
CREATE TABLE IF NOT EXISTS user_events(
	event_id INT NOT NULL,
    user_id INT NOT NULL,
    event_type TEXT,
    event_date TIMESTAMP,
    product_id INT NOT NULL,
    amount FLOAT,
    traffic_source TEXT);
    
    
LOAD DATA INFILE "C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\user_event_2 - Sheet1.csv"
INTO TABLE user_events
FIELDS TERMINATED BY ',' 
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;

SELECT * FROM user_events;
    
-- Define sales funnel and the different stages
SELECT DISTINCT(event_type) FROM user_events;

WITH funnel_stages AS (
    SELECT 
        COUNT(DISTINCT CASE WHEN event_type = 'page_view' THEN user_id END) AS stage_1_views,
        COUNT(DISTINCT CASE WHEN event_type = 'add_to_cart' THEN user_id END) AS stage_2_cart,
        COUNT(DISTINCT CASE WHEN event_type = 'checkout_start' THEN user_id END) AS stage_3_checkout,
        COUNT(DISTINCT CASE WHEN event_type = 'payment_info' THEN user_id END) AS stage_4_payment,
        COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS stage_5_purchase
    FROM user_events
	WHERE event_date >= '2026-01-03' 
    AND event_date <= '2026-02-02')
SELECT * FROM funnel_stages;
	-- NOTE: Interval 30 Day will not work because THERE IS NO RECENT DATA then.

-- Find the conversion rates through the funnel
WITH funnel_stages AS (
    SELECT 
        COUNT(DISTINCT CASE WHEN event_type = 'page_view' THEN user_id END) AS stage_1_views,
        COUNT(DISTINCT CASE WHEN event_type = 'add_to_cart' THEN user_id END) AS stage_2_cart,
        COUNT(DISTINCT CASE WHEN event_type = 'checkout_start' THEN user_id END) AS stage_3_checkout,
        COUNT(DISTINCT CASE WHEN event_type = 'payment_info' THEN user_id END) AS stage_4_payment,
        COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS stage_5_purchase
    FROM user_events
	WHERE event_date >= '2026-01-03' 
    AND event_date <= '2026-02-02')
SELECT

	stage_1_views,
	stage_2_cart,
	ROUND(stage_2_cart * 100 / stage_1_views) AS view_to_cart_rate,
	
	stage_3_checkout,
	ROUND(stage_3_checkout * 100 / stage_2_cart) AS cart_to_checkout_rate,
    
    stage_4_payment,
	ROUND(stage_4_payment * 100 / stage_3_checkout) AS checkout_to_payment_rate,
    
    stage_5_purchase,
	ROUND(stage_5_purchase * 100 / stage_4_payment) AS payment_to_purchase_rate,
    
	ROUND(stage_5_purchase * 100 / stage_1_views) AS overall_conversion_rate

FROM funnel_stages;

-- Funnel by source
SELECT DISTINCT(traffic_source)
FROM user_events;

WITH traffic_funnel AS (
    SELECT 
		traffic_source,
        COUNT(DISTINCT CASE WHEN event_type = 'page_view' THEN user_id END) AS views,
        COUNT(DISTINCT CASE WHEN event_type = 'add_to_cart' THEN user_id END) AS carts,
        COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS purchases
    FROM user_events
	WHERE event_date >= '2026-01-03' 
    AND event_date <= '2026-02-02'
    GROUP BY traffic_source)
SELECT 
	traffic_source,
    views,
    carts,
    purchases,
	ROUND(carts * 100 / views) AS cart_conversion_rate,
	ROUND(purchases * 100 / carts) AS purchases_conversion_rate,
	ROUND(purchases * 100 / views) AS cart_to_purchase_conversion_rate
FROM traffic_funnel
ORDER BY purchases DESC;

-- time to conversion analysis
WITH user_journey AS (
    SELECT 
		user_id,
        MIN(CASE WHEN event_type = 'page_view' THEN event_date END) AS view_time,
        MIN(CASE WHEN event_type = 'add_to_cart' THEN event_date END) AS cart_time,
        MIN(CASE WHEN event_type = 'purchase' THEN event_date END) AS purchase_time
    FROM user_events
	WHERE event_date >= '2026-01-03' 
    AND event_date <= '2026-02-02'
    GROUP BY user_id
    HAVING MIN(CASE WHEN event_type = 'purchase' THEN event_date END) IS NOT NULL
    )
SELECT 
	COUNT(*) AS converted_users,
    ROUND(AVG(TIMESTAMPDIFF(MINUTE, view_time, cart_time))) AS avg_view_to_cart_minutes,
    ROUND(AVG(TIMESTAMPDIFF(MINUTE, cart_time, purchase_time))) AS avg_cart_to_purchase_minutes,
    ROUND(AVG(TIMESTAMPDIFF(MINUTE, view_time, purchase_time))) AS avg_total_journey_minutes
FROM user_journey;

-- revenue funnel analysis
WITH funnel_revenue AS (
    SELECT 
        COUNT(DISTINCT CASE WHEN event_type = 'page_view' THEN user_id END) AS total_visitors,
        COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) AS total_buyers,
        ROUND(SUM(CASE WHEN event_type = 'purchase' THEN amount END), 2) AS total_revenue,
		COUNT(CASE WHEN event_type = 'purchase' THEN 1 END) AS total_orders
	FROM user_events
		WHERE event_date >= '2026-01-03' 
		AND event_date <= '2026-02-02'
)
SELECT 
	total_visitors,
    total_buyers,
    total_revenue,
    ROUND(total_revenue / total_orders, 2) AS avg_order_value,
    ROUND(total_revenue / total_buyers, 2) AS revenue_per_buyer,
    ROUND(total_revenue / total_visitors, 2) AS revenue_per_visitor
FROM funnel_revenue;