--select top 10 *
--from titan.live.dbo.product_warehouse

--gets all elig kit skus
drop table if exists #kits
select
replace(replace(replace(replace(trim(k.sku),'-FBA',''),'(A)',''),'(B)',''),'.old','') as sku
into #kits
from titan.live.dbo.kitting k
join titan.live.dbo.sku s
on s.sku = k.sku
where s.active_flag = 'Y'

--gets pre-existing kits in Akeneo
drop table if exists #akeneoprods
select
trim(sku) as sku
into #akeneoprods
from integration.pim.allproductstable 
where core_product_data_source in ('NatOrd-Kit')

--unions into one table
drop table if exists #union
select *
into #union
from #kits

union

select *
from #akeneoprods

--joins sku list to NO for warehouse codes
drop table if exists #whdata
select distinct
u.sku,
p.warehouse_code,
case when 
	p.warehouse_code = 'HHH' then '1'
	when p.warehouse_code = 'HTOOL' then '2'
	when p.warehouse_code = 'LHAK' then '7'
	when p.warehouse_code = 'LHAD' then '8'
	else null
	end as 'store_location'
into #whdata
from #union u
left join titan.live.dbo.product_warehouse p
on u.sku = trim(p.sku)

--creates string
drop table if exists #string
select
sku,
STRING_AGG(CAST(store_location AS varchar(10)), ',') 
        WITHIN GROUP (ORDER BY store_location) AS NO_store_location
into #string
from #whdata
group by sku

--pulls in Akeneo data
drop table if exists #compare
select
s.sku as eagle_sku,
p.sku as akeneo_sku,
isnull(s.no_store_location, 0) as warehouse_locations,
isnull(replace(replace(replace(p.in_stores, '[',''),']',''),'"',''),0) as akeneo_store_locations
into #compare
from #string s
left join pim.allproductstable p
on s.sku = p.sku

--displays discrepancies
select distinct
eagle_sku,
akeneo_sku,
warehouse_locations,
akeneo_store_locations,
case when
    warehouse_locations = akeneo_store_locations
    then 'true'
    else 'false'
    end as location_compare
from #compare
where 
case when
    warehouse_locations = akeneo_store_locations
    then 'true'
    else 'false'
    end = 'false'

/*
discrepancy example
select * from #compare where eagle_sku in ('100015016','1000686192','B1PD5173')
select * from titan.live.dbo.product_warehouse where sku in ('100015016','1000686192','B1PD5173')
select * from titan.live.dbo.kitting where sku in ('100015016','1000686192','B1PD5173')
select * from sqleagle.hh.view_in_clone where trim(in_item_number) in ('100015016','1000686192','B1PD5173')
*/