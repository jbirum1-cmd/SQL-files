--gets shopify pending
drop table if exists #shop
select 
sku as sku, 
sum(quantity) as shop_pending
into #shop 
from INV.ShopifyPending
group by sku

--gets amazon pending
drop table if exists #ap
select isnull(sx.sku, a.sku) as sku, 
sum(quantityOrdered) as amazon_quantityOrdered 
into #ap 
from titan.Integration.dbo.amazonpending a
LEFT JOIN titan.Integration.dbo.skuxref sx ON a.sku = sx.amazonsku
group by isnull(sx.sku, a.sku) 

--gets eagle inv quantities st1
drop table if exists #st1
SELECT
trim(e.in_item_number) as sku,
isnull(e.in_quantity_on_hand,0) - isnull(e.in_committed_quantity,0) - isnull(e.in_sfty_stk,0) - isnull(d.product_reserve_quantity,0) as st1_inventory
into #st1
FROM cv3.cv3hkitems c
left join [sqleagle].[HK].[view_in_clone] e
on trim(e.in_item_number) = c.sku and in_store = '1'
left join datawarehouse.livedb.product_warehouse d
on d.sku = c.sku and d.warehouse_code = 'HHH'

--gets eagle inv quantities st2
drop table if exists #st2
SELECT
trim(e.in_item_number) as sku,
isnull(e.in_quantity_on_hand,0) - isnull(e.in_committed_quantity,0) - isnull(d.product_reserve_quantity,0) as st2_inventory
into #st2
FROM cv3.cv3hkitems c
left join [sqleagle].[HK].[view_in_clone] e
on trim(e.in_item_number) = c.sku and in_store = '2'
left join datawarehouse.livedb.product_warehouse d
on d.sku = c.sku and d.warehouse_code = 'HTOOL'

--calculates final inventory
drop table if exists #inventory
select
c.sku,
isnull(st1.st1_inventory,0) + isnull(st2.st2_inventory,0) - isnull(ap.amazon_quantityOrdered,0) + isnull(sh.shop_pending,0) as total_inventory
into #inventory
from cv3.cv3hkitems c
left join #st1 st1
on st1.sku = c.sku
left join #st2 st2
on st2.sku = c.sku
left join #ap ap
on ap.sku = c.sku
left join #shop sh
on sh.sku = c.sku

--joins back to shopify skus and pulls in shopify location
select distinct
i.sku,
case when 
	i.total_inventory < 0
	then 0
	else i.total_inventory
	end as total_inventory
from #inventory i
join Integration.INV.ShopifyVariants sv
on i.sku = sv.sku



