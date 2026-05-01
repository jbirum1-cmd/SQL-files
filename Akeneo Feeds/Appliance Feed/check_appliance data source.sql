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
where obsoletedate is not null

--compares appliance skus to akeneo
select
h.sku,
a.core_product_data_source,
a.web_website_hartville,
a.shopify_status
from #homesource h
join pim.AllProductsTable a
on a.identifier = h.sku
where a.core_product_data_source <> 'homesource'