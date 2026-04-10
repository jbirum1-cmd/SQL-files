--creates homesource exclusion
drop table if exists #homesource
select 
sku
into #homesource
from titan.integration.dbo.centerspecappliances
where obsoletedate is null

--gets erp date for kits
drop table if exists #kits1
select
k.sku,
k.component_sku,
cast(s.create_dtm as date) as create_dtm
into #kits1
from titan.live.dbo.kitting k
join titan.live.dbo.sku s
on k.component_sku = s.sku
order by k.sku

--select * from #kits1 where sku = '1782173K1'

drop table if exists #kits2
select
k.sku,
max(k.create_dtm) as erp_create_date
into #kits2
from #kits1 k
join pim.allproductstable p
on k.sku = p.identifier
where p.core_product_data_source = 'NatOrd-Kit'
group by k.sku

--gets erp date for products
drop table if exists #products
select
trim(d.dwin_item_number) as sku,
min(cast(d.dwin_record_added_date as date)) as erp_create_date
into #products
from sqleagle.hh.dw_item d
where dwin_store = 'm' 
and not exists (
	select 1
	from #kits2 k
	where k.sku = trim(d.dwin_item_number))
group by trim(dwin_item_number)

--select * from sqleagle.hh.dw_item where trim(dwin_item_number) = '1782173K1'


--unions all skus together
drop table if exists #union
select * 
into #union
from #kits2

union

select * 
from #products

--select * from #union

--puts sandbox skus not assigned to families into a table for exclusion
drop table if exists #exclusion
SELECT [uuid]
      ,[identifier]
      ,[json]
      ,[record_insert_date]
into #exclusion
  FROM [Integration].[PIM].[AllProducts]
  where json like '%family%' and json_value(json, '$.family') is null

--compares calculated erp create date to product feed (checks for correct date in program)
select
p.identifier,
cast(p.erp_sku_create_date as date) as feed_date,
u.erp_create_date as calculated_date,
case when
	(p.erp_sku_create_date = u.erp_create_date) or (p.erp_sku_create_date is null and u.erp_create_date is null)
	then 'true'
	else 'false'
	end as date_compare
from pim.Product_Feed_Full p
left join #union u
on p.identifier = u.sku
 where case when
	p.erp_sku_create_date = u.erp_create_date or (p.erp_sku_create_date is null and u.erp_create_date is null)
	then 'true'
	else 'false'
	end = 'false'
	and p.product_trace <> 'akeneo only'

--compares calculated date to akeneo (checks that program is updating end system)
select
p.identifier,
cast(p.erp_sku_create_date as date) as akeneo_date,
u.erp_create_date as calculated_date,
case when
	p.erp_sku_create_date = u.erp_create_date
	then 'true'
	else 'false'
	end as date_compare,
f.product_trace
from pim.AllProductsTable p
join #union u
on p.identifier = u.sku
join pim.Product_Feed_Full f
on f.identifier = p.identifier
where case when
	p.erp_sku_create_date = u.erp_create_date
	then 'true'
	else 'false'
	end = 'false'
and not exists (
	select 1
	from #exclusion e
	where e.identifier = trim(p.identifier))
and not exists (
	select 1
	from #homesource h
	where h.sku = p.identifier)
and f.product_trace <> 'akeneo only'

/*testing
select * from titan.live.dbo.kitting where sku = 'T577383'
select * from titan.live.dbo.sku where sku = '1731263'

select
sku,
active_flag,
create_dtm
from titan.live.dbo.sku where sku in ('34549','1901639','1460012')

select * 
from pim.Product_Feed_previous
where identifier = '1869245'

select * 
from sqleagle.hh.dw_item
where trim(dwin_item_number) = '1861043'
and dwin_store = 'M'

*/