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
pl.product_quantity,
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
 JOIN Titan.testing.dbo.sku s 
    ON TRIM(s.sku) = TRIM(pl.sku)
    JOIN Titan.testing.dbo.products p 
        ON p.product_number = s.product_number
    JOIN Titan.testing.dbo.product_types pt 
        ON pt.product_type_code = p.product_type_code
where u.warehouse_mapped in ('hhh','htool') and pt.inventory_flag = 'y' and s.kit_code NOT IN ('K', 'S')

--filters #union skus to LEH
drop table if exists #NOLEH
select
u.sku,
u.eagle_location,
pl.location_type as NO_location,
pl.product_quantity,
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
on trim(u.sku) = trim(pl.sku) and pl.warehouse_code = u.warehouse_mapped
 JOIN Titan.testing.dbo.sku s 
    ON TRIM(s.sku) = TRIM(pl.sku)
    JOIN Titan.testing.dbo.products p 
        ON p.product_number = s.product_number
    JOIN Titan.testing.dbo.product_types pt 
        ON pt.product_type_code = p.product_type_code
where u.warehouse_mapped in ('lhak','lhad') and pt.inventory_flag = 'y' and s.kit_code NOT IN ('K', 'S')

--unions nohh and noleh
drop table if exists #noall
select * 
into #noall
from #nohh

union all

select * 
from #noleh

--compares Eagle QOH to NO total product quantity for remaining skus
select distinct
sku,
floor(n.QOH) as Eagle_QOH,
product_quantity,
in_store as Eagle_in_store,
warehouse_code as NO_warehouse_code,
case when floor(QOH) = product_quantity
	then 'true'
	else 'false'
	end as quantity_compare
from #NOall n
where 
	case when floor(QOH) = product_quantity
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

