CREATE STREAM bids(t FLOAT, id INT, broker_id INT, volume FLOAT, price FLOAT)
FROM FILE 'data/finance.csv'
LINE DELIMITED orderbook (book := 'bids', brokers := '10', deterministic := 'yes');

select count(1) from bids;
