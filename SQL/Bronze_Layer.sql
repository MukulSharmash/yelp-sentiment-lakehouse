create database yelp_db
use yelp_db

create schema bronze; 
create schema silver;
create schema gold;


use schema bronze;

create or replace stage yelp_stage

url="bucket location"
credentials=(
    AWS_KEY_ID = 'Your AWS_KEY_ID '
    AWS_SECRET_KEY = 'Your AWS_SECRET_KEY'
);



create or replace table bronze.yelp_reviews (review_text variant)

copy into bronze.yelp_reviews
from @bronze.yelp_stage/reviews/
file_format=(type='json');

create or replace table bronze.yelp_business (business_text variant)


copy into bronze.yelp_business 
from @bronze.yelp_stage/business/
file_format=(type='json');


