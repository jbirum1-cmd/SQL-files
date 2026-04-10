--select * from titan.integration.dbo.centerspecspecs
--where specvalue like '%upc%'
--select * from titan.integration.dbo.centerspecappliances
--where apid = '108344'

--gets UPCs for Bosch appliances
drop table if exists #bosch
select
a.sku,
replace(s.specvalue,'upc code: ','') as upc
into #bosch
from titan.integration.dbo.centerspecappliances a
left join titan.integration.dbo.centerspecspecs s
on a.apid = s.apid
where a.manufacturerid = '21' and specvalue like '%upc%'

--compares Bosch UPCs to current Akeneo values
select
a.identifier,
a.upc as akeneo_upc,
b.upc as homesource_upc,
case when
	a.upc = b.upc
	then 'true'
	else 'false'
	end as upc_check
from integration.pim.allproductstable a
join #bosch b
on a.identifier = b.sku
where a.shopify_status <> 'archive' and
case when
	a.upc = b.upc
	then 'true'
	else 'false'
	end = 'false'