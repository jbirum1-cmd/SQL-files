--get max update date record
drop table if exists #maxupdate
select
sku,
max(isnull(updatedate,insertdate)) as max_update_date
into #maxupdate
from titan.integration.dbo.centerspecappliances
group by sku

--compare
select
a.sku,
a.shopify_status,
c.obsoletedate
from integration.pim.allproductstable a
join titan.integration.dbo.centerspecappliances c
on a.sku = c.sku
join #maxupdate m
on m.sku = a.sku and m.max_update_date = coalesce(c.updatedate,c.insertdate)
where obsoletedate is not null and shopify_status <> 'archived'

