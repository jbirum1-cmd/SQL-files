drop table if exists #eagle
select
    trim(t.sku) as sku,
    trim(e.in_item_number) as eagle_sku,
    e.in_discontinued,
    STRING_AGG(e.in_store, ',') as in_store,
    e.inx_store_closeout_flag
into #eagle
from [Temp].[eagleskucompare] t
left join sqleagle.hh.view_in_clone e
    on trim(t.sku) = trim(e.in_item_number)
where e.in_store in ('1','2','7','8')
group by
    trim(t.sku),
    trim(e.in_item_number),
    e.in_discontinued,
    e.inx_store_closeout_flag;

drop table if exists #kit
select
t.sku,
k.sku as kit_sku,
s.active_flag
into #kit
from [Temp].[eagleskucompare] t
left join titan.testing.dbo.kitting k
on t.sku = k.sku
left join titan.testing.dbo.sku s
on s.sku = k.sku

select distinct
t.Sku,
t.[Enabled],
t.Family,
t.[Product Images],
t.[Product Title (Website - Hartville Hardware)],
t.Created,
t.Updated,
case when e.eagle_sku is null 
	then 'N'
	else 'Y'
	end as Exists_in_eagle,
e.in_discontinued as eagle_in_discontinued,
e.inx_store_closeout_flag as eagle_store_closeout_flag,
e.in_store,
case when k.kit_sku is null 
	then 'N'
	else 'Y'
	end as Exists_in_NO,
k.active_flag as kit_active_flag
from [Temp].[eagleskucompare] t
left join #eagle e
on e.sku = t.sku
left join #kit k
on k.sku = t.sku

	