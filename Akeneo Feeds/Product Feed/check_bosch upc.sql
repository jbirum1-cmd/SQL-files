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
b.sku,
trim(a.an_upc_number) as eagle_upc,
b.upc as homesource_upc,
case when
	trim(a.an_upc_number) = b.upc
	then 'true'
	else 'false'
	end as upc_check
from sqleagle.hh.anupc a
join #bosch b
on trim(a.an_upc_number_sku) = b.sku
--case when
--	a.upc = b.upc
--	then 'true'
--	else 'false'
--	end = 'false'