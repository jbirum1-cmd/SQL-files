--multi record skus
drop table if exists #multi1
select
c.sku,
case when c.obsoletedate is null then '0' else '1' 
	end as record_indicator
into #multi1
from titan.integration.dbo.centerspecappliances c

drop table if exists #multi2
select sku
into #multi2
from #multi1
group by sku
having count(distinct record_indicator) = 2;

drop table if exists #maxupdate
select
sku,
max(isnull(updatedate,insertdate)) as max_update_date
into #maxupdate
from titan.integration.dbo.centerspecappliances
group by sku

drop table if exists #include
select
c.sku,
c.obsoletedate,
c.updatedate,
c.insertdate
into #include
from titan.integration.dbo.centerspecappliances c
join #maxupdate m
on m.sku = c.sku and m.max_update_date = coalesce(c.updatedate,c.insertdate)
join #multi2 m2
on m2.sku = c.sku
where c.obsoletedate is null 

--check that all skus on #include are on the product feed full table
drop table if exists #disc
select
i.sku,
p.identifier
into #disc
from #include i
left join pim.Product_Feed_Full p
on i.sku = p.identifier
where p.identifier is null

--select
--d.sku,
--p.shopify_status,
--p.core_product_data_source
--from #disc d
--left join pim.AllProductsTable p
--on d.sku = p.identifier

--select
--d.sku
--from #disc d
--join pim.Appliance_Feed_Full a
--on a.identifier = d.sku


--select * from pim.Product_Feed_Full where identifier = 'HF861'

select * from #disc