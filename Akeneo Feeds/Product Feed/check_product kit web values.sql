--gets all akeneo products
drop table if exists #akeneoprods
select
trim(sku) as sku
into #akeneoprods
from integration.pim.allproductstable 
where core_product_data_source in ('NatOrd-Kit')

--joins akeneo products to NO for active flag data
drop table if exists #kits
select distinct
a.sku,
p.warehouse_code,
case when 
	s.active_flag = 'Y'
	then 'True'
	else 'False'
	end as web
into #kits
from #akeneoprods a
left join titan.live.dbo.kitting k
on a.sku = replace(replace(trim(k.sku),'-FBA',''),'(A)','')
join titan.live.dbo.sku s
on s.sku = replace(replace(trim(k.sku),'-FBA',''),'(A)','')
join titan.live.dbo.product_warehouse p
on replace(replace(trim(k.sku),'-FBA',''),'(A)','') = p.sku

----assigns web value per warehouse grouping
drop table if exists #webgrouping1
select
sku,
STRING_AGG(CAST(web AS varchar(10)), ',') 
        WITHIN GROUP (ORDER BY web) AS web_website_hartville
into #webgrouping1
from #kits 
where warehouse_code IN ('HHH','HTOOL')
group by sku


drop table if exists #webgrouping2
select
sku,
STRING_AGG(CAST(web AS varchar(10)), ',') 
        WITHIN GROUP (ORDER BY web) AS web_website_lehmans
into #webgrouping2
from #kits
where warehouse_code IN ('LHAK','LHAD')
group by sku

drop table if exists #webgrouping3
select
sku,
STRING_AGG(CAST(web AS varchar(10)), ',') 
        WITHIN GROUP (ORDER BY web) AS web_amazon_hartville
into #webgrouping3
from #kits
where warehouse_code IN ('HHH','HTOOL')
group by sku

drop table if exists #webgrouping4
select
sku,
STRING_AGG(CAST(web AS varchar(10)), ',') 
        WITHIN GROUP (ORDER BY web) AS web_amazon_lehmans
into #webgrouping4
from #kits
where warehouse_code IN ('LHAK','LHAD')
group by sku

--joins all groupings tables
drop table if exists #web
select
k.sku,
isnull(w1.web_website_hartville, 0) as web_website_hartville,
isnull(w2.web_website_lehmans, 0) as web_website_lehmans,
isnull(w3.web_amazon_hartville, 0) as web_amazon_hartville,
isnull(w4.web_amazon_lehmans, 0) as web_amazon_lehmans
into #web
from #kits k
left join #webgrouping1 w1
on k.sku = w1.sku
left join #webgrouping2 w2
on k.sku = w2.sku
left join #webgrouping3 w3
on k.sku = w3.sku
left join #webgrouping4 w4
on k.sku = w4.sku

--convers web fields to single value per channel
drop table if exists #value
select distinct
sku,
case when
	web_website_hartville like '%true%'
	then 'True'
	else 'False'
	end as web_website_hartville,
case when
	web_website_lehmans like '%true%'
	then 'True'
	else 'False'
	end as web_website_lehmans,
case when
	web_amazon_hartville like '%true%'
	then 'True'
	else 'False'
	end as web_amazon_hartville,
case when
	web_amazon_lehmans like '%true%'
	then 'True'
	else 'False'
	end as web_amazon_lehmans
into #value
from #web

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
	or
(case when
	v.web_amazon_hartville = p.web_amazon_hartville
	then 'true'
	else 'false'
	end = 'false')
	or
(case when
	v.web_amazon_lehmans = p.web_amazon_lehmans
	then 'true'
	else 'false'
	end = 'false');

	