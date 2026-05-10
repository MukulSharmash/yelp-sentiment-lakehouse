create or replace function silver.analyze_sentiments (text string)
returns float()
language python
runtime_version ='3.9'
packages=('textblob')
handler='sentiment_analyzer'
as $$
from textblob import TextBlob
def sentiment_analyzer(text):
    analysis=TextBlob(text)
    return analysis.sentiment.polarity

$$
