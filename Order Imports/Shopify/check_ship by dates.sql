select 
b.order_number,
a.ship_by_dtm as ship_by_date_gift,
b.expected_ship_date as ship_by_date_order
from titan.testing.dbo.import_order_gift a
join titan.testing.dbo.orders b 
on a.third_party_order_number = b.import_order_number 
where b.order_number like 'hwebs142%'

