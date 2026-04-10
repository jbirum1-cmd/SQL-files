--gets UPCs for Bosch appliances
drop table if exists #bosch
select
a.sku,
'Bosch' as brand,
replace(s.specvalue,'upc code: ','') as upc,
a.obsoletedate
into #bosch
from titan.integration.dbo.centerspecappliances a
left join titan.integration.dbo.centerspecspecs s
on a.apid = s.apid
where a.manufacturerid = '21' and specvalue like '%upc%'

--gets all other appliance skus
drop table if exists #otherhomesourceskus
select
sku,
'Other' as brand,
'' as upc,
obsoletedate
into #otherhomesourceskus
from titan.integration.dbo.centerspecappliances  c
where NOT EXISTS 
	( select 1
	from #bosch b
	where b.sku = c.sku);

--unions together
drop table if exists #union
select *
into #union
from #bosch

union all

select *
from #otherhomesourceskus

--calculates upc_not_exist
drop table if exists #upcnotexists
select 
u.sku,
u.obsoletedate,
a.upc,
a.upc_no_exist as akeneo_upc_no_exist,
a.shopify_status,
case when
	u.brand = 'bosch' or a.upc is not null
	then 'false'
	else 'true'
	end as upc_not_exists_calculated
into #upcnotexists 
from #union u
join integration.pim.allproductstable a
on a.identifier = u.sku


--compares upc not exist field to akeneo 
select
sku,
obsoletedate,
upc,
upc_not_exists_calculated,
akeneo_upc_no_exist,
case when
	upc_not_exists_calculated = akeneo_upc_no_exist
	then 'true'
	else 'false'
	end as upc_no_exist_check
from #upcnotexists 
where shopify_status <> 'archive' and
	case when
		upc_not_exists_calculated = akeneo_upc_no_exist
	then 'true'
	else 'false'
	end = 'false'
