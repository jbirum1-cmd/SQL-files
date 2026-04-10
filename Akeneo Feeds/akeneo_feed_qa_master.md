# Akeneo Feed QA — Master Test Cases

## Overview

This document captures the recurring QA patterns and master test cases derived from the SQL audit and check scripts across both feed domains. It is intended as a living reference for validating data integrity between source systems (Centerspec/Homesource, Eagle ERP, NatOrd) and the Akeneo PIM.

---

## Feed Domains

| Domain | Source System | Key Tables |
|--------|---------------|------------|
| Appliance Feed | Centerspec / Homesource | `titan.integration.dbo.centerspecappliances`, `centerspecspecs`, `Centerspecclassifications` |
| Product Feed | Eagle ERP | `sqleagle.hh.view_in_clone`, `sqleagle.hh.anupc`, `sqleagle.hh.dw_item` |
| Product Feed | NatOrd Kits | `titan.live.dbo.kitting`, `titan.live.dbo.sku`, `titan.live.dbo.catalog_price` |
| POR Feed | POR system | `temp.portesting` |

---

## Structural Patterns

These patterns repeat across nearly every script and should be understood before reading individual test cases.

### Max-date deduplication (Appliance Feed only)

`centerspecappliances` can contain multiple rows per SKU. All appliance queries first build a `#maxupdate` temp table to isolate the most recent record before any comparison:

```sql
select sku, max(isnull(updatedate, insertdate)) as max_update_date
into #maxupdate
from titan.integration.dbo.centerspecappliances
group by sku
```

The product feed avoids this because `view_in_clone` is already pre-filtered.

### Calculated vs. stored comparison

The core pattern in every check: derive what the value *should* be from the source system, compare it against what is stored in Akeneo, and return only discrepancies (rows where the check field = `'false'`).

### String normalization

Akeneo stores several field types as formatted strings that require stripping before comparison:

| Field type | Akeneo format | Strip pattern |
|------------|---------------|---------------|
| Price fields | `[{"amount":"99.99","currency":"USD"}]` | `replace(replace(field,'[{"amount":"',''),'","currency":"USD"}]','')` |
| Store arrays | `["1","4","adc"]` | `replace(replace(replace(field,'[',''),']',''),'"','')` |
| Type arrays | `["range"]` | Same as above |

---

## QA Dimensions

All scripts fall into one of six recurring dimensions:

1. SKU Coverage
2. Shopify / Lifecycle Status
3. Pricing Accuracy
4. UPC Integrity
5. Channel / Visibility Flags
6. Metadata Accuracy

---

## Master Test Cases

### 1. SKU Coverage

Validates that all eligible source-system SKUs are represented in the feed, and that no unexpected orphans exist in Akeneo.

| # | Test | Feed | Source Script | Pass Condition |
|---|------|------|---------------|----------------|
| 1.1 | All non-obsolete Homesource SKUs appear in the appliance feed | Appliance | `audit_all appliance skus.sql` | No rows returned from left-join miss against `Appliance_Feed_Full` |
| 1.2 | All active Akeneo appliance SKUs (not archived) appear in the feed | Appliance | `audit_all appliance skus.sql` | No orphaned Akeneo SKUs missing from feed |
| 1.3 | Obsolete-dated SKUs returned in coverage gap are flagged with their obsolete date | Appliance | `audit_all appliance skus.sql` | `obsoletedate` is populated for all gap rows |
| 1.4 | All Eagle SKUs with eligible `in_privatefromecommercefg` (C/O/N) in designated stores appear in the feed | Product | `audit_all product skus.sql` | No rows from left-join miss against `Product_Feed_Full` |
| 1.5 | All active NatOrd-Kit SKUs appear in the feed | Product | `audit_all product skus.sql` | No orphaned kit SKUs |
| 1.6 | Akeneo product-source SKUs not found in Eagle or NO kits are identified | Product | `audit_Akeneo prods not in eagle.sql`, `audit_Akeneo kits not in NO.sql` | Orphan audit returns zero unexpected rows |

**Eligible store list — Eagle:** `1, 2, 4, 7, 8, 12 (D), 18 (J)`
**Eligible `in_privatefromecommercefg` values:** `C`, `O`, `N`

---

### 2. Shopify / Lifecycle Status

Validates that archived and active states in Akeneo correctly reflect the source system's lifecycle signals.

| # | Test | Feed | Source Script | Pass Condition |
|---|------|------|---------------|----------------|
| 2.1 | SKUs with an `obsoletedate` in Centerspec are marked `archived` in Akeneo | Appliance | `audit_shopify status by obsolete date.sql` | Zero rows where `obsoletedate IS NOT NULL` and `shopify_status <> 'archived'` |
| 2.2 | SKUs without an `obsoletedate` are not archived in Akeneo | Appliance | `audit_all appliance skus.sql` | No active Homesource SKUs show archived status |
| 2.3 | New Eagle/kit products not yet in Akeneo are identified for onboarding | Product | `audit_product shop status.sql` | New product audit returns expected candidates only; no surprises |

---

### 3. Pricing Accuracy

Validates that prices in Akeneo match the values calculated from the source system's pricing fields.

#### 3a. Appliance pricing

| # | Test | Source Script | Pass Condition |
|---|------|---------------|----------------|
| 3.1 | Retail price = UMRP if non-zero; else MSRP if non-zero; else max(calculatedcost, MAP) — matches `retail_price_website_hartville` | `check_appliance prices.sql` | `retail_price_check = true` for all active SKUs |
| 3.2 | Sale price flag = `'no sale price'` when UMRP is non-zero; `'sale price'` otherwise | `check_appliance prices.sql` | Flag consistent with UMRP logic |

#### 3b. Eagle product pricing

| # | Test | Source Script | Pass Condition |
|---|------|---------------|----------------|
| 3.3 | HH retail = `coalesce(st1, st2, st4 retail)` matches `retail_price_website_hartville` | `check_product pricing.sql` | `HH_web_retail_check = true` |
| 3.4 | HH retail matches `retail_price_amazon_hartville` | `check_product pricing.sql` | `HH_amazon_retail_check = true` |
| 3.5 | LEH retail = `coalesce(st8, st7 retail)` matches `retail_price_website_lehmans` | `check_product pricing.sql` | `LEH_web_retail_check = true` |
| 3.6 | LEH retail matches `retail_price_amazon_lehmans` | `check_product pricing.sql` | `LEH_amazon_retail_check = true` |
| 3.7 | HH promo price matches `promo_price_website_hartville` | `check_product pricing.sql` | `HH_web_promo_check = true` |
| 3.8 | LEH promo price matches `promo_price_website_lehmans` | `check_product pricing.sql` | `LEH_amazon_promo_check = true` |

> **Note:** Prices are floor-divided to 2 decimal places before comparison: `cast(floor(price * 100) / 100.0 as decimal(18,2))`

#### 3c. Kit pricing

| # | Test | Source Script | Pass Condition |
|---|------|---------------|----------------|
| 3.9 | Kit HH retail = `coalesce(MASTER13, HHMASTER)` matches `retail_price_website_hartville` | `check_product kit pricing.sql` | `hh_price_compare = true` |
| 3.10 | Kit HH Amazon price = MASTER13 matches `retail_price_amazon_hartville` | `check_product kit pricing.sql` | `hh_amazon_price_compare = true` |
| 3.11 | Kit LEH retail = LEHMASTER matches `retail_price_website_lehmans` | `check_product kit pricing.sql` | `leh_price_compare = true` |
| 3.12 | Kit LEH Amazon price = LEHMASTER matches `retail_price_amazon_lehmans` | `check_product kit pricing.sql` | `lehmans_amazon_price_compare = true` |

---

### 4. UPC Integrity

Validates UPC values and the `upc_no_exist` flag across both feeds.

#### 4a. Appliance UPCs

| # | Test | Source Script | Pass Condition |
|---|------|---------------|----------------|
| 4.1 | Bosch SKUs: Centerspec UPC (with `'upc code: '` prefix stripped) matches `upc` in Akeneo | `check_appliance UPCs.sql` | `upc_check = true` for all active Bosch SKUs (`manufacturerid = '21'`) |
| 4.2 | Non-Bosch appliances without a UPC have `upc_no_exist = 'true'` in Akeneo | `audit_appliance UPC Not Exists.sql` | Calculated flag matches stored flag |
| 4.3 | Bosch appliances always have `upc_no_exist = 'false'` regardless of UPC presence | `audit_appliance UPC Not Exists.sql` | No Bosch SKUs with `upc_no_exist = 'true'` |

#### 4b. Product UPCs

| # | Test | Source Script | Pass Condition |
|---|------|---------------|----------------|
| 4.4 | Eagle UPC selection cascade: primary flag Y → MUPC (source=M) → most recent valid 12/13-digit UPC — matches `Product_Feed_Full` | `check_product UPC 13 digits.sql` | `upc_compare = true` |
| 4.5 | Feed UPC matches `upc` stored in `AllProductsTable` | `check_product UPC 13 digits.sql` | Second comparison block returns zero rows |
| 4.6 | Eagle products without any primary-flagged UPC are identified | `audit_product upcs.sql` | Known exceptions documented; no unexpected gaps |
| 4.7 | Kit UPCs from `titan.live.dbo.upc` (12/13 digit only) match feed | `check_product UPC 13 digits.sql` | `upc_compare = true` |
| 4.8 | `upc_no_exist` flag in Akeneo matches feed value (`true` ↔ `1`, `false` ↔ `0`) | `audit_product upc not exist.sql` | `upc_no_exist_check = true` |

---

### 5. Channel / Visibility Flags

Validates web visibility, store location strings, Shopify physical/inventory flags, and discontinued/closeout indicators.

#### 5a. Appliance channel flags

| # | Test | Source Script | Pass Condition |
|---|------|---------------|----------------|
| 5.1 | `web_website_hartville` = `true` when any store 1/2/4 record has `in_privatefromecommercefg` in (C, N, O) or is null; `false` when `obsoletedate IS NOT NULL` | `check_appliance web values.sql` | `web_check = true` for all SKUs |
| 5.2 | `in_stores` = `["1","4","adc"]` for all active Homesource SKUs | `check_appliance in store values.sql` | Zero rows deviating from expected value |
| 5.3 | `shopify_inventory_tracked_website_hartville = 'true'` for all active appliances | `check_appliance shop inventory.sql` | Zero rows where value is not `true` |
| 5.4 | `shopify_physical = 'true'` for all active appliances | `check_appliance shop physical.sql` | Zero rows where value is not `true` |

#### 5b. Product channel flags

| # | Test | Source Script | Pass Condition |
|---|------|---------------|----------------|
| 5.5 | Eagle product `web_website_hartville` = `True` if any store 1/2/4 record has eligible `in_privatefromecommercefg` | `check_product web value v2 no amazon.sql` | `website_hartville_compare = true` |
| 5.6 | Eagle product `web_website_lehmans` = `True` if any store 7/8 record is eligible | `check_product web value v2 no amazon.sql` | `website_lehmans_compare = true` |
| 5.7 | Kit `web_website_hartville` = `True` if any HHH/HTOOL warehouse kit has `active_flag = Y` | `check_product kit web values.sql` | `website_hartville_compare = true` |
| 5.8 | Kit `web_website_lehmans` = `True` if any LHAK/LHAD warehouse kit has `active_flag = Y` | `check_product kit web values.sql` | `website_lehmans_compare = true` |
| 5.9 | Eagle product `in_stores` string matches store locations from `view_in_clone` (D→12, J→18) | `check_product in store values.sql` | `location_compare = true` |
| 5.10 | Kit `in_stores` matches warehouse code mapping: HHH/HTOOL→1/2, LHAK/LHAD→7/8 | `check_product kit location.sql` | `location_compare = true` |
| 5.11 | `discontinued` store string matches Eagle `in_discontinued = 'Y'` records per store | `check_product discontinued & closeout.sql` | `discont_compare = true` |
| 5.12 | `store_closeout` string matches Eagle `inx_store_closeout_flag = 'Y'` records per store | `check_product discontinued & closeout.sql` | `closeout_compare = true` |
| 5.13 | `shopify_physical = 'true'` for all non-appliance, non-rental products | `check_product shop physical.sql` | Zero rows deviating |

---

### 6. Metadata Accuracy

Validates data source classification, product type codes, ERP create dates, and kit inventory quantities.

#### 6a. Appliance metadata

| # | Test | Source Script | Pass Condition |
|---|------|---------------|----------------|
| 6.1 | `core_product_data_source = 'homesource'` for all active Centerspec SKUs | `check_appliance data source.sql` | Zero rows with wrong source value |
| 6.2 | `appliance_type` matches the code mapped from `integration.appl.typemap` via `Centerspecclassifications` | `check_appliance types.sql` | `Type_Check = True` for all active SKUs |
| 6.3 | `erp_sku_create_date` = minimum `insertdate` from `centerspecappliances` | `check_appliance ERP create date.sql` | `date_compare = true` for all SKUs |

#### 6b. Product metadata

| # | Test | Source Script | Pass Condition |
|---|------|---------------|----------------|
| 6.4 | Eagle product `erp_sku_create_date` = minimum `dwin_record_added_date` from `sqleagle.hh.dw_item` (store M) | `check_product erp create date.sql` | `date_compare = true` (program check and Akeneo check) |
| 6.5 | Kit `erp_sku_create_date` = maximum component `create_dtm` from `titan.live.dbo.sku` | `check_product erp create date.sql` | `date_compare = true` |
| 6.6 | Kit quantity on hand (per store) = `FLOOR(component_QOH / component_quantity)` — minimum across all components | `check_product kit quantities.sql` | `QOH_compare = true` for stores 1, 2, 4 |
| 6.7 | Kit committed quantity matches same floor-divide logic | `check_product kit quantities.sql` | `committed_quantity_compare = true` |
| 6.8 | Kit future order quantity matches same floor-divide logic | `check_product kit quantities.sql` | `quantity_on_future_order_compare = true` |
| 6.9 | Kit safety stock matches same floor-divide logic | `check_product kit quantities.sql` | `safety_stock_compare = true` |

#### 6c. POR / Rental metadata

| # | Test | Source Script | Pass Condition |
|---|------|---------------|----------------|
| 6.10 | POR rental items: `rental_price_4_hours` in Akeneo matches `rate1` from POR system | `check_POR data.sql` | `rate1_check = true` |
| 6.11 | `rental_price_one_day` matches `rate2` | `check_POR data.sql` | `rate2_check = true` |
| 6.12 | `rental_price_one_week` matches `rate3` | `check_POR data.sql` | `rate3_check = true` |

---

## Known Gaps / Recommended Additional Tests

The following scenarios are not yet covered by existing scripts:

| Gap | Recommendation |
|-----|----------------|
| Archived SKUs appearing in feed output | Validate that `shopify_status = 'archived'` records are fully excluded from feed file rows, not just status-checked |
| Rental item exclusion from standard feed | Confirm `ISNULL(rental_item, 'false') <> 'true'` filter is applied consistently across all product feed checks (pricing, quantities, UPC) |
| `LEH import` data source handling | Verify this exclusion in kit audits is intentional and consistently applied across all relevant scripts |
| Bosch UPC Eagle vs. Homesource alignment | `check_bosch upc.sql` compares Eagle UPC to Homesource UPC — add this to the master run as a cross-system consistency check |
| Amazon channel flags for Eagle products | Amazon web value checks are commented out in v1 and v2 scripts — document whether these are intentionally excluded or pending |

---

## Script Inventory

| Script | Feed | Dimension |
|--------|------|-----------|
| `audit_all appliance skus.sql` | Appliance | SKU Coverage |
| `audit_appliance UPC Not Exists.sql` | Appliance | UPC Integrity |
| `audit_shopify status by obsolete date.sql` | Appliance | Lifecycle Status |
| `check_appliance ERP create date.sql` | Appliance | Metadata |
| `check_appliance UPCs.sql` | Appliance | UPC Integrity |
| `check_appliance data source.sql` | Appliance | Metadata |
| `check_appliance in store values.sql` | Appliance | Channel Flags |
| `check_appliance prices.sql` | Appliance | Pricing |
| `check_appliance shop inventory.sql` | Appliance | Channel Flags |
| `check_appliance shop physical.sql` | Appliance | Channel Flags |
| `check_appliance types.sql` | Appliance | Metadata |
| `check_appliance web values.sql` | Appliance | Channel Flags |
| `check_POR data.sql` | POR | Metadata |
| `audit_Akeneo kits not in NO.sql` | Product | SKU Coverage |
| `audit_Akeneo prods not in eagle.sql` | Product | SKU Coverage |
| `audit_UPC list.sql` | Product | UPC Integrity |
| `audit_all product skus.sql` | Product | SKU Coverage |
| `audit_product shop status.sql` | Product | Lifecycle Status |
| `audit_product upc not exist.sql` | Product | UPC Integrity |
| `audit_product upcs.sql` | Product | UPC Integrity |
| `check_bosch upc.sql` | Product | UPC Integrity |
| `check_product UPC 13 digits.sql` | Product | UPC Integrity |
| `check_product discontinued & closeout.sql` | Product | Channel Flags |
| `check_product erp create date.sql` | Product | Metadata |
| `check_product in store values.sql` | Product | Channel Flags |
| `check_product kit location.sql` | Product | Channel Flags |
| `check_product kit pricing.sql` | Product | Pricing |
| `check_product kit quantities.sql` | Product | Metadata |
| `check_product kit web values.sql` | Product | Channel Flags |
| `check_product pricing.sql` | Product | Pricing |
| `check_product shop physical.sql` | Product | Channel Flags |
| `check_product web value v1.sql` | Product | Channel Flags |
| `check_product web value v2 no amazon.sql` | Product | Channel Flags |
