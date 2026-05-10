# yelp-sentiment-lakehouse
## Dashboard Preview

![Dashboard](dashboard.png)

An end-to-end cloud-based data engineering project built using Snowflake, AWS S3, Python, SQL, and Power BI to analyze customer sentiment from Yelp business reviews. The pipeline processes large-scale semi-structured JSON data, performs sentiment analysis using TextBlob, builds a Medallion Architecture (Bronze, Silver, Gold), and generates analytical business insights through SQL views and dashboards.

## Architecture
```mermaid
graph LR
    %% Data Source
    Source[Yelp JSON Data]:::source --> |5GB+ / ~7M Rows| PyScript[Python Chunking Script]:::script

    %% Storage Layer
    subgraph DataLake ["Cloud Storage"]
        PyScript --> |Chunked JSON| S3[Amazon S3]:::storage
    end

    %% Warehouse Layers
    subgraph SnowflakeDW ["Snowflake Data Warehouse"]
        S3 --> |COPY INTO| Bronze[(Snowflake Bronze: Raw)]:::db
        Bronze --> |ELT Flattening| Silver[(Snowflake Silver: Cleansed & Sentiment)]:::db
        Silver --> |Dimensional Modeling| Gold[(Snowflake Gold: Star Schema)]:::db
    end

    %% Consumption Layer
    Gold --> |DirectQuery| PBI[Power BI Dashboard]:::viz

    %% --- STYLING (The code below makes it colorful) ---
    classDef source fill:#f9f,stroke:#333,stroke-width:2px;
    classDef script fill:#ff9,stroke:#333,stroke-width:2px;
    classDef storage fill:#f96,stroke:#333,stroke-width:2px,color:white;
    classDef db fill:#69c,stroke:#333,stroke-width:2px,color:white;
    classDef viz fill:#d4af37,stroke:#333,stroke-width:2px,color:black;

### Bronze Layer:
- Raw JSON ingestion from AWS S3
- Snowflake VARIANT data storage
###Silver Layer:
- Data cleaning and transformation
- JSON flattening
- Sentiment analysis using TextBlob
- Data quality handling
###Gold Layer:
- Fact and dimension modeling
- Business analytics aggregations
###Analytics Layer:
- Top businesses by sentiment
- Category performance
- City-level customer satisfaction
- Monthly sentiment trends
- Sentiment distribution analysis
---
