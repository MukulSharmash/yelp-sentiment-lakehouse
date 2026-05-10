CREATE OR REPLACE TABLE silver.yelp_reviews AS

SELECT 
    review_id,
    user_id,
    business_id,
    review_text,
    useful,
    review_date,
    polarity,

    CASE 
        WHEN polarity >= 0.05 THEN 'positive'
        WHEN polarity <= -0.05 THEN 'negative'
        ELSE 'neutral'
    END AS sentiment_label,

    polarity * LN(1 + useful) AS score

FROM
(
    SELECT 
        review_id,
        user_id,
        business_id,
        review_text,
        useful,
        review_date,
        silver.analyze_sentiments(review_text) AS polarity

    FROM
    (
        SELECT 
            TRIM(review_text:review_id::VARCHAR(100)) AS review_id,
            TRIM(review_text:user_id::VARCHAR(100)) AS user_id,
            TRIM(review_text:business_id::VARCHAR(100)) AS business_id,
            TRIM(review_text:text::VARCHAR(8000)) AS review_text,

            CASE 
                WHEN review_text:useful < 0 THEN 0
                ELSE review_text:useful
            END::INT AS useful,

            review_text:date::DATE AS review_date

        FROM bronze.yelp_reviews
    )

    WHERE 
        review_id IS NOT NULL
        AND user_id IS NOT NULL
        AND business_id IS NOT NULL
        AND LENGTH(review_text) >= 3
);



CREATE OR REPLACE TABLE silver.yelp_business AS

SELECT 
    TRIM(business_text:business_id::VARCHAR(100)) AS business_id,

    TRIM(business_text:categories::VARCHAR(5000)) AS categories,
    TRIM(business_text:city::VARCHAR(100)) AS city,
    TRIM(business_text:state::VARCHAR(10)) AS state,

    CASE 
        WHEN business_text:review_count < 0 THEN 0
        ELSE business_text:review_count
    END::NUMBER(10,0) AS review_count,

    CASE 
        WHEN business_text:stars < 1 THEN 1
        WHEN business_text:stars > 5 THEN 5
        ELSE business_text:stars
    END::NUMBER(3,1) AS stars,

    CASE 
        WHEN business_text:is_open NOT IN (0,1) THEN 0
        ELSE business_text:is_open
    END::NUMBER(1,0) AS is_open

FROM bronze.yelp_business

WHERE 
    business_text:business_id IS NOT NULL;




