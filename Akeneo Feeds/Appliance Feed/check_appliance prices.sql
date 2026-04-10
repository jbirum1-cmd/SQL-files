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
drop table if exists #calculate
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
replace(replace(replace(replace(replace(replace(a.retail_price_website_hartville,'[{"',''),'":"',''),'","',''),'"}]',''),'amount',''),'currencyUSD','') as akeneo_retail_price,
case when p.umrp <> '0'
	then 'no sale price'
	else 'sale price'
	end as sale_price_yes_no
into #calculate
from #pricing p
join pim.AllProductsTable a
on a.identifier = p.sku
where a.shopify_status <> 'archive'

--compares
select distinct
sku,
calculated_retail_price,
akeneo_retail_price,
case when
	calculated_retail_price = akeneo_retail_price
	then 'true'
	else 'false'
	end as retail_price_check,
sale_price_yes_no
from #calculate
where 
	case when
		calculated_retail_price = akeneo_retail_price
		then 'true'
		else 'false'
	end = 'false'
