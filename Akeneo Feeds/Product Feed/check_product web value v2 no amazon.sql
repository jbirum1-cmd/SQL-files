--gets all akeneo products that aren't appliances
drop table if exists #akeneoprods
select
trim(a.sku) as sku
into #akeneoprods
from integration.pim.allproductstable a
where core_product_data_source in ('eagle')
and not exists (
	select 1
	from titan.integration.dbo.centerspecappliances c
	where c.sku = a.sku)

--joins akeneo products to eagle for web data
drop table if exists #web
select
trim(a.sku) as sku,
v.in_store,
case when
	v.in_privatefromecommercefg in ('C','O','N')
	then '1'
	else  '0'
	end as web
into #web
from #akeneoprods a
join sqleagle.hh.view_in_clone v
on replace(replace(trim(v.in_item_number), '-FBA', ''),'(A)','') = trim(a.sku)
where v.in_store IN ('1','2','4','7','8','12','18') 
order by trim(a.sku)

--assigns web value per store grouping
drop table if exists #webgrouping1
select
sku,
STRING_AGG(CAST(web AS varchar(10)), ',') 
        WITHIN GROUP (ORDER BY web) AS web_website_hartville
into #webgrouping1
from #web 
where in_store IN ('1','2','4')
group by sku

drop table if exists #webgrouping2
select
sku,
STRING_AGG(CAST(web AS varchar(10)), ',') 
        WITHIN GROUP (ORDER BY web) AS web_website_lehmans
into #webgrouping2
from #web 
where in_store IN ('7','8')
group by sku

drop table if exists #webgrouping3
select
sku,
STRING_AGG(CAST(web AS varchar(10)), ',') 
        WITHIN GROUP (ORDER BY web) AS web_amazon_hartville
into #webgrouping3
from #web 
where in_store IN ('2','12')
group by sku

drop table if exists #webgrouping4
select
sku,
STRING_AGG(CAST(web AS varchar(10)), ',') 
        WITHIN GROUP (ORDER BY web) AS web_amazon_lehmans
into #webgrouping4
from #web 
where in_store IN ('8','18')
group by sku

--joins all groupings tables
drop table if exists #weball
select
w.sku,
isnull(w1.web_website_hartville, 0) as web_website_hartville,
isnull(w2.web_website_lehmans, 0) as web_website_lehmans,
isnull(w3.web_amazon_hartville, 0) as web_amazon_hartville,
isnull(w4.web_amazon_lehmans, 0) as web_amazon_lehmans
into #weball
from #web w
left join #webgrouping1 w1
on w.sku = w1.sku
left join #webgrouping2 w2
on w.sku = w2.sku
left join #webgrouping3 w3
on w.sku = w3.sku
left join #webgrouping4 w4
on w.sku = w4.sku

--convers web fields to single value per channel
drop table if exists #value
select distinct
sku,
case when
	web_website_hartville like '%1%'
	then 'True'
	else 'False'
	end as web_website_hartville,
case when
	web_website_lehmans like '%1%'
	then 'True'
	else 'False'
	end as web_website_lehmans,
case when
	web_amazon_hartville like '%1%'
	then 'True'
	else 'False'
	end as web_amazon_hartville,
case when
	web_amazon_lehmans like '%1%'
	then 'True'
	else 'False'
	end as web_amazon_lehmans
into #value
from #weball 

--compares to Akeneo
select
a.sku,
v.web_website_hartville as eagle_web_website_hartville,
p.web_website_hartville as pim_web_website_hartville,
case when
	isnull(v.web_website_hartville,0) = isnull(p.web_website_hartville,0)
	then 'true'
	else 'false'
	end as website_hartville_compare,
v.web_website_lehmans as eagle_web_website_lehmans,
p.web_website_lehmans as pim_web_website_lehmans,
case when
	isnull(v.web_website_lehmans,0) = isnull(p.web_website_lehmans,0)
	then 'true'
	else 'false'
	end as website_lehmans_compare,
v.web_amazon_hartville as eagle_web_amazon_hartville,
p.web_amazon_hartville as pim_web_amazon_hartville,
case when
	isnull(v.web_amazon_hartville,0) = isnull(p.web_amazon_hartville,0)
	then 'true'
	else 'false'
	end as amazon_hartville_compare,
v.web_amazon_lehmans as eagle_web_amazon_lehmans,
p.web_amazon_lehmans as pim_web_amazon_lehmans,
case when
	isnull(v.web_amazon_lehmans,0) = isnull(p.web_amazon_lehmans,0)
	then 'true'
	else 'false'
	end as amazon_lehmans_compare
from #akeneoprods a
left join #value v
on a.sku = v.sku
left join pim.AllProductsTable p
on v.sku = p.identifier
where
(case when
	isnull(v.web_website_hartville,0) = isnull(p.web_website_hartville,0)
	then 'true'
	else 'false'
	end = 'false')
	or
(case when
	isnull(v.web_website_lehmans,0) = isnull(p.web_website_lehmans,0)
	then 'true'
	else 'false'
	end = 'false')
--	or
--(case when
--	v.web_amazon_hartville = p.web_amazon_hartville
--	then 'true'
--	else 'false'
--	end = 'false')
--	or
--(case when
--	v.web_amazon_lehmans = p.web_amazon_lehmans
--	then 'true'
--	else 'false'
--	end = 'false');


