select
o.order_number,
o.priority_rank,
o.status_code,
i.line_number,
i.sku,
i.quantity_ordered,
i.sku_list_price,
i.discount_amount,
o.total_charges
from titan.testing.dbo.orders o
join titan.testing.dbo.line_item i
on o.order_number = i.order_number
where o.order_number like '%hwebs147%' or o.order_number like '%lwebs10%'
