select
identifier,
shopify_physical,
core_product_data_source
from pim.AllProductsTable
where core_product_data_source <> 'homesource' and ISNULL(rental_item, 'false') <> 'true'