--OPTIMIZE FOR PREDICATES

--we are going to optimize the tables for use in where clause
--filters based upon the company, user_id, and beer_opened_time

--in this table note we set the top sort order key to raw encoding.
--this will store the company data uncompressed.
-- light compression is okay to apply here

drop table if exists beer.drinkers3 cascade;
create table if not exists beer.drinkers3
(
	id integer
	,user_id char(32) encode lzo
	,first_name varchar(32) encode bytedict
	,last_name varchar(32) encode bytedict
	,company varchar(64) encode raw --we put raw encoding on the top sort order field
	,school varchar(128) encode bytedict
	,superhero_power varchar(64) encode bytedict
	,good_tipper boolean encode runlength
	,favorite_instrument varchar(64) encode lzo
	,zip_code char(5) encode lzo
)
distkey(user_id)
sortkey(company,user_id);

--this table is sorted by the timestamp allowing for 
--range restricted scans. 
--this also makes it faster to roll off data in the future
drop table if exists beer.events3 cascade;
create table if not exists beer.events3
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
sortkey(beer_opened_time);

insert into beer.drinkers3 select * from beer.drinkers2;
insert into beer.events3 select * from beer.events2;

analyze beer.events3;
analyze beer.drinkers3;

--the explain plans for the following queries have similar seq scan operators.
--note that the second query has lower cost for each seq scan
--the reality of the sorting and compression isn't always well quantified
--by the explain plan cost... but the timings make it clear 
explain select
	beer
	,count(distinct user_id)
from
	beer.events
where
	beer_opened_time between '2016-11-01' and '2016-11-04'
group by
	beer;
	
--this set of tables delivers the results with subsecond timing
--after the first run.  this is due to the exexcution plan being 
--compiled already after the first run.
explain select
	beer
	,count(distinct user_id)
from
	beer.events3
where
	beer_opened_time between '2016-11-01' and '2016-11-04'
group by
	beer;
	
--this query accesses approximately the same number of records ~3.5M
--but it takes much longer
--that is because redshift is unable to identify which blocks it needs
--to pull from disk because the column is not sorted at all.
--the table ends up getting scanned in this case.
explain select
	beer
	,count(distinct user_id)
from
	beer.events3
where
	schmooziest_buzzword in 
		('3rd generation',
		'4th generation',
		'5th generation',
		'6th generation',
		'Adaptive',
		'Advanced',
		'Ameliorated',
		'Assimilated',
		'Automated',
		'Balanced')
group by
	beer;
	
select
	beer
	,count(distinct user_id)
from
	beer.events
where
	schmooziest_buzzword in 
		('3rd generation',
		'4th generation',
		'5th generation',
		'6th generation',
		'Adaptive',
		'Advanced',
		'Ameliorated',
		'Assimilated',
		'Automated',
		'Balanced')
group by
	beer;