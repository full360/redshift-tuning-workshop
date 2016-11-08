--EXPLAIN EXPLAIN EXPLAIN!!!
--learning to read the redshift explain plans is extremely important!
--you want to make sure that your predicate filters are applied to XN Seq Scan operators
--and bad network operations are eliminated as much as possible.
--DS_DIST_NONE and DS_DIST_ALL_NONE are good... most of the others are bad
--Nested Loop is evil!
--be wary of intermediate result sets requiring bad network operations
explain select
	beer
	,favorite_instrument
	,count(distinct d.user_id)
from
	beer.events e
	inner join
	beer.drinkers d
		on
			e.user_id=d.user_id
			and
			d.company='venus.com'
group by
	beer
	,favorite_instrument;

--create tables to implement compression 
--sort and distkey optimization is targeted toward merge join
--encodings will be explained in future labs
drop table if exists beer.drinkers2 cascade;
create table if not exists beer.drinkers2
(
	id integer encode delta32k
	,user_id char(32) encode lzo
	,first_name varchar(32) encode bytedict
	,last_name varchar(32) encode bytedict
	,company varchar(64) encode bytedict
	,school varchar(128) encode bytedict
	,superhero_power varchar(64) encode bytedict
	,good_tipper boolean encode runlength
	,favorite_instrument varchar(64) encode lzo
	,zip_code char(5) encode lzo
)
distkey(user_id)
sortkey(user_id);

drop table if exists beer.events2 cascade;
create table if not exists beer.events2
(
	beer_event_id char(32) encode lzo
	,drinking_session_id char(32) encode lzo
	,user_id char(32) encode lzo
	,beer varchar(64) encode bytedict
	,schmooziest_buzzword varchar(32) encode bytedict
	,best_thing_said varchar(128) encode lzo
	,worst_thing_said varchar(128) encode lzo
	,drunken_babble varchar(1024) encode lzo
	,likes smallint encode mostly8
	,beer_opened_time timestamp encode lzo
)
distkey(user_id)
sortkey(user_id);

--copy data from source tables to target tables
insert into beer.drinkers2 select * from beer.drinkers;
insert into beer.events2 select * from beer.events;

--analyze all the tables to make explain and execution plans accurate
analyze beer.drinkers2;
analyze beer.events2;

--EXECUTE ALL STATEMENTS UP TO THIS POINT

-- http://docs.aws.amazon.com/redshift/latest/dg/c_data_redistribution.html

--without optimization
--Hash operator materializes a hash table for drinkers
--DS_BCAST_INNER on hash join indicates an expensive network operation because
--the intermediate results of the hash table need to be broadcasted between all of the nodes
--in order to insure that the join keys are present everywhere they are needed.
--this is a N*(N-1) operation... where N is the number of slices
explain select
	beer
	,favorite_instrument
	,count(distinct d.user_id)
from
	beer.events e
	inner join
	beer.drinkers d
		on
			e.user_id=d.user_id
			and
			d.company='venus.com'
group by
	beer
	,favorite_instrument;

--with optimization
--merge join is possible because both tables are sorted on join key
--and distributed on the same key.  all data is
--colocated and sorted, so it joins like a zipper!
--this query runs an average of twice as fast as the original tables
--note that you need to keep your tables vacuumed in order to keep
--the performance benefit of a merge join
explain select
	beer
	,favorite_instrument
	,count(distinct d.user_id)
from
	beer.events2 e
	inner join
	beer.drinkers2 d
		on
			e.user_id=d.user_id
			and
			d.company='venus.com'
group by
	beer
	,favorite_instrument;
	
--BONUS GOTCHA!!!
--when distributing multiple tables on the same key... 
---the column data types must match exactly... not just the values.
--the value 'hello' will be distributed differently 
--for varchar(32) than it will for varchar(33)