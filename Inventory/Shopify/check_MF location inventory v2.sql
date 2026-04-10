--gets amazon pending
drop table if exists #ap
	select isnull(sx.sku, a.sku) as sku, sum(quantityOrdered) as quantityOrdered into #ap from titan.Integration.dbo.amazonpending a
		LEFT JOIN titan.Integration.dbo.skuxref sx ON a.sku = sx.amazonsku
		group by isnull(sx.sku, a.sku) 

--gets open orders
	drop table if exists #shopOpen
	select sku, sum(quantity_ordered - canceled_quantity) as quantityOrdered 
		into #shopOpen
		from titan.testing.dbo.orders o with(nolock)
		inner join titan.testing.dbo.udf_order u with(nolock) on u.order_number = o.order_number and udf_code = 'hhcv3'
		left join titan.testing.dbo.line_item li with(nolock) on li.order_number = o.order_number
		where o.status_code not in ('C','X') and o.warehouse_code = 'HHH'
		group by sku

	
--gets product reserve
	drop table if exists #pw
		select distinct sku
		   , MAX(CASE WHEN warehouse_code = 'HHH' then product_reserve_quantity end) AS st1ProductReserve 
		   , MAX(CASE WHEN warehouse_code = 'HTOOL' then product_reserve_quantity end) AS st2ProductReserve 
		   , MAX(CASE WHEN warehouse_code = 'LHAK' then product_reserve_quantity end) AS st7ProductReserve 
		   , MAX(CASE WHEN warehouse_code = 'LHAD' then product_reserve_quantity end) AS st8ProductReserve 
		   into #pw
		   from datawarehouse.livedb.product_warehouse (nolock)
		   group by sku

--gets stock pit for homesource
	drop table if exists #HS
	select distinct sku, stock_pit into #HS from Titan.integration.dbo.centerspecappliances with(nolock) where obsoleteDate is null

	--select * from #HS where sku = '08F175Y'

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
 sum(isnull(pw.st1ProductReserve,0)) as st1ProductReserve,
 sum(isnull(p.in_sfty_stk,0)) as in_sfty_stk,
 sum(isnull(ap.quantityOrdered,0)) as amazon_pending,
 sum(isnull(so.quantityOrdered,0)) as shop_open_orders,
 iif(sum(isnull(hs.stock_pit,0)) < 0, 0, sum(isnull(hs.stock_pit,0)))  as stock_pit
 into #format
 from #total t
 left join #ap ap
 on ap.sku = t.sku
 left join #shopOpen so
 on so.sku = t.sku
 left join #pw pw
 on pw.sku = t.sku
 left join #HS hs
 on hs.sku = t.sku
 left join #products p
 on p.sku = t.sku
 group by t.sku

--select * from #format where sku in ('T707126','75705')

 --calculates inventory for products
 drop table if exists #productinventory
 select
 sku,
 in_quantity_on_hand,
 in_committed_quantity,
 st1ProductReserve,
 in_sfty_stk,
 amazon_pending,
 shop_open_orders,
 stock_pit,
 floor(IIF(in_quantity_on_hand - in_committed_quantity - in_sfty_stk - amazon_pending + stock_pit < 0, 0, in_quantity_on_hand - in_committed_quantity - in_sfty_stk - amazon_pending + stock_pit))  as total_product_inventory
 into #productinventory
 from #format
 group by sku, in_quantity_on_hand, in_committed_quantity, st1ProductReserve, in_sfty_stk, amazon_pending, shop_open_orders, stock_pit
 order by sku

 --calculated kit inventory 
 drop table if exists #kits
 select
 k.sku,
 min(floor(IIF((f.in_quantity_on_hand - f.in_committed_quantity - f.in_sfty_stk - f.amazon_pending + f.stock_pit)/ k.component_quantity < 0, 0, (f.in_quantity_on_hand - f.in_committed_quantity - f.in_sfty_stk - f.amazon_pending + f.stock_pit)/ k.component_quantity)))  as total_kit_inventory
 into #kits
 from titan.live.dbo.kitting k
 left join #format f
 on k.component_sku = f.sku
 group by k.sku

--select * from #total where sku in ( '1806692','1806695','1806701') 

--unions product & kit skus
drop table if exists #totalsku
select
sku
into #totalsku
from #productinventory

union

select sku
from #kits


 --joins together prod & kit inventory
 drop table if exists #join
 select 
t.sku,
p.total_product_inventory,
k.total_kit_inventory
into #join
from #totalsku t
left join #productinventory p
on p.sku = t.sku
left join #kits k
on k.sku = t.sku

--coalesces kit inventory then product inventory
select distinct
coalesce(total_kit_inventory,total_product_inventory) as total_inventory,
j.sku
from #join j
join Integration.INV.ShopifyVariants sv
on j.sku = sv.sku
join INV.ShopifyLocationMap sm
on sm.parentid = sv.id
where sm.id = 'gid://shopify/Location/79232401544' --and j.sku = '1931549'
order by sku
