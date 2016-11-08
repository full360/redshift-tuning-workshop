--http://docs.aws.amazon.com/redshift/latest/dg/c_Compression_encodings.html

--stv_blocklist stores metadata for every 1MB disk block used to store the actual data
--min and max value columns represent 8 byte varchar prefix or underlying integer value

select * from stv_blocklist limit 100;

--redshift uses table ids in some of the system tables and views.
--system tables don't necessarily join very well because they are postgres "objects"... so it's easiest to get
--the table ids directly from stv_tbl_perm and overwriting them directly into the query
select distinct
	name
	,id 
from 
	stv_tbl_perm
where
	name in ('events','events2');

--plug the ids into the following query
select 
	*
	--the compression factor shows how effective the compression is
	--higher numbers are better.  numbers less than 1 indicate a 
	--disk footprint larger than the uncompressed data set
	,1 / (optimized_block_count::float / unoptimized_block_count) as compression_factor
from
	(select
		col
		--blocks per column for unoptimized table
		,sum(case when tbl = 118072 then 1 else 0 end) as unoptimized_block_count
		
		--blocks per column for optimized table
		,sum(case when tbl = 127898 then 1 else 0 end) as optimized_block_count
	from 
		stv_blocklist
	where
		tbl in (118072, 127898)
	group by 
		col) sq
order by 
  1;
  
--columns 10-12 are system columns
--0-9 represent the actual data columns
--notice that column 2 has a high compression factor
--this is due to the data being sorted by this column, and having repeated values
--while a merge join is fun, this approach may not scale...
--join is optimized but predicate filters are not.  as the data set grows
--the seq scans may become less and less efficient

--be mindful to not distribute using a column containing a large number of nulls, or other default value
--also note that base64 encoded keys generated by hashing algorithms (md5, sha1) do not compress very
--well when they are unique keys as there is little repetition within the values, or between rows.
--in cases like this you may wish to use raw encoding type... which is "no" compression... as it will
--free up CPU power at load and query time.

--the query below is a sweet little bonus for you!
--it allows you to see the minimum and maximum character values
--in each block!
select 
	chr(abs((minvalue) % 256)::smallint)||
	chr(abs((minvalue >> 8) % 256)::smallint)||
	chr(abs((minvalue >> 16) % 256)::smallint)||
	chr(abs((minvalue >> 24) % 256)::smallint)||
	chr(abs((minvalue >> 32) % 256)::smallint)||
	chr(abs((minvalue >> 40) % 256)::smallint)||
	chr(abs((minvalue >> 48) % 256)::smallint)||
	chr(abs((minvalue >> 56) % 256)::smallint),

	chr(abs((maxvalue) % 256)::smallint)||
	chr(abs((maxvalue >> 8) % 256)::smallint)||
	chr(abs((maxvalue >> 16) % 256)::smallint)||
	chr(abs((maxvalue >> 24) % 256)::smallint)||
	chr(abs((maxvalue >> 32) % 256)::smallint)||
	chr(abs((maxvalue >> 40) % 256)::smallint)||
	chr(abs((maxvalue >> 48) % 256)::smallint)||
	chr(abs((maxvalue >> 56) % 256)::smallint)
	,*
from 
	stv_blocklist 
where 
	tbl = 118072 
	and 
	col = 6;