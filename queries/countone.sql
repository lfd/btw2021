CREATE STREAM bids(t FLOAT, id INT, broker_id CHAR, volume FLOAT, price FLOAT)
FROM FILE 'data/finance.csv'
LINE DELIMITED CSV (delimiter := ',');

SELECT count (1) FROM bids;
