select
identifier,
shopify_inventory_tracked_website_hartville,
shopify_status
from integration.pim.allproductstable
where core_product_data_source = 'homesource' and shopify_inventory_tracked_website_hartville <> 'true' and shopify_status <> 'archived'