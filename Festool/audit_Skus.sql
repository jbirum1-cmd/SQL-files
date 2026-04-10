drop table if exists #notkit
select distinct
trim(in_item_number) as sku,
in_manufacturer
into #notkit
from hh.view_in_clone
where in_manufacturer in ('fest','05112') and trim(in_item_number) not like '%zz%' and in_store in ('1', '2','4') and (in_discontinued <> 'Y'  or ISNULL(in_quantity_on_hand, 0) > 0)

--select * from #notkit where sku = '1234181'

drop table if exists #kit
select distinct
trim(k.sku) as sku,
in_manufacturer
into #kit
from Titan.live.dbo.kitting k
JOIN sqleagle.HH.view_in_clone v
  ON trim(v.in_item_number) = k.component_sku
where v.in_manufacturer in ('fest','05112') and trim(v.in_item_number) not like '%zz%' and v.in_store in ('1', '2','4') and (v.in_discontinued <> 'Y'  or ISNULL(in_quantity_on_hand, 0) > 0)

--select * from #kit where sku = '1234181'

drop table if exists #union
select 
nk.sku,
nk.in_manufacturer
into #union
from #notkit nk

union all

select
k.sku,
k.in_manufacturer
from #kit k

drop table if exists #skus
select distinct
u.sku,
u.in_manufacturer
into #skus
from #union u
join integration.INV.ShopifyVariants sv
on sv.sku = u.sku
JOIN integration.INV.ShopifyProducts sp 
ON sp.id = sv.ProductId
where sp.status <> 'draft' and sp.Environment = 'Sandbox'

--select * from #skus 

--select * from hh.view_in_clone where trim(in_item_number) = '1654928'

