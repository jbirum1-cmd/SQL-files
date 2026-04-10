
--gets QOH & location code from eagle for stores 1,2,7,8
drop table if exists #fbm
select
trim(in_item_number) as sku,
concat(in_department,'-',in_location_codes) as eagle_location,
case when 
	in_store = '1'
	then 'HHH'
	when in_store = '2'
	then 'HTOOL'
	when in_store = '7'
	then 'LHAK'
	when in_store = '8'
	then 'LHAD'
	else null
	end as warehouse_mapped,
isnull(in_quantity_on_hand,0) as QOH,
in_store
into #fbm
from sqleagle.hh.view_in_clone
where in_store in ('1','2','7','8') and in_primary_vendor not in ('5HACO','HARTC','MCELR','ULINE') and trim(in_item_number) not like 'zz%'

--gets store D QOH & location from eagle and adds the fba to the sku for NO
drop table if exists #fba
select
concat(trim(in_item_number),'-fba') as sku,
concat(in_department,'-',in_location_codes) as eagle_location,
'HTOOL' as warehouse_mapped,
isnull(in_quantity_on_hand,0) as QOH,
in_store
into #fba
from sqleagle.hh.view_in_clone
where in_store = 'D' and in_primary_vendor not in ('5HACO','HARTC')

--select * from #fba
--order by sku

--unions fbm & fba
drop table if exists #union
select *
into #union
from #fbm

union all

select * 
from #fba

--joins to NO product_locations by location code and warehouse for stores 1 & 2. Drops skus that don't have a match.
drop table if exists #NOHH
select
u.sku,
u.eagle_location,
pl.location_type as NO_location,
u.warehouse_mapped,
pl.warehouse_code,
case when 
	u.QOH < 0
	then 0
	else u.QOH
	end as QOH,
u.in_store
into #NOHH
from #union u
join titan.testing.dbo.product_location pl
on trim(u.sku) = trim(pl.sku) and u.eagle_location = pl.location_type and u.warehouse_mapped = pl.warehouse_code
where u.warehouse_mapped in ('hhh','htool')

--filters #union skus to LEH
drop table if exists #NOLEH
select
u.sku,
u.eagle_location,
pl.location_type as NO_location,
u.warehouse_mapped,
pl.warehouse_code,
case when 
	u.QOH < 0
	then 0
	else u.QOH
	end as QOH,
u.in_store
into #NOLEH
from #union u
join titan.testing.dbo.product_location pl
on trim(u.sku) = trim(pl.sku) 
where u.warehouse_mapped in ('lhak','lhad')

--unions nohh and noleh
drop table if exists #noall
select * 
into #noall
from #nohh

union all

select * 
from #noleh



--select * from #NO --where sku like '%fba%' order by sku
--select * from #NO where sku = '331731'

--select * from titan.testing.dbo.warehouse_locations where location_type in ('10-SO','10-69B08')

--compares Eagle QOH to NO total product quantity for remaining skus
--drop table if exists #compare
select distinct
n.sku,
floor(n.QOH) as Eagle_QOH,
pw.product_total_quantity,
n.in_store as Eagle_in_store,
pw.warehouse_code as NO_warehouse_code,
case when n.QOH = pw.product_total_quantity
	then 'true'
	else 'false'
	end as quantity_compare
from #NOall n
join TITAN.testing.dbo.product_warehouse pw
on pw.sku = n.sku and n.warehouse_mapped = pw.warehouse_code
where 
	case when floor(n.QOH) = pw.product_total_quantity
	then 'true'
	else 'false'
	end = 'false'
order by sku

/*testing
select 
trim(in_item_number) as sku,
in_store,
in_quantity_on_hand,
in_department,
in_location_codes
from sqleagle.hh.view_in_clone
where trim(in_item_number) = '100HHGIFTCARD'

select
sku,
warehouse_code,
product_total_quantity
from TITAN.testing.dbo.product_warehouse
where sku = '100HHGIFTCARD'

select *
from titan.testing.dbo.product_location
where sku = '100HHGIFTCARD'
*/

