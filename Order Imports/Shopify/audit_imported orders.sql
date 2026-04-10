--select * from integration.inv.ShopifyPending
--select * from integration.ordimp.ImportedOrders order by dateupdated desc
--select * from integration.ordimp.shopifyorders order by createdat desc
--select * from integration.ordimp.shopifyorderitems

--data from imported orders & shopify orders tables
select
o.orderid,
o.exported as export_flag,
o.imported as import_flag,
o.datecreated as import_date,
o.dateupdated as impore_update_date,
s.shopifyordername,
s.billingfirstname,
s.billinglastname,
s.billingaddress1,
s.billingaddress2,
s.billingzip,
s.shippingfirstname,
s.shippinglastname,
s.ShippingAddress1,
s.ShippingAddress2,
s.shippingcity,
s.shippingzip,
s.shippingcharges,
s.totalcharge,
s.paymentgateways,
s.originalpaymentgateways,
i.linenumber,
i.sku,
i.quantity,
i.unitprice,
i.totalprice,
i.discountedallocations
from integration.ordimp.ImportedOrders o 
left join integration.ordimp.shopifyorders s
on substring(o.orderid,21,13) = s.shopifyorderid
left join integration.ordimp.shopifyorderitems i
on s.id = i.orderid
where o.orderid like '%shopify%' and cast(o.datecreated as date) >= '2026-03-18'
order by shopifyordername desc 

--NO data
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
where o.udf_code = 'hhcv3' and o.order_number like '%hwebs%'
order by o.order_number desc

select * from integration.inv.ShopifyPending

select * from integration.ordimp.orderkickout