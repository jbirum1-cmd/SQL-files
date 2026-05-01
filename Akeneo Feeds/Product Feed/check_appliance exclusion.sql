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

--check exclusions against product feed full table
select
p.identifier
from pim.Product_Feed_Full p
join #exclusions e
on p.identifier = e.sku

