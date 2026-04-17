--get eagle test skus for sales receipts
select top 100
i.sku,
v.in_store,
v.in_privatefromecommercefg,
i.update_dtm
from titan.testing.dbo.udf_order o
join titan.testing.dbo.line_item i
on o.order_number = i.order_number
join titan.testing.[dbo].[order_status]s
on s.status_code = i.status_code
join hh.view_in_clone v
on i.sku = trim(v.in_item_number)
where v.in_store = 'd' --fba
--where v.in_privatefromecommercefg not in ('c','o','n') --web no
order by update_dtm desc


--get purchase orders for test receipts
SELECT TOP 25 
pud_po_number,
pud_line_number, 
trim(pud_item_number) AS pud_item_number, 
pud_date_due, 
puh_h_creation_date, 
pud_item_status, 
pud_stk_qty_on_order, 
pud_quantity_received, 
pud_stk_unit_cost, 
pud_distribute_to_store, 
pud_invoice_store
 FROM SQLEagle.HH.view_po_detail WITH (NOLOCK)
  LEFT JOIN SQLEagle.HH.PUH on view_po_detail.pud_po_number = PUH.[puh_po_number]
 -- WHERE TRIM(Integration.Util.RemoveWhitespace(pud_item_number)) = @sku
 ORDER BY pud_date_due ASC