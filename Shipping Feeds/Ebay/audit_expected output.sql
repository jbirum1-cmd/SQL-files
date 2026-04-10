select 
u.order_number,
u.udf_order_text,
l.line_number,
l.quantity_ordered,
l.first_shipped_datetime, 
case 
	when s.shipper_code = 'FEDX' then 'FedEx'
	else s.shipper_code
end as shipper_code,
s.tracking_number,
s.shipment_type_code,
l.sku
from titan.testing.dbo.udf_order u
left join titan.testing.dbo.line_item l
on u.order_number = l.order_number
left join titan.testing.dbo.shipper_tracking_number s
on l.order_number = s.order_number and l.first_shipped_shipdoc = s.shipping_document_number
left join NaturalOrder.syn_orders so
on so.order_number = u.order_number
where so.receiving_format_code = 'WE' and TRY_CONVERT(date, l.first_shipped_datetime) >= DATEADD(DAY, -7, GETDATE()) 
and not exists (
	select 1
    from Titan.Integration.dbo.shipmentlog sl
    where sl.Status = 'Completed' and sl.channelorderid = u.udf_order_text and sl.sku = l.Sku
	)



	--select top 10 *  from Titan.Integration.dbo.shipmentlog