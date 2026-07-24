
from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.standard.operators.python import PythonOperator

SNOWFLAKE_CONN_ID = "snowflake_default"

default_args = {
    "owner": "mukul",
    "retries": 2,
    "retry_delay": timedelta(minutes=3),
}


def validate_environment():
    print("Starting Yelp Sentiment Lakehouse pipeline...")
    print("Bronze -> Silver -> Gold")


def run_snowflake_sql(sql):
    from airflow.hooks.base import BaseHook
    import snowflake.connector

    conn = BaseHook.get_connection(SNOWFLAKE_CONN_ID)
    extra = conn.extra_dejson

    sf = snowflake.connector.connect(
        user=conn.login,
        password=conn.password,
        account=extra.get("account"),
        warehouse=extra.get("warehouse"),
        database=extra.get("database"),
        role=extra.get("role"),
        authenticator="snowflake",
    )
    cursor = sf.cursor()
    for statement in sql.strip().split(";"):
        if statement.strip():
            cursor.execute(statement.strip())
    cursor.close()
    sf.close()
    print("SQL executed successfully")


with DAG(
    dag_id="yelp_sentiment_lakehouse",
    default_args=default_args,
    description="Yelp pipeline: S3 -> Bronze -> Silver -> Gold",
    start_date=datetime(2026, 1, 1),
    schedule="@weekly",
    catchup=False,
    tags=["yelp", "snowflake", "etl"],
) as dag:

    validate_env = PythonOperator(
        task_id="validate_environment",
        python_callable=validate_environment,
    )

    bronze_reviews = PythonOperator(
        task_id="bronze_load_reviews",
        python_callable=run_snowflake_sql,
        op_args=["""
            CREATE OR REPLACE TABLE bronze.yelp_reviews
            (review_text VARIANT);
            COPY INTO bronze.yelp_reviews
            FROM @bronze.yelp_stage/reviews/
            FILE_FORMAT = (TYPE = 'JSON')
            ON_ERROR = 'CONTINUE'
        """],
    )

    bronze_business = PythonOperator(
        task_id="bronze_load_business",
        python_callable=run_snowflake_sql,
        op_args=["""
            CREATE OR REPLACE TABLE bronze.yelp_business
            (business_text VARIANT);
            COPY INTO bronze.yelp_business
            FROM @bronze.yelp_stage/business/
            FILE_FORMAT = (TYPE = 'JSON')
            ON_ERROR = 'CONTINUE'
        """],
    )

    silver_reviews = PythonOperator(
        task_id="silver_transform_reviews",
        python_callable=run_snowflake_sql,
        op_args=["""
            CREATE OR REPLACE TABLE silver.yelp_reviews AS
            SELECT 
                review_id, user_id, business_id, review_text,
                useful, review_date, polarity,
                CASE 
                    WHEN polarity >= 0.05 THEN 'positive'
                    WHEN polarity <= -0.05 THEN 'negative'
                    ELSE 'neutral'
                END AS sentiment_label,
                polarity * LN(1 + useful) AS score
            FROM (
                SELECT 
                    review_id, user_id, business_id, review_text,
                    useful, review_date,
                    silver.analyze_sentiments(review_text) AS polarity
                FROM (
                    SELECT 
                        TRIM(review_text:review_id::VARCHAR(100)) AS review_id,
                        TRIM(review_text:user_id::VARCHAR(100)) AS user_id,
                        TRIM(review_text:business_id::VARCHAR(100)) AS business_id,
                        TRIM(review_text:text::VARCHAR(8000)) AS review_text,
                        CASE WHEN review_text:useful < 0 THEN 0
                             ELSE review_text:useful END::INT AS useful,
                        review_text:date::DATE AS review_date
                    FROM bronze.yelp_reviews
                )
                WHERE review_id IS NOT NULL
                AND user_id IS NOT NULL
                AND business_id IS NOT NULL
                AND LENGTH(review_text) >= 3
            )
        """],
    )

    silver_business = PythonOperator(
        task_id="silver_transform_business",
        python_callable=run_snowflake_sql,
        op_args=["""
            CREATE OR REPLACE TABLE silver.yelp_business AS
            SELECT 
                TRIM(business_text:business_id::VARCHAR(100)) AS business_id,
                TRIM(business_text:name::VARCHAR(100)) AS name,
                TRIM(business_text:categories::VARCHAR(5000)) AS categories,
                TRIM(business_text:city::VARCHAR(100)) AS city,
                TRIM(business_text:state::VARCHAR(10)) AS state,
                CASE WHEN business_text:review_count < 0 THEN 0
                     ELSE business_text:review_count END::NUMBER(10,0) AS review_count,
                CASE WHEN business_text:stars < 1 THEN 1
                     WHEN business_text:stars > 5 THEN 5
                     ELSE business_text:stars END::NUMBER(3,1) AS stars,
                CASE WHEN business_text:is_open NOT IN (0,1) THEN 0
                     ELSE business_text:is_open END::NUMBER(1,0) AS is_open
            FROM bronze.yelp_business
            WHERE business_text:business_id IS NOT NULL
        """],
    )

    gold_dim_business=PythonOperator(
        task_id="gold_dim_business",
        python_callable=run_snowflake_sql,
        op_args=["""

        create  or replace table gold.dim_business as
        SELECT 
            business_id,
            name,
            city,
            state,
            stars,
            is_open,
            review_count
        FROM silver.yelp_business
        
        """],
    )

    gold_dim_category=PythonOperator(
        task_id="gold_dim_category",
        python_callable=run_snowflake_sql,
        op_args=["""
        CREATE OR REPLACE TABLE gold.dim_category AS

        SELECT 
            business_id,
            TRIM(f.value::STRING) AS category
        FROM silver.yelp_business,
        LATERAL FLATTEN(input => SPLIT(categories, ',')) f
        
        """],

    )

    gold_dim_date=PythonOperator(
        task_id="gold_dim_date",
        python_callable=run_snowflake_sql,
        op_args=["""
        CREATE OR REPLACE TABLE gold.dim_date AS
        SELECT DISTINCT
        review_date,
        YEAR(review_date) AS year,
        MONTH(review_date) AS month,
        DAY(review_date) AS day
    FROM silver.yelp_reviews;
        """],
    )

    gold_fact_review=PythonOperator(
        task_id="gold_fact_review",
        python_callable=run_snowflake_sql,
        op_args=["""
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
        """],
    )

    gold_fact_business_sentiment=PythonOperator(
        task_id="gold_fact_business_sentiment",
        python_callable=run_snowflake_sql,
        op_args=["""

        CREATE OR REPLACE TABLE gold.fact_business_sentiment AS

        SELECT 
            business_id,
            COUNT(*) AS total_reviews,
            AVG(polarity) AS avg_sentiment,
            AVG(score) AS weighted_sentiment,
            SUM(useful) AS total_useful_votes
        FROM silver.yelp_reviews
        GROUP BY business_id;
        """],
    )

    create_views = PythonOperator(
        task_id="create_analytical_views",
        python_callable=run_snowflake_sql,
        op_args=["""
            CREATE OR REPLACE VIEW gold.v_top_businesses AS
            SELECT f.business_id, d.city, d.state, f.avg_sentiment, f.total_reviews
            FROM gold.fact_business_sentiment f
            INNER JOIN gold.dim_business d ON f.business_id = d.business_id
            WHERE f.total_reviews >= 100
            ORDER BY f.avg_sentiment DESC
            LIMIT 10;

            CREATE OR REPLACE VIEW gold.v_sentiment_distribution AS
            SELECT sentiment_label, COUNT(*) AS total_reviews
            FROM gold.fact_review
            GROUP BY sentiment_label;

            CREATE OR REPLACE VIEW gold.v_monthly_sentiment_trend AS
            SELECT DATE_TRUNC('month', review_date) AS review_month,
                AVG(polarity) AS monthly_avg_sentiment
            FROM gold.fact_review
            GROUP BY review_month
            ORDER BY review_month
        """],
    )

    validate_env >> [bronze_reviews, bronze_business]
    bronze_reviews >> silver_reviews
    bronze_business >> silver_business
    silver_reviews >> [gold_dim_date,gold_fact_business_sentiment,gold_fact_review]
    silver_business >> [gold_dim_business,gold_dim_category]
    [gold_dim_business, gold_dim_category, gold_dim_date, gold_fact_review, gold_fact_business_sentiment] >> create_views
