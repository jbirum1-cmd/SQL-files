--gets kit skus
drop table if exists #kitskus
select
trim(sku) as sku
into #kitskus
from integration.pim.allproductstable 
where core_product_data_source = 'NatOrd-Kit' and ISNULL(rental_item, 'false') <> 'true'

--gets prices from catalog table per catalog id
drop table if exists #master13
select 
k.sku,
c.catalog_price as MASTER13
into #master13
from #kitskus k
left join titan.live.dbo.catalog_price c
on k.sku = c.sku and catalog_id = 'MASTER13'

drop table if exists #lehmaster
select 
k.sku,
c.catalog_price as LEHMASTER
into #lehmaster
from #kitskus k
left join titan.live.dbo.catalog_price c
on k.sku = c.sku and catalog_id = 'LEHMASTER'

drop table if exists #hhmaster
select 
k.sku,
c.catalog_price as HHMASTER
into #hhmaster
from #kitskus k
left join titan.live.dbo.catalog_price c
on k.sku = c.sku and catalog_id = 'HHMASTER'

--joins together
drop table if exists #prices
select
k.sku,
isnull(m.MASTER13,0) as MASTER13,
isnull(l.LEHMASTER,0) as LEHMASTER,
isnull(h.HHMASTER,0) as HHMASTER
into #prices
from #kitskus k
join #master13 m
on k.sku = m.sku
join #lehmaster l
on k.sku = l.sku
join #hhmaster h
on k.sku = h.sku

--cleans akeneo values
drop table if exists #cleandata
select
identifier,
isnull(replace(replace(Retail_Price_amazon_hartville,'[{"amount":"',''),'","currency":"USD"}]',''),0) as Retail_Price_amazon_hartville,
isnull(replace(replace(Retail_Price_amazon_lehmans,'[{"amount":"',''),'","currency":"USD"}]',''),0) as Retail_Price_amazon_lehmans,
isnull(replace(replace(Retail_Price_website_hartville,'[{"amount":"',''),'","currency":"USD"}]',''),0) as Retail_Price_website_hartville,
isnull(replace(replace(Retail_Price_website_lehmans,'[{"amount":"',''),'","currency":"USD"}]',''),0) as Retail_Price_website_lehmans
into #cleandata
from pim.AllProductsTable

--compares to akeneo
select
a.identifier,
p.master13,
p.hhmaster,
p.lehmaster,
a.retail_price_amazon_hartville,
a.retail_price_amazon_lehmans,
a.retail_price_website_hartville,
a.retail_price_website_lehmans,
case when 
	a.retail_price_amazon_hartville = p.master13
	then 'true'
	else 'false'
	end as hh_amazon_price_compare,
case when a.retail_price_amazon_lehmans = p.lehmaster
	then 'true'
	else 'false'
	end as lehmans_amazon_price_compare,
case when coalesce(p.MASTER13,p.HHMASTER)= a.Retail_Price_website_hartville
	then 'true'
	else 'false'
	end as hh_price_compare,
case when a.retail_price_website_lehmans = p.lehmaster
	then 'true'
	else 'false'
	end as leh_price_compare
from #prices p
join #cleandata a
on a.identifier = p.sku
where
(case when 
	a.retail_price_amazon_hartville = p.master13
	then 'true'
	else 'false'
	end = 'false')
or (
case when a.retail_price_amazon_lehmans = p.lehmaster
	then 'true'
	else 'false'
	end = 'false')
or (
case when coalesce(p.MASTER13,p.HHMASTER)= a.Retail_Price_website_hartville
	then 'true'
	else 'false'
	end = 'false')
or (
case when a.retail_price_website_lehmans = p.lehmaster
	then 'true'
	else 'false'
	end = 'false')