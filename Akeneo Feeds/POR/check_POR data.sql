SELECT
a.identifier,
a.rental_item,
SUBSTRING(a.rental_price_4_hours,13,CHARINDEX('.', a.rental_price_4_hours) + 3 - 13) as Akeneo_rental_4_hours,
cast(p.rate1 as decimal(18,2)) as rate1,
SUBSTRING(a.rental_price_one_day,13,CHARINDEX('.', a.rental_price_one_day) + 3 - 13) as Akeneo_rental_1_day,
cast(p.rate2 as decimal(18,2)) as rate2,
SUBSTRING(a.rental_price_one_week,13,CHARINDEX('.', a.rental_price_one_week) + 3 - 13) as Akeneo_rental_1_week,
cast(p.rate3 as decimal(18,2)) as rate3,
a.in_stores,
a.web_website_hartville,
case when
	cast(p.rate1 as varchar(10)) = p.rate1
	then 'true'
	else 'false'
	end as rate1_check,
case when
	cast(p.rate2 as decimal(18,2)) = p.rate2
	then 'true'
	else 'false'
	end as rate2_check,
case when
	cast(p.rate3 as decimal(18,2)) = p.rate3
	then 'true'
	else 'false'
	end as rate3_check
from pim.AllProductsTable a
join temp.portesting p
on a.identifier = p.[key]
where a.rental_item = 'true'

