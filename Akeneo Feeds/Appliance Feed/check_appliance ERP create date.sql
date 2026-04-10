--get max update date record
--drop table if exists #maxupdate
--select
--sku,
--max(isnull(updatedate,insertdate)) as max_update_date
--into #maxupdate
--from titan.integration.dbo.centerspecappliances
--group by sku

--gets all elig products
drop table if exists #homesource
select
c.sku
into #homesource
from titan.integration.dbo.centerspecappliances c
--join #maxupdate m
--on m.sku = c.sku and m.max_update_date = coalesce(c.updatedate,c.insertdate)
where obsoletedate is null

--select * from #homesource where sku = 'WMML5530RB'

drop table if exists #akeneo
select
sku
into #akeneo
from integration.pim.allproductstable
where core_product_data_source = 'homesource' and shopify_status <> 'archived'

--select * from #akeneo where sku = 'WMML5530RB'

drop table if exists #allskus
select *
into #allskus
from #homesource

union 

select * 
from #akeneo

--select * from #allskus where sku = 'WMML5530RB'

--gets insert date for all elgibiles
drop table if exists #insertdate
select
a.sku,
min(cast(c.insertdate as date)) as insertdate
into #insertdate
from #allskus a
left join titan.integration.dbo.centerspecappliances c
on a.sku = c.sku
group by a.sku

--select * from #insertdate where sku = 'WMML5530RB'

--compares dates to akeneo allproductstable
select
a.identifier,
a.erp_sku_create_date,
d.insertdate as centerspec_insertdate,
case when 
	a.erp_sku_create_date = d.insertdate
	then 'true'
	else 'false'
	end as date_compare
from #insertdate d 
left join integration.pim.allproductstable a
on a.identifier = d.sku
where
	case when 
	a.erp_sku_create_date = d.insertdate
	then 'true'
	else 'false'
	end = 'false'
