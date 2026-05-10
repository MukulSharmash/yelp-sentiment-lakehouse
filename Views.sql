CREATE OR REPLACE VIEW gold.v_platform_overview AS

SELECT
    (SELECT COUNT(*) 
     FROM gold.dim_business) AS total_businesses,

    (SELECT COUNT(*) 
     FROM gold.fact_review) AS total_reviews,

    (SELECT ROUND(AVG(avg_sentiment), 4)
     FROM gold.fact_business_sentiment) AS platform_avg_sentiment,

    (SELECT COUNT(DISTINCT category)
     FROM gold.dim_category) AS total_categories,

    (
        SELECT 
            ROUND
            (
                100.0 * 
                SUM(CASE WHEN is_open = 1 THEN 1 ELSE 0 END)
                / COUNT(*),
                2
            )
        FROM gold.dim_business
    ) AS open_business_percentage;





-- -- ----------------Top 10 business -----------------
CREATE OR REPLACE VIEW gold.v_top_businesses AS  

SELECT 
    f.business_id,
    d.city,
    d.state,
    f.avg_sentiment,
    f.total_reviews
FROM gold.fact_business_sentiment f
INNER JOIN gold.dim_business d 
    ON f.business_id = d.business_id
WHERE f.total_reviews >= 100
ORDER BY f.avg_sentiment DESC
LIMIT 10;

-- -- ----------------------- Worst 10 business----------------
create or replace view gold.v_worst_businesses as 

SELECT 
    f.business_id,
    d.city,
    d.state,
    f.avg_sentiment,
    f.total_reviews
FROM gold.fact_business_sentiment f
INNER JOIN gold.dim_business d 
    ON f.business_id = d.business_id
WHERE f.total_reviews >= 100
ORDER BY f.avg_sentiment 
LIMIT 10;

-- ----------top cities by  customer setisfaction 

create or replace view gold.v_top_cities_by_sentiment as

SELECT 
    d.city,
    AVG(f.avg_sentiment) AS city_avg_sentiment
FROM gold.dim_business d
JOIN gold.fact_business_sentiment f
    ON d.business_id = f.business_id
GROUP BY d.city
HAVING COUNT(*) >= 10
ORDER BY city_avg_sentiment DESC;

-- ----- worst cities by customer satisfaction 

CREATE OR REPLACE VIEW gold.v_worst_cities_by_sentiment AS

SELECT 
    d.city,
    AVG(f.avg_sentiment) AS city_avg_sentiment

FROM gold.dim_business d

JOIN gold.fact_business_sentiment f
    ON d.business_id = f.business_id

GROUP BY d.city

HAVING COUNT(*) >= 10

ORDER BY city_avg_sentiment ASC;


-- -- ----------- top categories among all businesses
create or replace view gold.v_category_performance as
SELECT 
    d.category,
    AVG(f.avg_sentiment) AS category_avg_sentiment,
    COUNT(*) AS total_businesses

FROM gold.fact_business_sentiment f
INNER JOIN gold.dim_category d 
    ON f.business_id = d.business_id

GROUP BY d.category

HAVING COUNT(*) >= 20

ORDER BY category_avg_sentiment DESC;


-- ------------top categories among top business --------------

create or replace view gold.v_top_categories_among_top_businesses as

select category,count(*) as category_frequency from gold.dim_category where business_id in (

select business_id from gold.fact_business_sentiment where total_reviews>=100 order by avg_sentiment desc limit 10) group by category order by count(*) desc;




-- -- ----------Category Performance by City--(Which types of businesses perform best in each city?)--------

create or replace view gold.v_category_performance_by_city as

select city, category,avg_sentiment_per_category from (
select d.city,dd.category,avg(f.avg_sentiment) avg_sentiment_per_category, row_number() over (partition by d.city order by avg(f.avg_sentiment) desc) as r from  gold.dim_business d join gold.dim_category dd on d.business_id=dd.business_id join gold.fact_business_sentiment f on dd.business_id=f.business_id group by d.city,dd.category )t where r=1;


-- -- -------Monthly Sentiment Trend

create or replace view gold.v_monthly_sentiment_trend as

SELECT 
    DATE_TRUNC('month', review_date) AS review_month,
    AVG(polarity) AS monthly_avg_sentiment
FROM gold.fact_review
GROUP BY review_month
ORDER BY review_month;


-- -----------open vs closed business sentiment


CREATE OR REPLACE VIEW gold.v_open_vs_closed_business_sentiment AS

SELECT 
    d.is_open,

    AVG(f.avg_sentiment) AS avg_sentiment,

    COUNT(*) AS total_businesses

FROM gold.dim_business d

JOIN gold.fact_business_sentiment f
    ON d.business_id = f.business_id

GROUP BY d.is_open;


------Positive / Neutral / Negative Review Distribution

CREATE OR REPLACE VIEW gold.v_sentiment_distribution AS

SELECT 
    sentiment_label,

    COUNT(*) AS total_reviews

FROM gold.fact_review

GROUP BY sentiment_label;
