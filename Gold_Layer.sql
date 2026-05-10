create  or replace table gold.dim_business as
(SELECT 
    business_id,
    city,
    state,
    stars,
    is_open,
    review_count
FROM yelp_business)


CREATE OR REPLACE TABLE gold.dim_category AS

SELECT 
    business_id,
    TRIM(f.value::STRING) AS category
FROM silver.yelp_business,
LATERAL FLATTEN(input => SPLIT(categories, ',')) f;


CREATE OR REPLACE TABLE gold.dim_date AS

SELECT DISTINCT
    review_date,
    YEAR(review_date) AS year,
    MONTH(review_date) AS month,
    DAY(review_date) AS day
FROM silver.yelp_reviews;


CREATE OR REPLACE TABLE gold.fact_review AS

SELECT 
    review_id,
    business_id,
    user_id,
    review_date,
    polarity,
    sentiment_label,
    score,
    useful
FROM silver.yelp_reviews;


CREATE OR REPLACE TABLE gold.fact_business_sentiment AS

SELECT 
    business_id,
    COUNT(*) AS total_reviews,
    AVG(polarity) AS avg_sentiment,
    AVG(score) AS weighted_sentiment,
    SUM(useful) AS total_useful_votes
FROM silver.yelp_reviews
GROUP BY business_id;
