SELECT ShopifyOrderName, RiskRecommendation 
FROM integration.ordimp.shopifyorders
WHERE shopifyordername IN ('HWEBS1419','HWEBS1420')
-- Expected: RiskRecommendation  = 'cancel' or 'investigate'

select
o.udf_code,
o.order_number,
o.udf_order_text,
i.line_number,
i.sku,
i.quantity_ordered,
i.discount_amount,
i.hold_until_date,
i.status_code,
s.order_status_desc
from titan.testing.dbo.udf_order o
join titan.testing.dbo.line_item i
on o.order_number = i.order_number
join titan.testing.[dbo].[order_status]s
on s.status_code = i.status_code
where o.order_number in ('HWEBS1419','HWEBS1420')

