--gets QOH & location code from eagle for stores 1,2,7,8
drop table if exists #fbm
select
trim(in_item_number) as sku,
case when
	in_store in ('1','4')
	then concat(in_department,'-',in_location_codes)
	else in_location_codes
	end as eagle_location,
case when 
	in_store = '1'
	then 'HHH'
	when in_store = '2'
	then 'HTOOL'
	when in_store = '7'
	then 'LHAK'
	when in_store = '8'
	then 'LHAD'
	when in_store = '4'
	then 'HHMF'
	else null
	end as warehouse_mapped,
case when
	isnull(in_quantity_on_hand,0) - isnull(in_committed_quantity,0) < 0
	then 0
	else isnull(in_quantity_on_hand,0) - isnull(in_committed_quantity,0)
	end as QOH,
in_store
into #fbm
from sqleagle.hh.view_in_clone
where in_store in ('1','2','4','7','8') and trim(in_item_number) not like 'zz%' and trim(in_item_number) not like '$due'
order by trim(in_item_number) 

----sql check for only one unique record per sku/in_store combination
--SELECT 
--    sku,
--    in_store,
--    COUNT(*) AS record_count
--FROM #fbm
--GROUP BY sku, in_store
--HAVING COUNT(*) > 1;

--gets store D QOH & location from eagle and adds the fba to the sku for NO
drop table if exists #fba
select
concat(trim(in_item_number),'-fba') as sku,
in_location_codes as eagle_location,
'HTOOL' as warehouse_mapped,
case when
	isnull(in_quantity_on_hand,0) - isnull(in_committed_quantity,0) < 0
	then 0
	else isnull(in_quantity_on_hand,0) - isnull(in_committed_quantity,0)
	end as QOH,
in_store
into #fba
from sqleagle.hh.view_in_clone
where in_store = 'D' and trim(in_item_number) not like 'zz%'


--unions fbm & fba
drop table if exists #union
select *
into #union
from #fbm

union all

select * 
from #fba

--joins to NO product_locations by sku & warehouse
drop table if exists #NO
select
u.sku,
u.eagle_location,
pl.location_type as NO_location,
pl.product_quantity,
u.QOH,
u.warehouse_mapped,
pl.warehouse_code,
u.in_store
into #NO
from #union u
join titan.testing.dbo.product_location pl
on trim(u.sku) = trim(pl.sku) and u.warehouse_mapped = pl.warehouse_code
 JOIN Titan.testing.dbo.sku s 
    ON TRIM(s.sku) = TRIM(pl.sku)
    JOIN Titan.testing.dbo.products p 
        ON p.product_number = s.product_number
    JOIN Titan.testing.dbo.product_types pt 
        ON pt.product_type_code = p.product_type_code
where pt.inventory_flag = 'y' and s.kit_code NOT IN ('K', 'S')


--compares Eagle QOH & location to NO total product quantity & location. Run before program updates.
drop table if exists #before
select distinct
sku,
eagle_location,
NO_location,
floor(QOH) as Eagle_QOH,
product_quantity,
in_store as Eagle_in_store,
warehouse_mapped,
warehouse_code as NO_warehouse_code,
case when eagle_location = NO_location
	then 'true'
	else 'false'
	end as location_compare,
case when floor(QOH) = product_quantity
	then 'true'
	else 'false'
	end as quantity_compare
into #before
from #NO 
where (
	case when floor(QOH) = product_quantity
	then 'true'
	else 'false'
	end = 'false'
	) or (
	case when eagle_location = NO_location
	then 'true'
	else 'false'
	end = 'false'
	)
order by sku

--compares Eagle QOH & location to NO total product quantity & location. Run after program updates.
drop table if exists #after
select distinct
sku,
eagle_location,
NO_location,
floor(QOH) as Eagle_QOH,
product_quantity,
in_store as Eagle_in_store,
warehouse_mapped,
warehouse_code as NO_warehouse_code,
case when eagle_location = NO_location
	then 'true'
	else 'false'
	end as location_compare,
case when floor(QOH) = product_quantity
	then 'true'
	else 'false'
	end as quantity_compare
into #after
from #NO 
where (
	case when floor(QOH) = product_quantity
	then 'true'
	else 'false'
	end = 'false'
	) or (
	case when eagle_location = NO_location
	then 'true'
	else 'false'
	end = 'false'
	)
order by sku

select * from #before
select * from #after

--compares location changes to log. Run after program updates.
select
b.sku,
b.eagle_location,
b.NO_location
l.warehouse,
l.previous_location,
l.new_location,
l.changedat
FROM #before b
LEFT JOIN INV.LocationChangeLog l
    ON b.sku = l.sku
WHERE b.eagle_location <> b.NO_location;

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

