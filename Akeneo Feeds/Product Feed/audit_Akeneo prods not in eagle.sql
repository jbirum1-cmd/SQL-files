--gets all akeneo products that are not from adc, homesource, or kits
drop table if exists #akeneoprods
select
trim(sku) as sku
into #akeneoprods
from integration.pim.allproductstable 
where core_product_data_source not in ('adc','homesource','natord-kit')

--gets all Eagle products in designated stores
drop table if exists #eagleprods
select
replace(replace(trim(in_item_number), '-FBA', ''),'(A)','') as sku
into #eagleprods
from sqleagle.hh.view_in_clone
where in_store IN ('1','2','4','7','8','12','18')

--looks for akeneo products not in eagle
select
a.sku as akeneo_sku,
e.sku as eagle_sku
from #akeneoprods a
left join #eagleprods e
on a.sku = e.sku
where e.sku is null

