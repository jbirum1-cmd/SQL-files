--gets amazon pending
drop table if exists #ap
	select isnull(sx.sku, a.sku) as sku, sum(quantityOrdered) as quantityOrdered into #ap from titan.Integration.dbo.amazonpending a
		LEFT JOIN titan.Integration.dbo.skuxref sx ON a.sku = sx.amazonsku
		group by isnull(sx.sku, a.sku) 

--gets stock pit for homesource
	drop table if exists #HS
	select distinct sku, stock_pit into #HS from Titan.integration.dbo.centerspecappliances with(nolock) where obsoleteDate is null

--gets shopify product skus and inv data from eagle hh
drop table if exists #products
select distinct
trim(v.in_item_number) as sku,
v.in_quantity_on_hand,
v.in_committed_quantity,
v.in_sfty_stk
into #products
from sqleagle.hh.view_in_clone v
--join Integration.INV.ShopifyVariants sv
--on trim(v.in_item_number) = sv.sku
--join INV.ShopifyLocationMap sm
--on sm.parentid = sv.id
where v.in_store = '4' --and sv.environment <> 'production' and sm.id = 'gid://shopify/Location/79232434312'

 --gets shopify product skus from Homesource
 drop table if exists #homesource
select distinct
c.sku
into #homesource
from titan.integration.dbo.centerspecappliances c
--join Integration.INV.ShopifyVariants sv
--on c.sku = sv.sku
--join INV.ShopifyLocationMap sm
--on sm.parentid = sv.id
where c.obsoletedate is null --and sv.environment <> 'production' and sm.id = 'gid://shopify/Location/79232434312'

 --unions products and homesource
drop table if exists #total
 select 
 sku
 into #total
 from #products

 union 

 select
 sku
 from #homesource

 --pulls in inventory data for total skus
 drop table if exists #format
 select
 t.sku,
 sum(isnull(p.in_quantity_on_hand,0)) as in_quantity_on_hand,
 sum(isnull(p.in_committed_quantity,0)) as in_committed_quantity,
 sum(isnull(p.in_sfty_stk,0)) as in_sfty_stk,
 sum(isnull(ap.quantityOrdered,0)) as amazon_pending,
 sum(isnull(hs.stock_pit,0)) as stock_pit
 into #format
 from #total t
 left join #ap ap
 on ap.sku = t.sku
 left join #HS hs
 on hs.sku = t.sku
 left join #products p
 on p.sku = t.sku
 group by t.sku

 --calculates inventory for products
 drop table if exists #productinventory
 select
 sku,
 in_quantity_on_hand,
 in_committed_quantity,
 in_sfty_stk,
 amazon_pending,
 stock_pit,
 floor(IIF(in_quantity_on_hand - in_committed_quantity - in_sfty_stk - amazon_pending + stock_pit < 0, 0, in_quantity_on_hand - in_committed_quantity - in_sfty_stk - amazon_pending + stock_pit))  as total_product_inventory
 into #productinventory
 from #format
 group by sku, in_quantity_on_hand, in_committed_quantity, in_sfty_stk, amazon_pending, stock_pit
 order by sku

 --calculated kit inventory 
 drop table if exists #kits
 select
 k.sku,
 min(floor(IIF((f.in_quantity_on_hand - f.in_committed_quantity - f.in_sfty_stk - f.amazon_pending + f.stock_pit)/ k.component_quantity < 0, 0, (f.in_quantity_on_hand - f.in_committed_quantity - f.in_sfty_stk - f.amazon_pending + f.stock_pit)/ k.component_quantity)))  as total_kit_inventory
 into #kits
 from #format f
 join titan.live.dbo.kitting k
 on k.component_sku = f.sku
 group by k.sku

--select * from #total where sku in ( '1806692','1806695','1806701') 

 --joins together prod & kit inventory
 drop table if exists #join
 select 
 f.sku,
p.total_product_inventory,
k.total_kit_inventory
into #join
from #format f
left join #productinventory p
on p.sku = f.sku
left join #kits k
on k.sku = f.sku

--coalesces kit inventory then product inventory
select distinct
coalesce(total_kit_inventory,total_product_inventory) as total_inventory,
j.sku
from Integration.INV.ShopifyVariants sv
left join #join j
on j.sku = sv.sku
left join INV.ShopifyLocationMap sm
on sm.parentid = sv.id
where sv.environment <> 'production' and sm.id = 'gid://shopify/Location/79232401544'
order by sku