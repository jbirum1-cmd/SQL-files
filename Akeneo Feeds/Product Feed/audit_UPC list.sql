--select * from sqleagle.hh.anupc
--order by an_upc_number_sku

--gets all elig products
drop table if exists #eagleprods
select
replace(replace(trim(in_item_number), '-FBA', ''),'(A)','') as sku,
'Eagle' as source
into #eagleprods
from sqleagle.hh.view_in_clone
where in_privatefromecommercefg in ('C','O','N') and in_store IN ('1','2','4','7','8','12','18')

drop table if exists #kits
select
replace(replace(trim(k.sku),'-FBA',''),'(A)','') as sku,
'NatOrd-Kit' as source
into #kits
from titan.live.dbo.kitting k
join titan.live.dbo.sku s
on s.sku = k.sku
where s.active_flag = 'Y'

drop table if exists #akeneoprods
select
trim(sku) as sku,
core_product_data_source as source
into #akeneoprods
from integration.pim.allproductstable 
where core_product_data_source in ('eagle','NatOrd-Kit')

drop table if exists #allskus
select *
into #allskus
from #eagleprods

union all

select * 
from #kits

union all 

select * 
from #akeneoprods

--joins eagle source skus with eagle upc table & kits with NO upc table
drop table if exists #eagleupc
select 
a.sku,
a.source,
trim(u.an_upc_number_sku) as upc_sku,
u.an_upc_number as upc_number,
u.an_upc_source as upc_source,
u.an_upc_primary_flag as upc_primary_flag,
u.an_upc_db_update_datetime as upc_datetime
into #eagleupc
from #allskus a
left join sqleagle.hh.anupc u
on a.sku = trim(u.an_upc_number_sku)
where a.source = 'Eagle'
order by sku

drop table if exists #kitupc
select distinct
a.sku,
a.source,
trim(u.sku) as upc_sku,
u.upc as upc_number,
'' as upc_source,
'' as upc_primary_flag,
'' as upc_datetime
into #kitupc
from #allskus a
left join titan.live.[dbo].[upc] u
on a.sku = trim(u.sku)
where a.source = 'NatOrd-Kit'
order by sku

drop table if exists #union
select * 
into #union
from #eagleupc

union all

select * 
from #kitupc

select distinct * from #union
order by sku