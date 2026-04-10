select
i.orderid,
i.linenumber,
i.amazonorderid,
i.numberofitems,
i.itemprice,
i.sellersku,
isnull(i.shippingprice,0) as ShippingPrice,
isnull(i.shippingdiscount,0) as ShippingDiscount,
o.storeid,
i.dateentered
from ordimp.amazonorderitems i
join ordimp.amazonorders o
on i.AmazonOrderId = o.AmazonOrderId
where dateentered like '%2026%' and isnull(shippingprice,0) = isnull(shippingdiscount,0) and storeid = '1'
order by dateentered desc

--is null test scenarios
select
i.orderid,
i.linenumber,
i.amazonorderid,
i.numberofitems,
i.itemprice,
i.sellersku,
i.shippingprice,
i.shippingdiscount,
o.storeid,
i.dateentered
from ordimp.amazonorderitems i
join ordimp.amazonorders o
on i.AmazonOrderId = o.AmazonOrderId
where dateentered like '%2026%' and storeid = '1'
order by dateentered desc