--select * from titan.integration.dbo.centerspecappliances

--get max update date record
drop table if exists #maxupdate
select
sku,
max(isnull(updatedate,insertdate)) as max_update_date
into #maxupdate
from titan.integration.dbo.centerspecappliances
group by sku

drop table if exists #pricing
select
c.sku,
isnull(c.umrp,0) as umrp,
isnull(c.msrp,0) as msrp,
isnull(c.cost,0) as cost,
isnull(c.calculatedcost,0) as calculatedcost,
isnull(c.map,0) as map,
c.obsoletedate
into #pricing
from titan.integration.dbo.centerspecappliances c
join #maxupdate m
on m.sku = c.sku and m.max_update_date = coalesce(c.updatedate,c.insertdate)

--calculates retail & sale
drop table if exists #calc1
select
p.sku,
case when
	p.umrp <> '0'
	then p.umrp
	when p.umrp = '0' and p.msrp <> '0'
	then p.msrp
	else
		case when
		p.calculatedcost >= p.map
		then p.calculatedcost
		else p.map
		end
	end as calculated_retail_price,
isnull(f.sale_price_website_hartville,0) as sale_price
into #calc1
from #pricing p
left join pim.appliance_feed_full f
on p.sku = f.identifier

--calculates retail and list price fields
drop table if exists #calc2
select
c1.sku,
c1.sale_price,
c1.calculated_retail_price as calculated_list_price,
case when
	c1.sale_price <> 0
	then c1.sale_price
	else c1.calculated_retail_price
	end as calculated_retail_price
into #calc2
from #calc1 c1

--compares calculated prices to feed data
select distinct
f.identifier as sku,
c2.sale_price,
c2.calculated_retail_price,
f.retail_price_website_hartville as feed_retail_price,
c2.calculated_list_price,
f.list_price_website_hartville,
case when
	c2.calculated_retail_price = f.retail_price_website_hartville
	then 'true'
	else 'false'
	end as retail_price_check,
case when
	c2.calculated_list_price = f.list_price_website_hartville
	then 'true'
	else 'false'
	end as list_price_check
from pim.appliance_feed_full f
left join #calc2 c2
on f.identifier = c2.sku
where f.shopify_status <> 'archived' and (
	case when
	c2.calculated_retail_price = f.retail_price_website_hartville
	then 'true'
	else 'false'
	end = 'false'
or
	case when
	c2.calculated_list_price = f.list_price_website_hartville
	then 'true'
	else 'false'
	end = 'false'
	)

--puts akeneo list price values into a temp table to pull from
drop table if exists #akeneolist
SELECT 
    p.identifier,
    d.amount AS list_price
into #akeneolist
FROM [Integration].[PIM].[AllProducts] p
CROSS APPLY OPENJSON(p.json, '$.values.list_price') lp
CROSS APPLY OPENJSON(lp.value)
    WITH (
        scope NVARCHAR(100) '$.scope',
        amount NVARCHAR(50) '$.data[0].amount'
    ) d
WHERE d.scope = 'website_hartville'

--compares calculated prices to akeneo data
select distinct
a.identifier as sku,
f.Sale_Price_website_hartville as sale_price,
f.Retail_Price_website_hartville as feed_retail_price,
replace(replace(replace(replace(replace(replace(a.retail_price_website_hartville,'[{"',''),'":"',''),'","',''),'"}]',''),'amount',''),'currencyUSD','') as akeneo_retail_price,
f.list_price_website_hartville as feed_list_price,
l.list_price as akeneo_list_price,
case when
	f.Retail_Price_website_hartville = replace(replace(replace(replace(replace(replace(a.retail_price_website_hartville,'[{"',''),'":"',''),'","',''),'"}]',''),'amount',''),'currencyUSD','')
	then 'true'
	else 'false'
	end as retail_price_check,
case when
	f.list_price_website_hartville = l.list_price
	then 'true'
	else 'false'
	end as list_price_check
from pim.appliance_feed_full f 
left join pim.AllProductsTable a
on a.identifier = f.identifier
left join #akeneolist l
on f.identifier = l.identifier
where a.shopify_status <> 'archive' and (
	case when
	f.Retail_Price_website_hartville = replace(replace(replace(replace(replace(replace(a.retail_price_website_hartville,'[{"',''),'":"',''),'","',''),'"}]',''),'amount',''),'currencyUSD','')
	then 'true'
	else 'false'
	end = 'false'
or
	case when
	f.list_price_website_hartville = l.list_price
	then 'true'
	else 'false'
	end = 'false'
	)
