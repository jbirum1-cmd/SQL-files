--gets elig eagle products
drop table if exists #eagleprods
select
replace(replace(trim(in_item_number), '-FBA', ''),'(A)','') as sku
into #eagleprods
from sqleagle.hh.view_in_clone v
where in_privatefromecommercefg in ('C','O','N') and in_store IN ('1','2','4','7','8','D','J')
and not exists (
	select 1
	from titan.live.dbo.kitting k
	where k.sku = trim(v.in_item_number))

--gets pre-existing akeneo skus where source is eagle
drop table if exists #akeneoprods
select
trim(sku) as sku
into #akeneoprods
from integration.pim.allproductstable 
where core_product_data_source in ('eagle')

--unions skus 
drop table if exists #union
select *
into #union
from #eagleprods

union

select * 
from #akeneoprods

--excludes appliances
drop table if exists #allskus
select
sku
into #allskus
from #union u
where not exists (
	select 1
	from titan.integration.dbo.centerspecappliances c
	where c.sku = u.sku)


--joins back to Eagle for store locations
drop table if exists #stores
select
a.sku,
v.in_store
into 
#stores
from #allskus a
left join sqleagle.hh.view_in_clone v
on a.sku = replace(replace(trim(in_item_number), '-FBA', ''),'(A)','')
where v.in_privatefromecommercefg in ('C','O','N') and v.in_store IN ('1','2','4','7','8','D','J')

--creates store string
drop table if exists #string
select
sku,
STRING_AGG(CAST(in_store AS varchar(10)), ',') 
        WITHIN GROUP (ORDER BY in_store) AS eagle_store_location
into #string
from #stores
group by sku

--compares to Akeneo
drop table if exists #compare
select
s.sku, 
isnull(replace(replace(s.eagle_store_location,'D','12'),'J','18'), 0) as eagle_store_locations,
isnull(replace(replace(replace(p.in_stores, '[',''),']',''),'"',''),0) as akeneo_store_locations
into #compare
from #string s
join pim.allproductstable p
on s.sku = p.sku

--displays discrepancies
select distinct
sku,
eagle_store_locations,
akeneo_store_locations,
case when
    eagle_store_locations = akeneo_store_locations
    then 'true'
    else 'false'
    end as location_compare
from #compare
where 
case when
    eagle_store_locations = akeneo_store_locations
    then 'true'
    else 'false'
    end = 'false'

