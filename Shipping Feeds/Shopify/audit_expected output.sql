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
case
	when s.shipper_code = 'FEDX' then CONCAT('https://www.fedex.com/apps/fedextrack/?tracknumbers=',TRIM(s.tracking_number))
	when s.shipper_code = 'UPS' then CONCAT('http://wwwapps.ups.com/WebTracking/track?track=yes&trackNums=',TRIM(s.tracking_number))
	when s.shipper_code = 'USPS' then CONCAT('https://tools.usps.com/go/TrackConfirmAction?qtc_tLabels1=',TRIM(s.tracking_number))
	else null
end as [URL],
l.sku
from titan.testing.dbo.udf_order u
left join titan.testing.dbo.line_item l
on u.order_number = l.order_number
left join titan.testing.dbo.shipper_tracking_number s
on l.order_number = s.order_number and l.first_shipped_shipdoc = s.shipping_document_number
where u.udf_code in ('HHCV3','CV3') and u.udf_order_text like '%shop%' and TRY_CONVERT(date, l.first_shipped_datetime) >= DATEADD(DAY, -7, GETDATE()) 
and not exists (
	select 1
    from Titan.Integration.dbo.shipmentlog sl
    where sl.Status = 'Completed' and sl.channelorderid = u.udf_order_text and sl.sku = l.Sku
	)
order by order_number


	--select top 10 *  from Titan.Integration.dbo.shipmentlog