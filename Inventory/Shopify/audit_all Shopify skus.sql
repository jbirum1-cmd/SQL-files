--todo: add hk items

--gets shopify product skus from eagle hh
drop table if exists #products
select distinct
sv.sku as shopify_sku,
sv.Environment,
sv.store,
sm.id as shopify_location
into #products
from Integration.INV.ShopifyVariants sv
join sqleagle.hh.view_in_clone v
on trim(v.in_item_number) = sv.sku
join INV.ShopifyLocationMap sm
on sm.parentid = sv.id
where v.in_store in ('1','2','4','7','8') and sv.environment <> 'production' and sm.id = 'gid://shopify/Location/79232401544'
 -- And NOT EXISTS (       -------removed loig. Per Scott, JD should not be excluded.
 --       SELECT 1
 --       FROM titan.integration.dbo.JDPartsInfo j
 --       WHERE j.partnumber = sv.sku
 --);
 -- AND NOT EXISTS (        ------removed logic. The join to eagle removes the need for this
 --       SELECT 1
 --       FROM #ApplianceExclusions a
 --       WHERE a.centerspec_sku = sv.sku
 --)
 --And NOT EXISTS (        ------removed logic. The join to eagle removes the need for this
 --       SELECT 1
 --       FROM temp.porskus p
 --       WHERE p.skus = sv.sku
 --);

 --gets shopify product skus from Homesource
 drop table if exists #homesource
select distinct
sv.sku as shopify_sku,
sv.Environment,
sv.store,
sm.id as shopify_location
into #homesource
from Integration.INV.ShopifyVariants sv
join titan.integration.dbo.centerspecappliances c
on c.sku = sv.sku
join INV.ShopifyLocationMap sm
on sm.parentid = sv.id
where c.obsoletedate is null and sv.environment <> 'production' and sm.id = 'gid://shopify/Location/79232401544'


 --gets shopify kit skus
drop table if exists #kits
select distinct
sv.sku as shopify_sku,
sv.Environment,
sv.store,
sm.id as shopify_location
into #kits
from Integration.INV.ShopifyVariants sv
join titan.testing.dbo.kitting k
on k.sku = sv.sku
join INV.ShopifyLocationMap sm
on sm.parentid = sv.id
where sv.environment <> 'production' and sm.id = 'gid://shopify/Location/79232401544'
 -- And NOT EXISTS (
 --       SELECT 1
 --       FROM titan.integration.dbo.JDPartsInfo j
 --       WHERE j.partnumber = sv.sku
 --);

 /*
 removed HK logic from program
 --gets shopify product skus from eagle hk
drop table if exists #kitchen
select distinct
sv.sku as shopify_sku,
sv.Environment,
sv.store,
sm.id as shopify_location
into #kitchen
from Integration.INV.ShopifyVariants sv
join cv3.cv3hkitems v
on v.sku = sv.sku
join INV.ShopifyLocationMap sm
on sm.parentid = sv.id
where sv.environment <> 'production' --and sm.id = 'gid://shopify/Location/79232401544'  
 --select * from #kitchen
 */

 --unions kits,products, and homesource
drop table if exists #total
 select *
 into #total
 from #products

 union 

 select *
 from #kits 

 union 
 
 select *
 from #homesource

 select * from #total

/*compare logic using temp table

 select distinct
 t.shopify_sku
 from #total t
 left join temp.shop_hhshop h
 on t.shopify_sku = h.sku  
 where h.sku is null and t.shopify_location = 'gid://shopify/Location/79143207048'

  select distinct
 t.shopify_sku
 from temp.shop_hhshop h
 left join #total t
 on t.shopify_sku = h.sku
 where t.shopify_sku is null

 select * from inv.ShopifyVariants
 where sku = 'M143520M'
 select * from inv.ShopifyLocationMap
where parentid = 'gid://shopify/ProductVariant/44494198079624'
*/