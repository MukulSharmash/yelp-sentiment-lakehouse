# yelp-sentiment-lakehouse
## Dashboard Preview

![Dashboard](images/dashboard.png)

An end-to-end cloud-based data engineering project built using Snowflake, AWS S3, Apache Airflow Python, SQL, and Power BI to analyze customer sentiment from Yelp business reviews. The pipeline processes large-scale semi-structured JSON data, performs sentiment analysis using TextBlob, builds a Medallion Architecture (Bronze, Silver, Gold), and generates analytical business insights through SQL views and dashboards.

## Architecture
``` mermaid
graph LR
    %% Data Source
    Source["Yelp JSON Data\n(6M+ Rows, 5GB+)"]:::source --> |Local File Path| PyScript["Python Chunking Script\n(Memory Optimized Splitting)"]:::script

    %% S3 Upload
    PyScript --> |Upload Split Chunks| S3["AWS S3 Bucket\n/reviews/ /business/"]:::storage

    %% Orchestration + Snowflake Layer
    subgraph OrchestrationLayer ["Apache Airflow — Astronomer Cloud (11 Tasks, Weekly Schedule, Retries)"]
        direction TB
        DAG["Airflow DAG\nyelp_sentiment_lakehouse"]:::airflow
        DAG -.-> |"Parallel Execution\nbronze_reviews || bronze_business"| DAG
        DAG -.-> |"Task Dependencies\n>> operator"| DAG

        subgraph SnowflakeDW ["Snowflake Data Warehouse — Medallion Architecture"]
            direction TB
            Bronze["Bronze Layer\nRaw VARIANT JSON\nyelp_reviews / yelp_business"]:::bronze
            Silver["Silver Layer\nFlattened JSON + Data Quality\nTextBlob Sentiment UDF"]:::silver
            Gold["Gold Layer\nStar Schema\ndim_business / dim_category\ndim_date / fact_review\nfact_business_sentiment"]:::gold
            Views["Analytical Views (9)\nv_top_businesses\nv_monthly_sentiment_trend\nv_category_performance\nv_sentiment_distribution"]:::views
            Bronze --> |"JSON Flattening\nSentiment Scoring"| Silver
            Silver --> |"Dimensional Modeling\nAggregations"| Gold
            Gold --> |"Business Intelligence\nQueries"| Views
        end

        DAG --> |"CREATE OR REPLACE\nIdempotent Tasks"| Bronze
    end

    %% S3 to Airflow
    S3 --> |"COPY INTO @yelp_stage\n(Airflow Triggered)"| DAG

    %% Consumption Layer
    Views --> |DirectQuery| PBI["Power BI Dashboard\nBusiness Insights\nSentiment Trends"]:::viz

    %% Styling
    classDef source fill:#f9f,stroke:#333,stroke-width:2px;
    classDef script fill:#C5A3FF,stroke:#333,stroke-width:2px;
    classDef storage fill:#FF9966,stroke:#333,stroke-width:2px,color:white;
    classDef airflow fill:#017CEE,stroke:#333,stroke-width:2px,color:white;
    classDef bronze fill:#CD7F32,stroke:#333,stroke-width:2px,color:white;
    classDef silver fill:#87CEEB,stroke:#333,stroke-width:2px;
    classDef gold fill:#FFD700,stroke:#333,stroke-width:2px;
    classDef views fill:#66CCCC,stroke:#333,stroke-width:2px;
    classDef viz fill:#FFCC00,stroke:#333,stroke-width:2px,color:black;

```
### Bronze Layer:
- Raw JSON ingestion from AWS S3
- Snowflake VARIANT data storage
### Silver Layer:
- Data cleaning and transformation
- JSON flattening
- Sentiment analysis using TextBlob
- Data quality handling
### Gold Layer:
- Fact and dimension modeling
- Business analytics aggregations
### Analytics Layer:
- Top businesses by sentiment
- Category performance
- City-level customer satisfaction
- Monthly sentiment trends
- Sentiment distribution analysis
---
## Tech Stack 
- Python
- Snowflake
- Apache Airflow
- SQL
- AWS S3
- TextBlob
- Power BI
---
## Key Features 
- Orchestrated End-to-end ETL pipeline
- Cloud-based data warehouse architecture
- Sentiment analysis on customer reviews
- Semi-structured JSON processing
- Medallion Architecture implementation
- Analytical SQL views for business intelligence

---


