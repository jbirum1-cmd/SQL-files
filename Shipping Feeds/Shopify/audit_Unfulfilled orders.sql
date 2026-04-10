select 
u.order_number,
u.udf_order_text,
l.line_number,
l.quantity_ordered,
l.first_shipped_datetime,
s.tracking_number,
s.shipment_type_code,
l.sku
from titan.testing.dbo.udf_order u
left join titan.testing.dbo.line_item l
on u.order_number = l.order_number
left join titan.testing.dbo.shipper_tracking_number s
on u.order_number = s.order_number 
where l.first_shipped_shipdoc is null and u.order_number like '%webs%'
and not exists (
	select 1
    from Titan.Integration.dbo.shipmentlog sl
    where sl.Status = 'Completed' and sl.channelorderid = u.udf_order_text and sl.sku = l.Sku)
order by u.order_number desc;
       
--select * from [ORDIMP].[ShopifyOrders]
--order by ShopifyOrderName desc

--select * from titan.testing.dbo.udf_order
--where order_number in ('HWEBS1251','HWEBS1252','LWEBS1009','LWEBS1010','HWEBS1253','LWEBS1011')

--select * from titan.testing.dbo.shipper_tracking_number where order_number = 'LWEBS1251'

--select * from titan.testing.dbo.line_item where order_number = 'LWEBS1007'