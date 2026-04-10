--gets all active kits
drop table if exists #kits
select
replace(replace(replace(replace(trim(k.sku),'-FBA',''),'(A)',''),'.old',''),'(b)','') as sku,
component_sku,
component_quantity
into #kits
from titan.live.dbo.kitting k
join titan.live.dbo.sku s
on s.sku = k.sku
where s.active_flag = 'Y'

--gets all component quantities from eagle
drop table if exists #quantity

select
    k.sku as kit_sku,
    k.component_sku,
    k.component_quantity,
    isnull(v.in_quantity_on_hand,0) as in_quantity_on_hand,
    isnull(v.in_committed_quantity,0) as in_committed_quantity,
    isnull(v.in_future_order_quantity,0) as in_future_order_quantity,
    isnull(v.in_sfty_stk,0) as in_sfty_stk,

    s.store as in_store

into #quantity
from #kits k

-- generate all 3 stores for every component
cross join (values ('1'), ('2'), ('4')) s(store)

-- attempt to match real inventory
left join sqleagle.hh.view_in_clone v
    on k.component_sku = trim(v.in_item_number)
    and v.in_store = s.store 

--select * from #quantity where kit_sku = 'GX10168M2'

--gets total quantity for each field per the component quantity using floor
drop table if exists #cqf
select
kit_sku,
component_sku,
FLOOR(in_quantity_on_hand/component_quantity) as quantity_on_hand,
FLOOR(in_committed_quantity/component_quantity) as committed_quantity,
FLOOR(in_future_order_quantity/component_quantity) as future_order_quantity,
FLOOR(in_sfty_stk/component_quantity) as safety_stock,
in_store
into #cqf
from #quantity
where component_sku not like '%fba%'

--select * from #cqf where kit_sku = 'GX10168M2'

--takes smallest component quantity per sku
drop table if exists #kittotals
select
kit_sku,
MIN(quantity_on_hand) as quantity_on_hand,
MIN(committed_quantity) as committed_quantity,
MIN(future_order_quantity) as future_order_quantity,
MIN(safety_stock) as safety_stock,
in_store
into #kittotals
from #cqf
group by kit_sku, in_store

--select * from #kittotals

--select * from #kittotals where kit_sku = '0820710W30K1'

--creates Akeneo tables for future comparison
drop table if exists #hartville
select
identifier as sku,
isnull(quantity_on_hand_hartville,0) as akeneo_QOH,
isnull(quantity_committed_hartville,0) as akeneo_committed_quantity,
isnull(quantity_on_future_order_hartville,0) as akeneo_quantity_on_future_order,
isnull(safety_stock_hartville,0) as akeneo_safety_stock,
'1' as in_store
into #hartville
from pim.AllProductsTable

drop table if exists #middlefield
select
identifier as sku,
isnull(quantity_on_hand_middlefield,0) as akeneo_QOH,
isnull(quantity_committed_middlefield,0) as akeneo_committed_quantity,
isnull(quantity_on_future_order_middlefield,0) as akeneo_quantity_on_future_order,
isnull(safety_stock_middlefield,0) as akeneo_safety_stock,
'4' as in_store
into #middlefield
from pim.AllProductsTable

drop table if exists #fulfillment
select
identifier as sku,
isnull(quantity_on_hand_fulfillment_center,0) as akeneo_QOH,
isnull(quantity_committed_fulfillment_center,0) as akeneo_committed_quantity,
isnull(quantity_on_future_order_fulfillment_center,0) as akeneo_quantity_on_future_order,
isnull(safety_stock_fulfillment_center,0) as akeneo_safety_stock,
'2' as in_store
into #fulfillment
from pim.AllProductsTable

--unions Akeneo tables
drop table if exists #union
select
sku,
akeneo_QOH,
akeneo_committed_quantity,
akeneo_quantity_on_future_order,
akeneo_safety_stock,
in_store
into #union
from #hartville

union all

select
sku,
akeneo_QOH,
akeneo_committed_quantity,
akeneo_quantity_on_future_order,
akeneo_safety_stock,
in_store
from #middlefield

union all

select
sku,
akeneo_QOH,
akeneo_committed_quantity,
akeneo_quantity_on_future_order,
akeneo_safety_stock,
in_store
from #fulfillment

--select * from #union
--order by sku

--compares to Akeneo
select
k.kit_sku,
k.quantity_on_hand as calculated_QOH,
isnull(u.akeneo_QOH,0) as akeneo_QOH,
case when 
	k.quantity_on_hand = u.akeneo_QOH
	then 'true'
	else 'false'
	end as QOH_compare,	
k.committed_quantity as calculated_committed_quantity,
isnull(u.akeneo_committed_quantity,0) as akeneo_committed_quantity,
case when
	k.committed_quantity = u.akeneo_committed_quantity
	then 'true'
	else 'false'
	end as committed_quantity_compare,	
k.future_order_quantity as calculated_quantity_on_future_order,
isnull(u.akeneo_quantity_on_future_order,0) as akeneo_quantity_on_future_order,
case when
	k.future_order_quantity = u.akeneo_quantity_on_future_order
	then 'true'
	else 'false'
	end as quantity_on_future_order_compare,	
k.safety_stock as calculated_safety_stock,
isnull(u.akeneo_safety_stock,0) as akeneo_safety_stock,
case when
	k.safety_stock = u.akeneo_safety_stock
	then 'true'
	else 'false'
	end as safety_stock_compare,	
k.in_store
from #kittotals k
left join #union u
on k.kit_sku = u.sku and k.in_store = u.in_store
where
(case when 
	k.quantity_on_hand = u.akeneo_QOH
	then 'true'
	else 'false'
	end = 'false')
	or
(case when
	k.committed_quantity = u.akeneo_committed_quantity
	then 'true'
	else 'false'
	end = 'false')
	or
(case when
	k.future_order_quantity = u.akeneo_quantity_on_future_order
	then 'true'
	else 'false'
	end = 'false')
	or
(case when
	k.safety_stock = u.akeneo_safety_stock
	then 'true'
	else 'false'
	end = 'false')
order by kit_sku
