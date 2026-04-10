select
identifier,
shopify_physical,
shopify_status
from integration.pim.allproductstable
where core_product_data_source = 'homesource' and shopify_physical <> 'true' and shopify_status <> 'archive'