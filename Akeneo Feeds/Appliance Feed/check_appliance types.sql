--get max update date record
drop table if exists #maxupdate
select
sku,
max(isnull(updatedate,insertdate)) as max_update_date
into #maxupdate
from titan.integration.dbo.centerspecappliances
group by sku

--maps appliance type code that should be sent on feed
drop table if exists #mapping
select
a.sku,
a.apid,
c.type as homesource_type,
tm.code as mapped_code
into #mapping
from titan.integration.dbo.centerspecappliances a
join titan.integration.dbo.Centerspecclassifications c
on a.apid = c.apid
join integration.appl.typemap tm 
on tm.type = c.type
join #maxupdate m
on m.sku = a.sku and m.max_update_date = coalesce(a.updatedate,a.insertdate)

--compares mapped codes to current Akeneo state
select
a.identifier,
replace(replace(replace(a.appliance_type, '["',''),'"',''),']','') as appliance_type,
m.mapped_code,
a.core_product_data_source,
case when 
	isnull(replace(replace(replace(a.appliance_type, '["',''),'"',''),']',''),'') = isnull(m.mapped_code,'')
	then 'True'
	else 'False'
	end as Type_Check
from integration.pim.allproductstable a
left join #mapping m
on a.identifier = m.sku
where a.core_product_data_source = 'homesource' and shopify_status <> 'archive'
and case when 
	isnull(replace(replace(replace(a.appliance_type, '["',''),'"',''),']',''),'') = isnull(m.mapped_code,'')
	then 'True'
	else 'False'
	end = 'false';


--investigate discrepancies
--select * from integration.appl.typemap
--select * from titan.integration.dbo.centerspecappliances where sku = 'HF861'
--select * from titan.integration.dbo.Centerspecclassifications where apid = ' '