--select * from titan.integration.dbo.centerspecappliances
--select * from [PIM].[Appliance_Feed_Previous]

--get max update date record
drop table if exists #maxupdate
select
sku,
max(isnull(updatedate,insertdate)) as max_update_date
into #maxupdate
from titan.integration.dbo.centerspecappliances
group by sku

--gets all elig products
drop table if exists #homesource
select
c.sku
into #homesource
from titan.integration.dbo.centerspecappliances c
join #maxupdate m
on m.sku = c.sku and m.max_update_date = coalesce(c.updatedate,c.insertdate)
where obsoletedate is null

drop table if exists #akeneo
select
sku
into #akeneo
from integration.pim.allproductstable
where core_product_data_source = 'homesource' and shopify_status <> 'archived'

drop table if exists #allskus
select *
into #allskus
from #homesource

union 

select * 
from #akeneo

--compares to file eligibles
drop table if exists #compare
select
a.sku
into #compare
from #allskus a
left join pim.Appliance_Feed_Full f
on a.sku = f.identifier
where f.identifier is null

--pulls back in obsolete date if one exists from centerspec
select
c.sku,
cs.obsoletedate
from #compare c
left join titan.integration.dbo.centerspecappliances cs
on c.sku = cs.sku


