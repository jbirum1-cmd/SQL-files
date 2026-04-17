SELECT top 100
 --od_transaction_number AS [transaction],
 cast(od_transaction_number as varchar(25)) AS [transaction],
 TRIM(od_item) AS item,
 od_store_number AS store,
 od_qty_selling_units AS qty_selling_units,
 oh_creation_date AS transaction_date,
 od_actual_selling_price AS actual_selling_price,
 od_cost AS cost,
 'eagle' AS source_type,
 'E' as source_type_code
FROM [SQLEagle].[HH].[OD] (NOLOCK)
 INNER JOIN [SQLEagle].[HH].[OH] ON
  od_transaction_number = oh_transaction_num AND
  od_store_number = oh_store_number
WHERE
 -- TRIM(od_item) = @sku
  oh_transaction_type<>'E'

UNION ALL

SELECT top 100 * FROM (
 SELECT
  li.order_number,
  sku,
  coalesce(strlkp1.StoreNum, strlkp2.StoreNum) AS store,
  li.quantity_ordered,
  o.today AS transaction_date,
  product_price,
  li.sku_list_price,
  'natural-order' AS sourceType,
  'NO' as source_type_code
 FROM DataWarehouse.LiveDB.line_item (NOLOCK) li
  INNER JOIN DataWarehouse.LiveDB.Orders o
   ON li.order_number=o.order_number
  LEFT JOIN Datawarehouse.LKP.EagleStore_To_NatOrd strlkp1
   ON li.warehouse_code=strlkp1.WarehouseCode 
    AND o.receiving_format_code=strlkp1.ReceivingFormat
    AND strlkp1.ReceivingFormat IS NOT NULL
  LEFT JOIN Datawarehouse.LKP.EagleStore_To_NatOrd strlkp2
   ON li.warehouse_code=strlkp2.WarehouseCode 
    AND strlkp2.ReceivingFormat IS NULL
 WHERE line_item_status_code IS NOT NULL
  AND li.status_code <> 'X'
  AND coalesce(li.line_item_status_code,'') <> 'C'
  AND (li.quantity_ordered-li.canceled_quantity) <> li.shipped_quantity
  -- AND sku=@sku
) a
ORDER BY transaction_date DESC