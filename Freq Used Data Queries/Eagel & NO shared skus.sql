--looks for skus that exist in both Eagle & NO
select distinct
k.sku as kit_sku,
trim(v.in_item_number) as eagle_sku,
s.active_flag as kit_active_flag,
v.in_discontinued as eagle_discontinued,
v.in_item_description as eagle_description,
p.product_name as kit_description
from titan.live.dbo.kitting k
join titan.live.dbo.sku s
on k.sku = s.sku
join sqleagle.hh.view_in_clone v
on trim(v.in_item_number) = s.sku
join titan.live.[dbo].[products] p
on p.product_number = k.sku
where s.active_flag <> 'n'
order by k.sku

--select * from titan.live.[dbo].[products]
--where product_number = '52278'

/*
52278 - tied to two different products between eagle & NO
*/
