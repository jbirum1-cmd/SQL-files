--gets all akeneo products that are not from adc, homesource, or eagle
drop table if exists #akeneoprods
select
trim(sku) as sku
into #akeneoprods
from integration.pim.allproductstable 
where core_product_data_source not in ('adc','homesource','eagle','LEH import')

--gets all NO kits
drop table if exists #kits
select
replace(replace(trim(k.sku),'-FBA',''),'(A)','') as sku
into #kits
from titan.live.dbo.kitting k

--looks for akeneo kits not in NO
select
a.sku as akeneo_sku,
k.sku as natorder_sku
from #akeneoprods a
left join #kits k
on a.sku = k.sku
where k.sku is null
