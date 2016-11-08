--this table already exists... ddl provided for reference
--compound sortkey optimized for range restriction on transaction_id
create table if not exists sales.transactions 
(
	"transaction_id" bigint encode delta32k,
	"customer_id" bigint encode delta32k,
	"product" varchar(255) encode text32k,
	"color" varchar(64) encode bytedict,
	"price" numeric(8,2) encode delta32k,
	"quantity" smallint encode mostly8,
	"country" varchar(255) encode bytedict,
	"transaction_time" timestamp
)
distkey(customer_id)
sortkey(transaction_id);

create table if not exists sales.transactions_interleaved
(
	"transaction_id" bigint encode delta32k,
	"customer_id" bigint encode delta32k,
	"product" varchar(255) encode text32k,
	"color" varchar(64) encode bytedict,
	"price" numeric(8,2) encode delta32k,
	"quantity" smallint encode mostly8,
	"country" varchar(255) encode bytedict,
	"transaction_time" timestamp
)
distkey(customer_id)
interleaved sortkey(transaction_id, customer_id, product, color, country, transaction_time);

--compare the compound sortkey table sales.transactions
--to the interleaved sortkey table sales.transactions_interleaved
--if you remove the transaction_id filter then start adding in
--the others you will see the performance degrade in one
--and increase in the other
explain select
	product
	,sum(price * quantity) as total_sales
	,count(*)
from
	sales.transactions
where
	transaction_id < 100000000
	and
	product='Mediocre Paper Shirt'
	and
	color = 'black'
	--and
	--country = 'Croatia'
	--and
	--customer_id = 1118291
group by 
	product;
	
explain select
	product
	,sum(price * quantity) as total_sales
	,count(*)
from
	sales.transactions_interleaved
where
	--transaction_id < 100000000
	--and
	product='Mediocre Paper Shirt'
	and
	color = 'black'
	and
	country = 'Croatia'
	and
	customer_id = 1118291
group by 
	product;