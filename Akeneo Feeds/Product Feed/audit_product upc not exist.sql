select
a.identifier,
a.upc_no_exist as akeneo_upc_no_exist,
f.upc_no_exist as feed_no_exist,
a.core_product_data_source,
case when
	a.upc_no_exist = 'true' and f.upc_no_exist = '1'
	then 'true'
	when a.upc_no_exist = 'false' and f.upc_no_exist = '0'
	then 'true'
	else 'false'
	end as upc_no_exist_check
from pim.AllProductsTable a
join pim.Product_Feed_Full f
on a.identifier = f.identifier
where a.core_product_data_source not like '%akeneo%'
and case when
	a.upc_no_exist = 'true' and f.upc_no_exist = '1'
	then 'true'
	when a.upc_no_exist = 'false' and f.upc_no_exist = '0'
	then 'true'
	else 'false'
	end = 'false'