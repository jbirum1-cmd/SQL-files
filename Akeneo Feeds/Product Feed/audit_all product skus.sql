--get max update date record
drop table if exists #maxupdate
select
sku,
max(isnull(updatedate,insertdate)) as max_update_date
into #maxupdate
from titan.integration.dbo.centerspecappliances
group by sku

--create appliance exclusion list
drop table if exists #exclusions
select
c.sku,
c.obsoletedate
into #exclusions
from titan.integration.dbo.centerspecappliances c
join #maxupdate m
on m.sku = c.sku and m.max_update_date = coalesce(c.updatedate,c.insertdate)
where c.obsoletedate is not null 

drop table if exists #eagleprods
select
replace(replace(trim(v.in_item_number), '-FBA', ''),'(A)','') as sku,
'Eagle' as source
into #eagleprods
from sqleagle.hh.view_in_clone v
where in_privatefromecommercefg in ('C','O','N') and in_store IN ('1','2','4','7','8','D','J')
and NOT EXISTS (
    SELECT 1
    FROM #exclusions e
    WHERE e.sku = replace(replace(trim(v.in_item_number), '-FBA', ''),'(A)','')
);

drop table if exists #kits
select
replace(replace(trim(k.sku),'-FBA',''),'(A)','') as sku,
'NO' as source
into #kits
from titan.live.dbo.kitting k
join titan.live.dbo.sku s
on s.sku = k.sku
where s.active_flag = 'Y'

drop table if exists #akeneoprods
select
trim(sku) as sku,
'Akeneo' as source
into #akeneoprods
from integration.pim.allproductstable 
where core_product_data_source in ('eagle','NatOrd-Kit') and ISNULL(rental_item, 'false') <> 'true'

drop table if exists #allskus
select *
into #allskus
from #eagleprods

union all

select * 
from #kits

union all 

select * 
from #akeneoprods

select distinct 
trim(a.sku) as sku,
a.source,
trim(p.identifier) as identifier
from #allskus a
left join pim.Product_Feed_Full p
on trim(a.sku) = trim(p.identifier)
where p.identifier is null
