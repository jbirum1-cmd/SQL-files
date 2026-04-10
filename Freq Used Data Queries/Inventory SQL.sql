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

--select * from #pw where sku = 'TR5006WN'		
	

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

--select * from #products1 where trim(in_item_number) = '