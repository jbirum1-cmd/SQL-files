--gets all primary upcs from eagle where exists
drop table if exists #eagleprimary
select distinct
replace(replace(trim(v.in_item_number), '-FBA', ''),'(A)','') as sku,
trim(u.an_upc_number) as an_upc_number
into #eagleprimary
from sqleagle.hh.view_in_clone v
join sqleagle.hh.anupc u
on replace(replace(trim(v.in_item_number), '-FBA', ''),'(A)','') = replace(replace(trim(u.an_upc_number_sku), '-FBA', ''),'(A)','')
where u.an_upc_primary_flag = 'Y' and  len(trim(u.an_upc_number)) in (12,13)

--select * from #eagleprimary where sku in ('DAR016B1BM') order by sku

--gets max update date for mupcs
drop table if exists #maxdatemupc
select distinct
replace(replace(trim(u.an_upc_number_sku), '-FBA', ''),'(A)','') as sku,
max(u.an_upc_db_update_datetime) as max_date
into #maxdatemupc
from sqleagle.hh.anupc u
where u.an_upc_source = 'm' and len(trim(u.an_upc_number)) in (12,13)
group by u.an_upc_number_sku

--gets all MUPCs from eagle where exists
drop table if exists #eaglemupc
select distinct
replace(replace(trim(v.in_item_number), '-FBA', ''),'(A)','') as sku,
trim(u.an_upc_number) as an_upc_number
into #eaglemupc
from sqleagle.hh.view_in_clone v
join sqleagle.hh.anupc u
on replace(replace(trim(v.in_item_number), '-FBA', ''),'(A)','') = replace(replace(trim(u.an_upc_number_sku), '-FBA', ''),'(A)','')
join #maxdatemupc mu
on replace(replace(trim(u.an_upc_number_sku), '-FBA', ''),'(A)','') = mu.sku and u.an_upc_db_update_datetime = mu.max_date
where u.an_upc_source = 'M' --and len(trim(u.an_upc_number)) in (12,13)

--gets any valid 12 or 13 digit upc
drop table if exists #validrecords
select distinct
replace(replace(trim(u.an_upc_number_sku), '-FBA', ''),'(A)','') as sku,
trim(u.an_upc_number) as an_upc_number,
u.an_upc_db_update_datetime
into #validrecords
from sqleagle.hh.view_in_clone v
join sqleagle.hh.anupc u
on replace(replace(trim(v.in_item_number), '-FBA', ''),'(A)','') = replace(replace(trim(u.an_upc_number_sku), '-FBA', ''),'(A)','')
where len(trim(u.an_upc_number)) in (12,13)

--gets max date for those valid upcs
drop table if exists #maxdate
select distinct
sku,
max(u.an_upc_db_update_datetime) as max_date
into #maxdate
from #validrecords u
group by sku

--joins record with max date
drop table if exists #eaglemax
select distinct
replace(replace(trim(u.an_upc_number_sku), '-FBA', ''),'(A)','') as sku,
trim(u.an_upc_number) as an_upc_number
into #eaglemax
from sqleagle.hh.anupc u
join #maxdate m
on replace(replace(trim(u.an_upc_number_sku), '-FBA', ''),'(A)','') = m.sku and u.an_upc_db_update_datetime = m.max_date
where len(trim(u.an_upc_number)) in (12,13)

--joins all eagle tables 
drop table if exists #eagleproducts
select distinct
replace(replace(trim(v.in_item_number), '-FBA', ''),'(A)','') as sku,
p.an_upc_number as primary_upc,
mu.an_upc_number as mupc,
m.an_upc_number as upc_last_used
into #eagleproducts
from sqleagle.hh.view_in_clone v
left join #eagleprimary p
on replace(replace(trim(v.in_item_number), '-FBA', ''),'(A)','') = p.sku
left join #eaglemupc mu
on replace(replace(trim(v.in_item_number), '-FBA', ''),'(A)','') = mu.sku
left join #eaglemax m
on replace(replace(trim(v.in_item_number), '-FBA', ''),'(A)','') = m.sku
where in_store = 'm'

--select * from #eagleproducts where sku in ('DAR016B1BM') order by sku

--coalesce
drop table if exists #eagleupc
select distinct
p.sku,
coalesce(p.primary_upc,p.mupc,p.upc_last_used) as upc
into #eagleupc
from #eagleproducts p
join pim.AllProductsTable a
on a.identifier = p.sku 
where a.core_product_data_source in ('eagle','homesource')
--select * from #eagleupc where sku = 'DAR016B1BM'

--kit upcs
drop table if exists #kit
select distinct
k.sku,
trim(u.upc) as upc
into #kit
from titan.live.dbo.kitting k
left join titan.live.[dbo].[upc] u
on u.sku = k.sku
--left join titan.live.dbo.sku s
--on s.sku = k.sku
where len(trim(u.upc)) in (12,13) -- and s.active_flag = 'Y' 

--select * from titan.live.dbo.kitting where sku = '1738340'
--select * from #kit where sku = '1738340'

--unions eagle products & kits
drop table if exists #union 
select * 
into #union
from #eagleupc

union all

select * from #kit

--select * from #union where sku = '1738340'

--compare calculated UPCs with Stored proc product feed full
select 
a.identifier,
a.upc as program_upc,
u.upc as systems_upc,
case when
	(a.upc = u.upc) OR (a.upc IS NULL AND u.upc IS NULL)
	then 'true'
	else 'false'
	end as upc_compare
from pim.Product_Feed_Full a
left join #union u
on a.identifier = u.sku
where case when
	(a.upc = u.upc) OR (a.upc IS NULL AND u.upc IS NULL) 
	then 'true'
	else 'false'
	end = 'false'
order by a.identifier



--then compare full table to akeneo all products and filter out nulls on previous table
select
f.identifier,
f.upc as program_upc,
a.upc as akeneo_upc,
case when
	f.upc = a.upc
	then 'true'
	else 'false'
	end as upc_compare
from pim.Product_Feed_Full f
join pim.AllProductsTable a
on f.identifier = a.identifier
where f.upc is not null and
	case when
	f.upc = a.upc
	then 'true'
	else 'false'
	end = 'false'

--testing
--select
--replace(replace(trim(in_item_number), '-FBA', ''),'(A)','') as sku,
--in_privatefromecommercefg,
--in_store
--from sqleagle.hh.view_in_clone
--where replace(replace(trim(in_item_number), '-FBA', ''),'(A)','') = '302832'

--select 
--trim(an_upc_number_sku) as sku,
--an_upc_primary_flag,
--an_upc_source,
--an_upc_db_update_datetime,
--an_upc_db_update_datetime,
--trim(an_upc_number) as upc
--from sqleagle.hh.anupc
--where trim(an_upc_number_sku) in ('100005011') order by sku


--select * from titan.live.[dbo].[upc]
--where sku in ('100005011','100004308')

