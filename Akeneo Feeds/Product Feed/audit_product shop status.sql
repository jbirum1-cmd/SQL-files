--gets all existing Akeneo skus and current shopify status
drop table if exists #akeneoskus
select
trim(sku) as sku,
shopify_status
into #akeneoskus
from integration.pim.allproductstable 

--gets all eligible eagle products
drop table if exists #eagleprods
select
replace(replace(trim(in_item_number), '-FBA', ''),'(A)','') as sku,
'Eagle' as source
into #eagleprods
from sqleagle.hh.view_in_clone
where in_privatefromecommercefg in ('C','O','N') and in_store IN ('1','2','4','7','8','12','18')

--gets all eligible kits from NO
drop table if exists #kits
select
replace(replace(trim(k.sku),'-FBA',''),'(A)','') as sku,
'NO' as source
into #kits
from titan.live.dbo.kitting k
join titan.live.dbo.sku s
on s.sku = k.sku
where s.active_flag = 'Y'

--unions eagle & NO products
drop table if exists #alleligprods
select * 
into #alleligprods
from #eagleprods

union all

select * 
from #kits

--looks for new products
select
e.sku,
e.source
from #alleligprods e
left join #akeneoskus a
on e.sku = a.sku
where a.sku is null