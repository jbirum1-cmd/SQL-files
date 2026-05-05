select distinct
o.ShopifyOrderName,
c.CorrectedSku,
c.ShopifySku,
c.createdby,
c.createdat,
c.updatedby,
c.updatedat
from integration.ordimp.shopifycustomproducts c
left join [ORDIMP].[ShopifyOrders] o
on o.ShopifyOrderId = c.ShopifyOrderId

