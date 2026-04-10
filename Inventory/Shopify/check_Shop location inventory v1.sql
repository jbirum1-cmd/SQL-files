--gets amazon pending
drop table if exists #ap
	select isnull(sx.sku, a.sku) as sku, sum(quantityOrdered) as quantityOrdered into #ap from titan.Integration.dbo.amazonpending a
		LEFT JOIN titan.Integration.dbo.skuxref sx ON a.sku = sx.amazonsku
		group by isnull(sx.sku, a.sku) 
	
	--select * from #ap where sku = 'TR5006WN'

--gets open orders
drop table if exists #shopOpen
	select sku
		, SUM(CASE WHEN o.warehouse_code = 'HHH' then quantity_ordered - canceled_quantity end) AS st1quantityOrdered
		, SUM(CASE WHEN o.warehouse_code = 'HTOOL' then quantity_ordered - canceled_quantity end) AS st2quantityOrdered
		, SUM(CASE WHEN o.warehouse_code = 'LHAK' then quantity_ordered - canceled_quantity end) AS st7quantityOrdered
	    , SUM(CASE WHEN o.warehouse_code = 'LHAD' then quantity_ordered - canceled_quantity end) AS st8quantityOrdered
		into #shopOpen
		from titan.live.dbo.orders o with(nolock)
		inner join titan.live.dbo.udf_order u with(nolock) on u.order_number = o.order_number and udf_code in ('HHCV3','CV3')
		left join titan.live.dbo.line_item li with(nolock) on li.order_number = o.order_number
		where o.status_code not in ('C','X')
		group by sku

--select * from #shopOpen where sku = 'TR5006WN'		
		
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
	

--gets shopify product skus and inv data from eagle hh
drop table if exists #products1
	SELECT trim(in_item_number) as sku
	   , MAX(CASE WHEN in_store = '1' THEN ISNULL(in_quantity_on_hand,0) - ISNULL(in_committed_quantity,0) - ISNULL(in_sfty_stk,0) - 2 END) AS st1CalcQty
	   , MAX(CASE WHEN in_store = '2' THEN ISNULL(in_quantity_on_hand,0) - ISNULL(in_committed_quantity,0) END) AS st2CalcQty
	   , MAX(CASE WHEN in_store = '8' THEN ISNULL(in_quantity_on_hand,0) - ISNULL(in_committed_quantity,0) END) AS st8CalcQty
	into #products1
	from SQLEAGLE.hh.view_in_clone
	where in_store in ('1','2','8')
	and trim(in_item_number) not like 'zz%'
	group by trim(in_item_number) 

 --calculates inventory total quantities for products
 drop table if exists #products2
 select
 t.sku,
 iif(isnull(t.st1CalcQty,0) - isnull(pw.st1ProductReserve,0) + isnull(so.st1quantityOrdered,0) < 0, 0, isnull(t.st1CalcQty,0) - isnull(pw.st1ProductReserve,0) + isnull(so.st1quantityOrdered,0)) as st1totalinv,
iif(isnull(t.st2CalcQty,0) - isnull(pw.st2ProductReserve,0) + isnull(so.st2quantityOrdered,0) < 0, 0, isnull(t.st2CalcQty,0) - isnull(pw.st2ProductReserve,0) + isnull(so.st2quantityOrdered,0)) as st2totalinv,
iif(isnull(t.st8CalcQty,0) - isnull(pw.st8ProductReserve,0) + isnull(so.st8quantityOrdered,0) < 0, 0, isnull(t.st8CalcQty,0) - isnull(pw.st8ProductReserve,0) + isnull(so.st8quantityOrdered,0)) as st8totalinv
 into #products2
 from #products1 t
 left join #shopOpen so
 on so.sku = t.sku
 left join #pw pw
 on pw.sku = t.sku

 
	--select * from #products2 where sku = '03H1268'

  drop table if exists #products3
  select 
  t.sku,
  iif(floor(st1totalinv + st2totalinv + st8totalinv - isnull(ap.quantityordered,0)) < 0,0, floor(st1totalinv + st2totalinv + st8totalinv - isnull(ap.quantityordered,0))) as shop_inventory
  into #products3
  from #products2 t
  left join #ap ap
  on ap.sku = t.sku


 --calculated kit inventory 
 drop table if exists #kits
 select
 k.sku,
 min(floor(f.shop_inventory/ k.component_quantity))  as total_kit_inventory
 into #kits
 from titan.live.dbo.kitting k
 left join #products3 f
 on k.component_sku = f.sku
 group by k.sku

 --unions product & kit skus
drop table if exists #totalsku
select
sku
into #totalsku
from #products3

union

select sku
from #kits

 --joins together prod & kit inventory
 drop table if exists #join
 select 
t.sku,
p.shop_inventory,
k.total_kit_inventory
into #join
from #totalsku t
left join #products3 p
on p.sku = t.sku
left join #kits k
on k.sku = t.sku

--coalesces kit inventory then product inventory
select distinct
coalesce(total_kit_inventory,shop_inventory) as total_inventory,
j.sku
from Integration.INV.ShopifyVariants sv
left join #join j
on j.sku = sv.sku
join INV.ShopifyLocationMap sm
on sm.parentid = sv.id
where sm.id = 'gid://shopify/Location/79143207048' and j.sku = '87446' 
order by sku
