--gets all eligible Akeneo products
drop table if exists #eagleprods
select
replace(replace(trim(v.in_item_number), '-FBA', ''),'(A)','') as sku
into #eagleprods
from sqleagle.hh.view_in_clone v
where in_privatefromecommercefg in ('C','O','N') and v.in_store IN ('1','2','4','7','8','D','J')
and not exists (
	select 1
	from titan.live.dbo.kitting k
	where k.sku = trim(v.in_item_number))

drop table if exists #akeneoprods
select
trim(sku) as sku
into #akeneoprods
from integration.pim.allproductstable 
where core_product_data_source = 'eagle'

drop table if exists #allskus
select *
into #allskus
from #eagleprods

union 

select * 
from #akeneoprods

--gets pricing from eagle for products above
drop table if exists #eaglepricing
select distinct
a.sku,
max(case when 
	in_store = '1'
	then in_retail_price 
	end) as st1_retail,
max(case when 
	v.in_store = '1'
	then in_promotion_price
	end) as st1_promo,
max(case when 
	v.in_store = '2'
	then in_retail_price
	end) as st2_retail,
max(case when 
	v.in_store = '2'
	then in_promotion_price 
	end) as st2_promo,
max(case when 
	in_store = '4'
	then in_retail_price 
	end) as st4_retail,
max(case when 
	in_store = '4'
	then in_promotion_price 
	end) as st4_promo,
max(case when 
	in_store = '7'
	then in_retail_price 
	end) as st7_retail,
max(case when 
	in_store = '7'
	then in_promotion_price 
	end) as st7_promo,
max(case when 
	in_store = '8'
	then in_retail_price 
	end) as st8_retail,
max(case when 
	in_store = '8'
	then in_promotion_price 
	end) as st8_promo
into #eaglepricing
from #allskus a
left join sqleagle.hh.view_in_clone v
on a.sku = replace(replace(trim(v.in_item_number), '-FBA', ''),'(A)','')
where in_store in ('1','2','4','7','8')
group by a.sku

--select * from #eaglepricing
--where sku = '1852499'

--calculates prices to send to akeneo
drop table if exists #calculatedprices
select
sku,
coalesce(nullif(st1_retail,0),nullif(st2_retail,0),nullif(st4_retail,0)) as HH_retail,
coalesce(nullif(st1_promo,0),nullif(st2_promo,0),nullif(st4_promo,0)) as HH_promo,
coalesce(nullif(st8_retail,0),nullif(st7_retail,0)) as LEH_retail,
coalesce(nullif(st8_promo,0),nullif(st7_promo,0)) as LEH_promo
into #calculatedprices
from #eaglepricing

--select * from #calculatedprices
--where sku = '1874672'

--preps data from allproducts table
drop table if exists #cleandata
select
p.identifier,
isnull(replace(replace(Retail_Price_amazon_hartville,'[{"amount":"',''),'","currency":"USD"}]',''),0) as Retail_Price_amazon_hartville,
isnull(replace(replace(Retail_Price_amazon_lehmans,'[{"amount":"',''),'","currency":"USD"}]',''),0) as Retail_Price_amazon_lehmans,
isnull(replace(replace(Retail_Price_website_hartville,'[{"amount":"',''),'","currency":"USD"}]',''),0) as Retail_Price_website_hartville,
isnull(replace(replace(Retail_Price_website_lehmans,'[{"amount":"',''),'","currency":"USD"}]',''),0) as Retail_Price_website_lehmans,
isnull(replace(replace(promo_price_website_hartville,'[{"amount":"',''),'","currency":"USD"}]',''),0) as promo_price_website_hartville,
isnull(replace(replace(promo_price_website_lehmans,'[{"amount":"',''),'","currency":"USD"}]',''),0) as promo_price_website_lehmans
into #cleandata
from pim.AllProductsTable p
where not exists (
    select 1
    from pim.Appliance_Feed_Previous a
    where a.identifier = p.identifier
);

--compares pricing between caculated and akeneo
select
c.sku,
cast(floor(isnull(c.HH_retail,0)*100)/100.0 as decimal(18,2)) as HH_retail,
isnull(cd.Retail_Price_website_hartville,0) as Retail_Price_website_hartville,
isnull(cd.Retail_Price_amazon_hartville,0) as Retail_Price_amazon_hartville,
case when isnull(c.HH_retail,0) = isnull(cd.Retail_Price_website_hartville,0)
	then 'true' else 'false'
	end as HH_web_retail_check,
case when isnull(c.HH_retail,0) = isnull(cd.Retail_Price_amazon_hartville,0)
	then 'true' else 'false'
	end as HH_amazon_retail_check,
cast(floor(isnull(c.HH_promo,0)*100)/100.0 as decimal(18,2)) as HH_promo,
isnull(cd.promo_price_website_hartville,0) as promo_price_website_hartville,
case when
	isnull(c.hh_promo,0) = isnull(cd.promo_price_website_hartville,0)
	then 'true' else 'false'
	end as HH_web_promo_check,
cast(floor(isnull(c.LEH_retail,0)*100)/100.0 as decimal(18,2)) as LEH_retail,
isnull(cd.Retail_Price_website_lehmans,0) as Retail_Price_website_lehmans,
isnull(cd.Retail_Price_amazon_lehmans,0) as Retail_Price_amazon_lehmans,
case when isnull(c.LEH_retail,0) = isnull(cd.Retail_Price_website_lehmans,0)
	then 'true' else 'false'
	end as LEH_web_retail_check,
case when isnull(c.LEH_retail,0) = isnull(cd.Retail_Price_amazon_lehmans,0)
	then 'true' else 'false'
	end as LEH_amazon_retail_check,
cast(floor(isnull(c.LEH_promo,0)*100)/100.0 as decimal(18,2)) as LEH_promo,
isnull(cd.promo_price_website_lehmans,0) as promo_price_website_lehmans,
case when isnull(c.LEH_promo,0) = isnull(cd.promo_price_website_lehmans,0)
	then 'true' else 'false'
	end as LEH_amazon_promo_check
from #calculatedprices c
join #cleandata cd
on c.sku = cd.identifier
where
(case when isnull(c.HH_retail,0) = isnull(cd.Retail_Price_website_hartville,0)
	then 'true' else 'false'
	end = 'false')
or
(case when isnull(c.HH_retail,0) = isnull(cd.Retail_Price_amazon_hartville,0)
	then 'true' else 'false'
	end = 'false')
or
(case when
	isnull(c.hh_promo,0) = isnull(cd.promo_price_website_hartville,0)
	then 'true' else 'false'
	end = 'false')
or
(case when isnull(c.LEH_retail,0) = isnull(cd.Retail_Price_website_lehmans,0)
	then 'true' else 'false'
	end = 'false')
or
(case when isnull(c.LEH_retail,0) = isnull(cd.Retail_Price_amazon_lehmans,0)
	then 'true' else 'false'
	end = 'false')
or
(case when isnull(c.LEH_promo,0) = isnull(cd.promo_price_website_lehmans,0)
	then 'true' else 'false'
	end = 'false')
order by sku;

/*
Discrepancy investigation:
select 
trim(in_item_number),
in_retail_price,
in_promotion_price,
in_store,
in_discontinued,
in_privatefromecommercefg
from sqleagle.hh.view_in_clone
where trim(in_item_number) = '100015007'
*/