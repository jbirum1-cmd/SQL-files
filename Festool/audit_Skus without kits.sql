drop table if exists #notkit
select distinct
trim(in_item_number) as sku
into #notkit
from hh.view_in_clone
where in_manufacturer in ('fest','stabl') and trim(in_item_number) not like '%zz%' and in_store in ('1', '2') and (in_discontinued <> 'Y'  or ISNULL(in_quantity_on_hand, 0) > 0)

--select * from #notkit where sku = '1234181'



drop table if exists #skus
select distinct
u.sku
into #skus
from #notkit u
join integration.INV.ShopifyVariants sv
on sv.sku = u.sku
JOIN integration.INV.ShopifyProducts sp 
ON sp.id = sv.ProductId
where sp.status <> 'draft' and sp.Environment = 'Sandbox'

select * from #skus