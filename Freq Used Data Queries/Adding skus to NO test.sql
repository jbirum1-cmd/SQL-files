select 
trim(in_item_number),
in_store,
in_department,
in_location_codes,
in_item_description,
in_retail_price,
in_quantity_on_hand
from hh.view_in_clone
where trim(in_item_number) IN (
'786850',
'1721294',
'2X2O',
'1808207',
'1905536',
'1721117',
'41009',
'1721579',
'1806236',
'1905536',
'CR6P',
'1738268',
'11012POP'
)
order by trim(in_item_number);