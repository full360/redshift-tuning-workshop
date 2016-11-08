--build core beer tables and load data
--drop schema if exists beer cascade;
create schema if not exists beer;

drop table if exists beer.drinkers cascade;
create table if not exists beer.drinkers
(
	id integer
	,user_id char(32)
	,first_name varchar(32)
	,last_name varchar(32)
	,company varchar(64)
	,school varchar(128)
	,superhero_power varchar(64)
	,good_tipper boolean
	,favorite_instrument varchar(64)
	,zip_code char(5)
);

copy beer.drinkers from 's3://redshift-demo-beer.full360.com/users.json.gz'
credentials 'aws_iam_role=arn:aws:iam::073631148609:role/myRedshiftRole' 
gzip
json 'auto'
region 'us-west-2'
compupdate false;

drop table if exists beer.events cascade;
create table if not exists beer.events
(
	beer_event_id char(32)
	,drinking_session_id char(32)
	,user_id char(32)
	,beer varchar(64)
	,schmooziest_buzzword varchar(32)
	,best_thing_said varchar(256)
	,worst_thing_said varchar(256)
	,drunken_babble varchar(1024)
	,likes integer
	,beer_opened_time timestamp
);

copy beer.events from 's3://redshift-demo-beer.full360.com/beer'
credentials 'aws_iam_role=arn:aws:iam::073631148609:role/myRedshiftRole' 
gzip
json 'auto'
region 'us-west-2'
compupdate false;


create schema if not exists sales;
drop table if exists sales.transactions cascade;
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

copy sales.transactions from 's3://redshift-demo-beer.full360.com/billion_transactions'
credentials 'aws_iam_role=arn:aws:iam::073631148609:role/myRedshiftRole'
gzip
json 'auto'
region 'us-west-2'
compupdate false;

drop table if exists sales.transactions_interleaved cascade;
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
interleaved sortkey(product, color, country, transaction_time, customer_id);

insert into sales.transactions_interleaved select * from sales.transactions;
vacuum reindex sales.transactions_interleaved;