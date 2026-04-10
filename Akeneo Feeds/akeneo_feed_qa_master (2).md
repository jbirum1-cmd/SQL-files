# Akeneo Feed QA — Master Test Cases

## Overview

This document captures the recurring QA patterns, specifications, test scenarios, known defects, and master test cases derived from the SQL audit/check scripts and QA tracking spreadsheets across all feed domains. It is intended as a living reference for validating data integrity between source systems (Centerspec/Homesource, Eagle ERP, NatOrd, POR) and the Akeneo PIM.

---

## Feed Domains

| Domain | Source System | Key Tables | Schedule |
|--------|---------------|------------|----------|
| Appliance Feed | Centerspec / Homesource | `titan.integration.dbo.centerspecappliances`, `centerspecspecs`, `Centerspecclassifications` | 1:00am & 3:00pm |
| Product Feed | Eagle ERP | `sqleagle.hh.view_in_clone`, `sqleagle.hh.anupc`, `sqleagle.hh.dw_item` | 12:00am & 2:00pm |
| Product Feed | NatOrd Kits | `titan.live.dbo.kitting`, `titan.live.dbo.sku`, `titan.live.dbo.catalog_price` | 12:00am & 2:00pm |
| POR Feed | POR rental system | `hrm-db-01\hrmdb01.POR.dbo.ItemFile` | Scheduled |

> **Feed order note:** Appliance feed runs at 1am/3pm and Product feed at 12am/2pm intentionally, to maintain a consistent processing order.

---

## Required Fields — Product Feed

The following fields must be populated and sent on every product feed run. Reference the *Consolidated Data Dictionary & Logic Mapping* document for full value logic.

`ManuFacturer_Code`, `Shopify_Status`, `Web_amazon_hartville`, `Web_amazon_lehmans`, `Web_website_hartville`, `Web_website_lehmans`, `store_closeout`, `core_product_data_source`, `department_name`, `department_number`, `discontinued`, `erp_title`, `fineline_code`, `fineline_name`, `hartville_location_aisle_number`, `in_stores`, `inactive`, `isNatOrdKitOnly`, `manufacturer_name`, `manufacturer_part_number`, `quantity_committed_fulfillment_center`, `quantity_committed_hartville`, `quantity_committed_middlefield`, `quantity_on_future_order_fulfillment_center`, `quantity_on_future_order_hartville`, `quantity_on_future_order_middlefield`, `quantity_on_hand_fulfillment_center`, `quantity_on_hand_hartville`, `quantity_on_hand_middlefield`, `safety_stock_fulfillment_center`, `safety_stock_hartville`, `safety_stock_middlefield`, `shopify_inventory_tracked_website_hartville`, `shopify_inventory_tracked_website_lehmans`, `upc`, `Vendor_Code`, `Vendor_Name`, `class_code`, `class_name`, `Retail_Price_amazon_hartville`, `Retail_Price_amazon_lehmans`, `Retail_Price_website_hartville`, `Retail_Price_website_lehmans`, `middlefield_location_aisle_number`

> **Note:** A few dimension fields (e.g., certain measurement fields) were observed as all-null during QA. This is documented as a mention — it may reflect genuinely missing source data rather than a feed defect.

---

## Structural Patterns

### Max-date deduplication (Appliance Feed only)

`centerspecappliances` can contain multiple rows per SKU. All appliance queries first build a `#maxupdate` temp table to isolate the most recent record before any comparison:

```sql
select sku, max(isnull(updatedate, insertdate)) as max_update_date
into #maxupdate
from titan.integration.dbo.centerspecappliances
group by sku
```

> **Known issue (resolved):** Multiple records on `centerspecappliances` with null `updatedate` or identical `updatedate` values caused incorrect ERP date selection (e.g., `JX9153DJBB`, `JX9153DJWW`). The dedup logic was corrected to use `min(insertdate)` consistently.

### Calculated vs. stored comparison

The core pattern in every check: derive what the value *should* be from the source system, compare it against what is stored in Akeneo, and return only discrepancies (rows where the check field = `'false'`).

### String normalization

Akeneo stores several field types as formatted strings that require stripping before comparison:

| Field type | Akeneo format | Strip pattern |
|------------|---------------|---------------|
| Price fields | `[{"amount":"99.99","currency":"USD"}]` | `replace(replace(field,'[{"amount":"',''),'","currency":"USD"}]','')` |
| Store arrays | `["1","4","adc"]` | `replace(replace(replace(field,'[',''),']',''),'"','')` |
| Type arrays | `["range"]` | Same as above |

### Delta feed behavior

All feeds build a results table each run and send only deltas (new or changed records) compared to the prior run stored in the `*_Previous` tables. Test cases that validate Akeneo state must account for this — a value will only update in Akeneo if it changed since the last feed run.

---

## Specification Status Tracker

### Product Feed

| Specification | Round 1 | Round 2 | Round 3 | Round 4 | Round 5 |
|---------------|---------|---------|---------|---------|---------|
| All appropriate SKUs sent | N — bug in join to data warehouse table | Y | Y | Y | Y |
| Scheduled run times (12am & 2pm) | N — left on disabled | Y | Y | Y | Y |
| Discontinued & closeout | N — closeout discrepancies; not sending when Eagle values are null | Y | Y | Y | Y |
| `shopify_physical` | N — SQL bug; values remaining null | N — still null | N — kit hard-coded | Y | Y |
| `shopify_inventory_tracked` | — | — | — | N — program overrides current value | Y |
| `shopify_status` | N — resetting to draft | Y | Y | Y | Y |
| Web yes/no — products | N — Amazon channel using stores 1 & 7 (deferred per Jenn/Ken) | Y | Y | Y | Y |
| Web yes/no — kits | Y | Y | Y | Y | Y |
| Kit store location | N — ~4,000 discrepancies | N — 3 discrepancies | Y | Y | Y |
| Kit quantities | N — multiple issues | Y | Y | Y | Y |
| Product store location | N — 3,299 discrepancies, mostly stores 12 & 18 | Y | Y | Y | Y |
| UPC sourcing (product feed) | Y | Y | Y | Y | Y |
| UPC sourcing (UPC update project) | N — 150 SKUs required full reload | Y | — | — | — |
| UPC does not exist flag | N — null values | N — null values | Y | Y | Y |
| Product pricing | N — promo on Amazon; nulls not updating; some prices not updating | N — 231 discrepancies | Y* | Y* | Y* |
| Kit pricing | — | — | Y | Y | Y |
| Data source | Y | — | Y | Y | Y |
| All required fields populated | Y | — | Y | Y | Y |
| Delta feed | — | — | Y | Y | Y |
| **ERP create date** | N — 5,000+ discrepancies on feed; 11,000+ in Akeneo; kit join logic incorrect | N — kit date not inserting into temp table | N — 12 SKUs not hitting full feed | Y | — |
| **ERP appliance date (product feed non-override)** | N — product feed overriding appliance ERP dates | Y | — | — | — |

> \* Pricing passes with the understanding that promo values will not update until Akeneo attributes are fixed on the Akeneo side.

### Appliance Feed

| Specification | Round 1 | Round 2 | Round 3 | Round 4 | Round 5 | Round 6 |
|---------------|---------|---------|---------|---------|---------|---------|
| All appropriate SKUs sent | N — 51 discrepancies | N — 53 discrepancies; obsoletes not archiving | Y | N — 7 SKUs missing | Y | Y |
| Scheduled run times (1am & 3pm) | N — running 1am & 1am | N — not updated | Y | Y | Y | — |
| `shopify_status` | N — 344 obsolete SKUs still active/draft | N — 300+ still active/draft | Y | Y | — | — |
| `shopify_physical` | Y | Y | Y | — | — | — |
| `shopify_inventory_tracked` | N — feed overriding on subsequent sends | Y | Y | — | — | — |
| Web yes/no | N — not setting web yes or web no | N — 2,000+ discrepancies | N — 1,880 discrepancies | N — 610 discrepancies | N — 16 discrepancies | Y |
| Appliance type | Y | Y | Y | Y | — | — |
| Appliance UPC (Bosch) | Y (Round 3) | — | Y | — | Y | — |
| UPC does not exist | N — 309 discrepancies; flipping each run | N — 17 discrepancies | Y | — | — | — |
| Pricing | N — not updating obsoletes; multiple records issue | Y | Y | — | — | — |
| `in_stores` | Y | Y | Y | — | — | Y |
| Data source | Y (Round 3) | — | Y | — | — | Y |
| All required fields populated | Y | Y | — | — | — | — |
| Delta feed | Y | Y | — | — | — | — |
| **ERP create date** | N — not identifying oldest insert date when multiple records exist | N — matching on model instead of SKU | Y | — | — | — |

### POR Feed (original)

| Specification | Round 1 | Round 2 |
|---------------|---------|---------|
| Only rental items sent | Y | Y |
| 4-hour pricing (`rate1`) | Y | Y |
| 1-day pricing (`rate2`) | Y | Y |
| 1-week pricing (`rate3`) | Y | Y |
| `in_stores` = `["1","por"]` (force push) | Y | Y |
| `web_website_hartville` = true (force push) | Y | Y |
| `shopify_status` = Active (force push) | Y | Y |
| `shopify_inventory_tracked` = false (force push) | Y | Y |
| Delta feed — price updates picked up | N | Y |

### POR Feed (updated program)

| Specification | Round 1 | Round 2 |
|---------------|---------|---------|
| All Akeneo rental items found; only rental items sent | Y | Y |
| 4-hour pricing (`rate1`) | Y | Y |
| 1-day pricing (`rate2`) | Y | Y |
| 1-week pricing (`rate3`) | Y | Y |
| `in_stores` = `["1","por"]` (delta updates) | Y | Y |
| `web_website_hartville` = true (force push; delta updates) | N — did not update web | Y |
| Delta feed — pricing, store, and web updates picked up | Y | Y |
| `shopify_status` removed from program (no longer sent) | Y | Y |
| `shopify_inventory_tracked` removed from program (no longer sent) | Y | Y |

---

## Master Test Cases

### 1. SKU Coverage

**Appliance eligibility rules:**
- Non-obsolete Homesource SKUs on `centerspecappliances` (ADC/obsolete filters applied at API layer)
- OR already in Akeneo with `shopify_status <> 'archive'`

**Product eligibility rules:**
- `in_privatefromecommercefg IN ('C','O','N')` AND `in_store IN ('1','2','4','7','8','12','18')` — OR already in Akeneo with `core_product_data_source = 'Eagle'`
- Kits: `dbo.kitting.active_flag = 'Y'` — OR already in Akeneo with `core_product_data_source = 'NatOrd-Kit'`
- Exclusion: `rental_item = 'true'` always excluded

**POR eligibility rules:**
- All products in `AllProductsTable` where `rental_item = 'true'`
- SKU matched to POR via `POR.dbo.ItemFile."key"` field

**Steps (product):**
1. Run `Get_Products_All_Table` to refresh Akeneo sandbox data
2. Run `audit_all product skus.sql`

**Steps (POR):**
1. Query `AllProductsTable` where `rental_item = 'yes'`
2. Execute POR program
3. Check program log product counts against step 1 results

| # | Test | Feed | Source Script | Pass Condition |
|---|------|------|---------------|----------------|
| 1.1 | All non-obsolete Homesource SKUs appear in the appliance feed | Appliance | `audit_all appliance skus.sql` | No left-join misses against `Appliance_Feed_Full` |
| 1.2 | All active Akeneo appliance SKUs (not archived) appear in the feed | Appliance | `audit_all appliance skus.sql` | No orphaned Akeneo SKUs missing from feed |
| 1.3 | Obsolete-dated SKUs in the coverage gap are flagged with their obsolete date | Appliance | `audit_all appliance skus.sql` | `obsoletedate` populated for all gap rows |
| 1.4 | All eligible Eagle SKUs appear in the product feed | Product | `audit_all product skus.sql` | No left-join misses against `Product_Feed_Full` |
| 1.5 | All active NatOrd-Kit SKUs appear in the product feed | Product | `audit_all product skus.sql` | No orphaned kit SKUs |
| 1.6 | Rental items are excluded from the product feed | Product | `audit_all product skus.sql` | No rows where `rental_item = 'true'` appear |
| 1.7 | Akeneo SKUs not found in Eagle or NO kits are identified | Product | `audit_Akeneo prods not in eagle.sql`, `audit_Akeneo kits not in NO.sql` | Zero unexpected orphans |
| 1.8 | POR program finds all Akeneo rental items and only processes rental items | POR | Manual log check | Program count matches `rental_item = 'yes'` count in Akeneo (validated: 124 items found correctly) |

---

### 2. Shopify / Lifecycle Status

#### 2a. Appliance feed — three scenarios

**Scenario 1 — Obsolete products are set to `archive`**

Steps:
1. Run `audit_shopify status by obsolete date.sql` to identify obsolete appliances still active/draft in Akeneo
2. Discrepancies represent obsolete appliances on the Centerspec table that are still active in Akeneo
3. Run feed and validate archiving

**Known defect (resolved):** Round 1 — 344 obsolete SKUs still active or draft. Round 2 — 300+ still active. Resolved in round 3.

Sample round 1 discrepancies: `JN327HBB` (Draft), `GZS22DSJSS` (Draft), `RMDD3604EX` (Active), `E6036SS` (Active), `HBN8451UC` (Active)

**Scenario 2 — New products are set to `draft`**

Steps:
1. Delete test products from `appliance_feed_previous` and Akeneo sandbox
2. Run feed
3. Verify `shopify_status = 'draft'` and all other values correct

Test products (rounds 1–2): `ACR4303MMS`, `ADFS2524RB`, `DWF18V3S`, `B36IT100NP`, `BIM18IFADALHD`, `AL57G` — all passed.

**Scenario 3 — Status updated in Akeneo is not overwritten**

Steps:
1. Change `shopify_status` in Akeneo sandbox and another field in sandbox + previous table to trigger pickup
2. Run feed
3. Verify status unchanged

Test products (rounds 1–2): `B36IT100NP`, `BIM18IFADALHD`, `AL57G`, `ADFS2524RB`, `ACR1011W` — all passed.

#### 2b. Product feed — two scenarios

**Scenario 1 — New products receive `draft`**

Test products: `0000C` ✓, `100011070` ✓, `1408712` ✓

**Scenario 2 — Feed does not overwrite manually set status**

Test products: `0000C`, `100011070`, `1408712` — all passed.

#### 2c. Test cases

| # | Test | Feed | Source Script | Pass Condition |
|---|------|------|---------------|----------------|
| 2.1 | Obsolete appliances with `obsoletedate` are set to `shopify_status = 'archive'` | Appliance | `audit_shopify status by obsolete date.sql` | Zero rows with obsoletedate and status ≠ archived |
| 2.2 | New appliances (not in previous table) receive `shopify_status = 'draft'` | Appliance | Manual — Shopify Status sheet | Status = draft after first feed run |
| 2.3 | Subsequent appliance feed runs do not overwrite a manually set `shopify_status` | Appliance | Manual — Shopify Status sheet | Status unchanged after feed delta run |
| 2.4 | New products (not in previous table) receive `shopify_status = 'draft'` | Product | Manual — Shopify Status sheet | Status = draft in Akeneo after feed run |
| 2.5 | Subsequent product feed runs do not overwrite a manually set `shopify_status` | Product | Manual — Shopify Status sheet | Status unchanged after delta run |
| 2.6 | POR feed does NOT send `shopify_status` (removed from program) | POR | Manual — Shopify status & inventory sheet | Status unchanged after POR feed run when price is updated |

---

### 3. Pricing Accuracy

#### 3a. Appliance pricing

Retail price hierarchy: UMRP → MSRP → max(calculatedcost, MAP). Sale price: if UMRP exists, no sale price is sent.

**Known issue (resolved):** Feed was not sending pricing updates for obsolete products. Pricing discrepancies were concentrated in obsolete SKUs — the program was skipping them rather than updating.

**Known issue — multiple Centerspec records:** SKUs with multiple records having null `updatedate` or identical `updatedate` values can produce incorrect pricing (wrong record selected). Examples: `JX9153DJBB`, `JX9153DJWW`, `JX9153EJES`, `JX9153SJSS`.

| # | Test | Source Script | Pass Condition |
|---|------|---------------|----------------|
| 3.1 | Retail = UMRP if non-zero; else MSRP if non-zero; else max(calculatedcost, MAP) — matches `retail_price_website_hartville` | `check_appliance prices.sql` | `retail_price_check = true` for all active SKUs |
| 3.2 | Sale price flag = `'no sale price'` when UMRP is non-zero; `'sale price'` otherwise | `check_appliance prices.sql` | Flag consistent with UMRP logic |
| 3.3 | Obsolete appliances that are already in Akeneo still receive pricing updates | `check_appliance prices.sql` | No pricing discrepancies on obsolete SKUs |

#### 3b. Eagle product pricing

Price cascade: HH = store 1, else store 2, else store 4. LEH = store 8, else store 7. Promo sent on website channels only — not Amazon. Values are floor-divided: `cast(floor(price * 100) / 100.0 as decimal(18,2))`.

**Known discrepancy patterns:**
- SKU `1396523`: promo null in Eagle — feed sends null, does not clear Akeneo existing value
- SKU `100015007`: promo on previous table correct but not updating in Akeneo (Akeneo-side issue)
- SKU `1852499`: HH retail doesn't exist in Eagle — open question whether feed should clear existing Akeneo price
- SKUs `18218`, `18222`, `33750`, `40323`, `441515`: retail price mismatch — investigate individually

| # | Test | Source Script | Pass Condition |
|---|------|---------------|----------------|
| 3.4 | HH retail = `coalesce(st1, st2, st4 retail)` matches `retail_price_website_hartville` | `check_product pricing.sql` | `HH_web_retail_check = true` |
| 3.5 | HH retail matches `retail_price_amazon_hartville` | `check_product pricing.sql` | `HH_amazon_retail_check = true` |
| 3.6 | LEH retail = `coalesce(st8, st7 retail)` matches `retail_price_website_lehmans` | `check_product pricing.sql` | `LEH_web_retail_check = true` |
| 3.7 | LEH retail matches `retail_price_amazon_lehmans` | `check_product pricing.sql` | `LEH_amazon_retail_check = true` |
| 3.8 | HH promo matches `promo_price_website_hartville` | `check_product pricing.sql` | `HH_web_promo_check = true` |
| 3.9 | LEH promo matches `promo_price_website_lehmans` | `check_product pricing.sql` | `LEH_amazon_promo_check = true` |
| 3.10 | Promo price NOT sent on Amazon channels | `check_product pricing.sql` | `promo_price_amazon_*` fields are null |

#### 3c. Kit pricing

| # | Test | Source Script | Pass Condition |
|---|------|---------------|----------------|
| 3.11 | Kit HH retail = `coalesce(MASTER13, HHMASTER)` matches `retail_price_website_hartville` | `check_product kit pricing.sql` | `hh_price_compare = true` |
| 3.12 | Kit HH Amazon = MASTER13 matches `retail_price_amazon_hartville` | `check_product kit pricing.sql` | `hh_amazon_price_compare = true` |
| 3.13 | Kit LEH retail = LEHMASTER matches `retail_price_website_lehmans` | `check_product kit pricing.sql` | `leh_price_compare = true` |
| 3.14 | Kit LEH Amazon = LEHMASTER matches `retail_price_amazon_lehmans` | `check_product kit pricing.sql` | `lehmans_amazon_price_compare = true` |

#### 3d. POR pricing

Source: `hrm-db-01\hrmdb01.POR.dbo.ItemFile` — `rate1` (4hr), `rate2` (1 day), `rate3` (1 week).

**Force push behavior:** Pricing, `in_stores`, and `web_website_hartville` are force-pushed on every run (not delta-only) to ensure values are always correct even if manually changed in Akeneo.

**Delta behavior (updated program):** Pricing, `in_stores`, and web are all delta-tracked — only items with changes are picked up on subsequent runs. `shopify_status` and `shopify_inventory_tracked` are no longer sent by the program at all.

**Round 2 force push validation (original program):**
- `08-050`: 4hr removed → reset to $10 ✓
- `12-013`: 1-day changed → reset to $65 ✓
- `20-018`: 1-week changed → reset correctly ✓
- `50-066`: web changed to no → **failed round 1** (did not reset); passed round 2
- `08-067`: `in_stores` changed → reset to `1,por` ✓
- `12-003`: web + `rental_item` set to no → product not picked up (correct) ✓

| # | Test | Source Script | Pass Condition |
|---|------|---------------|----------------|
| 3.15 | `rental_price_4_hours` matches `rate1` from POR | `check_POR data.sql` | `rate1_check = true` for all rental items |
| 3.16 | `rental_price_one_day` matches `rate2` | `check_POR data.sql` | `rate2_check = true` |
| 3.17 | `rental_price_one_week` matches `rate3` | `check_POR data.sql` | `rate3_check = true` |
| 3.18 | Pricing updates in POR are picked up on subsequent delta runs | POR delta sheet | Only changed items updated; unchanged items skipped |
| 3.19 | POR program resets pricing to POR value if manually changed in Akeneo | Manual — Pricing, store, web sheet | Price reverts to correct POR value after run |
| 3.20 | SKU with `rental_item = no` is not processed by POR program | Manual | Product skipped; values not updated |

---

### 4. UPC Integrity

#### 4a. Appliance UPCs

Only Bosch SKUs (`manufacturerid = '21'`) receive a UPC value. Strip the prefix `'upc code: '` from `centerspecspecs.specvalue`.

**Round 1 discrepancies (resolved by round 3):** 21 Bosch SKUs with NULL in Akeneo but UPC in Homesource. Examples: `SHE3AEM6N`, `HBN8451UC`, `HBN8651UC`, `SHX5AEM4N`, `NGM8058UC`.

**`upc_no_exist` logic:** If Bosch and has UPC → send `'0'` (false). All others → send `'1'` (true). Push on every run.

**Known defect (resolved):** Round 1 — 309 discrepancies; flag was flipping back and forth each run. Resolved in round 3.

**Round 1 `upc_no_exist` discrepancies:** Predominantly obsolete SKUs with null values in Akeneo. Examples: `ADB1400AMS`, `DAR016B1BM`, `DR7004WG`, `SMC1162KS`, `TC5003WN`.

#### 4b. Eagle product UPCs

Priority cascade: **Primary UPC** (`an_upc_primary_flag = 'Y'`) → **MUPC** (`an_upc_source = 'M'`, most recent date) → **most recently used valid UPC** (12 or 13 digits, most recent `an_upc_db_update_datetime`). UPCs under 12 digits bypassed at every level.

**Known edge cases:**
- SKUs `1157885`, `46735`: Multiple UPCs, no primary, no 'M' source, identical dates — cascade cannot resolve
- SKU `1738340`: Kit SKU but source in sandbox says `eagle` — prod data is correct; sandbox data source discrepancy
- SKUs `1903262`, `1903277`, `SMC1452KH`: UPC in feed but Akeneo shows NULL — known update propagation issue
- SKU `4410T`: Control character (`\x1B`) in Eagle UPC value — Eagle data quality issue
- **UPC update project (150 SKU reload):** During the UPC field refresh initiative, 150 SKUs failed to update in Akeneo and required a full reload. Resolved in round 2.

> **Note:** Bosch UPCs do not exist in Eagle. Bosch UPCs source exclusively from Centerspec/Homesource.

**Steps (product UPC validation):**
1. Run `audit_product upcs.sql` for a complete list of Eagle and kit UPCs
2. Compare test products with UPCs sent on previous table and current Akeneo values

**Steps (`upc_no_exist` validation):**
1. Run `Get_Products_All_Table`
2. Create test products with null `upc_no_exist` values
3. Run product feed (do NOT re-run `Get_Products_All_Table`)
4. Run `audit_product upc not exist.sql`

| # | Test | Feed | Source Script | Pass Condition |
|---|------|------|---------------|----------------|
| 4.1 | Bosch appliance UPC (prefix stripped) matches `upc` in Akeneo | Appliance | `check_appliance UPCs.sql` | `upc_check = true` for all active Bosch SKUs |
| 4.2 | Non-Bosch appliances without a UPC have `upc_no_exist = 'true'` | Appliance | `audit_appliance UPC Not Exists.sql` | Calculated flag matches stored flag |
| 4.3 | Bosch appliances with a UPC have `upc_no_exist = 'false'` | Appliance | `audit_appliance UPC Not Exists.sql` | No Bosch SKUs with `upc_no_exist = 'true'` |
| 4.4 | `upc_no_exist` is pushed on every run (not delta-gated) | Appliance | `audit_appliance UPC Not Exists.sql` | Flag value consistent after any run |
| 4.5 | Eagle UPC cascade (primary → MUPC → most recent valid 12/13-digit) matches `Product_Feed_Full` | Product | `check_product UPC 13 digits.sql` | `upc_compare = true` |
| 4.6 | Feed UPC (`Product_Feed_Full`) matches `upc` in `AllProductsTable` | Product | `check_product UPC 13 digits.sql` | Second comparison block returns zero rows |
| 4.7 | Eagle products without a primary-flagged UPC are identified | Product | `audit_product upcs.sql` | Known exceptions only |
| 4.8 | Kit UPCs from `titan.live.dbo.upc` (12/13 digit) match feed | Product | `check_product UPC 13 digits.sql` | `upc_compare = true` |
| 4.9 | `upc_no_exist` in Akeneo matches feed value (`true` ↔ `1`, `false` ↔ `0`) | Product | `audit_product upc not exist.sql` | `upc_no_exist_check = true` |
| 4.10 | `upc_no_exist` defaults to `'N'` (not null) when Akeneo value is null | Product | `audit_product upc not exist.sql` | No null values in Akeneo for this field |

---

### 5. Channel / Visibility Flags

> **Amazon channel decision:** Per Jenn and Ken, Amazon channel web logic (`web_amazon_hartville`, `web_amazon_lehmans`) is intentionally deferred for products. Amazon checks are commented out in v1 and v2 scripts.

#### 5a. Appliance web flag

**Logic (v2):** If `obsoletedate IS NOT NULL` → web = no. If not obsolete, check Eagle: if `in_privatefromecommercefg NOT IN ('N','C','O')` → web = no. Otherwise → web = yes.

**Known defect history:**
- Round 1: Feed not setting web yes for active appliances or web no for obsoletes
- Round 2: 2,000+ discrepancies
- Round 3: 1,880 discrepancies
- Round 4: 610 discrepancies
- Round 5: 16 discrepancies
- Round 6: Resolved ✓

**Scenario 1 — Obsolete appliances are web=no; active appliances with Eagle web=no are web=no; all others web=yes**

Steps:
1. Run `check_appliance web values.sql`
2. Update web to yes in Akeneo and on `appliance_feed_previous` table for test SKUs
3. Run program and validate

Round 1 discrepancies included: `AEP222VAW`, `GC900QPPQ`, `GX900QPPS`, `KECC056RBL`, `KURG24RWBS` — all active SKUs showing `web_website_hartville = false`.

**Scenario 2 — Appliances that become obsolete are updated to web=no**

Steps:
1. Identify obsolete test appliances
2. Update web to yes in Akeneo and on `appliance_feed_previous`
3. Run program and validate update to web=no

Round 1 failures: `413604`, `BCSD130WW`, `WRT318FZDW` — feed did not update web to no.

#### 5b. `shopify_physical`

**Appliance:** Set to `'1'` on first send only. Do not override on subsequent sends.

Steps:
1. Run `check_appliance shop physical.sql` to verify all values set
2. Select test appliances, update `shopify_physical` to no in Akeneo
3. Update another field to trigger feed and update `in_stores` on `appliance_feed_previous`
4. Run program — validate other attribute updated but `shopify_physical` did not

**Product:** Same behavior. Known defect history: Round 1 SQL bug, Round 2 still null, Round 3 kit hard-coded. Resolved round 4.

#### 5c. `shopify_inventory_tracked`

**Appliance:** Hard-code to `'1'` on first run only. Do not override on subsequent sends.

Steps:
1. Run `check_appliance shop inventory.sql`
2. Set `inventory_tracked` to no in Akeneo and `appliance_feed_previous`
3. Update `in_stores` value in both to trigger feed
4. Validate `in_stores` updated but `inventory_tracked` was not changed

**Known defect (resolved):** Appliance feed was overriding value on subsequent sends. Resolved by round 2.

**Product:** Same behavior (two scenarios). Round 4 defect: program overriding current value. Resolved round 5.

Validated test SKUs (round 5): `818585`, `771443`, `1408712` — all passed.

**POR:** `shopify_inventory_tracked` was previously force-pushed as `false`. This has been removed from the updated POR program — field no longer sent at all.

Steps (updated program):
1. Update price and change inventory tracked value in Akeneo
2. Run program
3. Validate price updated but inventory tracked did not change

Test SKUs (rounds 1–2): `26-019`, `02-006` — both passed both rounds.

#### 5d. POR `in_stores` and web values

`in_stores` = `["1","por"]` and `web_website_hartville` = true are force-pushed (and delta-tracked in updated program) on every run.

**Round 1 failure (original program):** `50-066` — web did not update back to yes when changed to no. Resolved in round 2.

#### 5e. Channel flag test cases

| # | Test | Feed | Source Script | Pass Condition |
|---|------|------|---------------|----------------|
| 5.1 | `web_website_hartville` matches calculated value from obsolete status and Eagle eligibility | Appliance | `check_appliance web values.sql` | `web_check = true` for all SKUs |
| 5.2 | Appliances that become obsolete are updated to web=no on next feed run | Appliance | Manual — Web sheet | `web_website_hartville = false` after run |
| 5.3 | `in_stores` = `["1","4","adc"]` for all active Homesource SKUs | Appliance | `check_appliance in store values.sql` | Zero deviations |
| 5.4 | `shopify_inventory_tracked_website_hartville = 'true'` for all active appliances | Appliance | `check_appliance shop inventory.sql` | Zero rows with non-true value |
| 5.5 | `shopify_physical = 'true'` for all active appliances | Appliance | `check_appliance shop physical.sql` | Zero rows with non-true value |
| 5.6 | Appliance `shopify_physical` not overwritten when manually set | Appliance | Manual — Shopify Physical sheet | Unchanged after delta feed run |
| 5.7 | Appliance `shopify_inventory_tracked` not overwritten when manually set | Appliance | Manual — Shop Inventory Tracked sheet | Unchanged after delta feed run |
| 5.8 | Eagle product `web_website_hartville` = `True` if any store 1/2/4 is eligible | Product | `check_product web value v2 no amazon.sql` | `website_hartville_compare = true` |
| 5.9 | Eagle product `web_website_lehmans` = `True` if any store 7/8 is eligible | Product | `check_product web value v2 no amazon.sql` | `website_lehmans_compare = true` |
| 5.10 | Products set to web=no in Eagle continue to send with web=`'no'` | Product | Manual — Web - products sheet | Web stays no after delta pickup |
| 5.11 | Akeneo products not in Eagle or NO receive `web = 'no'` and all other fields null | Product | `audit_Akeneo prods not in eagle.sql` | Correct values after feed run |
| 5.12 | Kit `web_website_hartville` = `True` if any HHH/HTOOL kit is `active_flag = Y` | Product | `check_product kit web values.sql` | `website_hartville_compare = true` |
| 5.13 | Kit `web_website_lehmans` = `True` if any LHAK/LHAD kit is `active_flag = Y` | Product | `check_product kit web values.sql` | `website_lehmans_compare = true` |
| 5.14 | Eagle product `in_stores` string matches store locations (D→12, J→18) | Product | `check_product in store values.sql` | `location_compare = true` |
| 5.15 | Kit `in_stores` matches warehouse mapping: HHH→1, HTOOL→2, LHAK→7, LHAD→8 | Product | `check_product kit location.sql` | `location_compare = true` |
| 5.16 | `discontinued` store string matches Eagle `in_discontinued = 'Y'` per store | Product | `check_product discontinued & closeout.sql` | `discont_compare = true` |
| 5.17 | `store_closeout` string matches Eagle `inx_store_closeout_flag = 'Y'` per store | Product | `check_product discontinued & closeout.sql` | `closeout_compare = true` |
| 5.18 | `shopify_physical = 'true'` for all non-appliance, non-rental products | Product | `check_product shop physical.sql` | Zero deviations |
| 5.19 | Product `shopify_physical` not overwritten when manually set | Product | Manual — Shopify Physical sheet | Unchanged after delta run |
| 5.20 | New products receive `shopify_inventory_tracked = 'true'` default | Product | Manual — Shopify Inventory Tracked sheet | True in Akeneo after first send |
| 5.21 | Product `shopify_inventory_tracked` not reset when manually set to no | Product | Manual — Shopify Inventory Tracked sheet | Remains no after delta run |
| 5.22 | POR `in_stores` = `["1","por"]` set correctly and restored if changed | POR | `check_POR data.sql`, Manual | Correct value in Akeneo after run |
| 5.23 | POR `web_website_hartville` = true set correctly and restored if changed | POR | `check_POR data.sql`, Manual | True in Akeneo after run |
| 5.24 | POR `shopify_status` NOT sent by updated program | POR | Manual — Shopify status & inventory sheet | Status unchanged after POR run with price update |
| 5.25 | POR `shopify_inventory_tracked` NOT sent by updated program | POR | Manual — Shopify status & inventory sheet | Inventory tracked unchanged after POR run |

---

### 6. Metadata Accuracy

#### 6a. ERP Create Date — Appliances

Logic: Minimum `insertdate` from `centerspecappliances` for the matching SKU. If multiple records exist, the oldest `insertdate` is used.

**Known defects (both resolved):**
- Round 1: Program not consistently identifying oldest `insertdate` when multiple records exist on Centerspec table. Examples: `UVD6361DPBB`, `UVD6301SPSS`, `UCC15NPRII`, `MF3051`, `CS1400R`, `HF861`.
- Round 2: Program subquery was matching on model number instead of SKU, causing wrong record selection. Same SKUs affected.

Steps:
1. Run `Get_Products_All_Table`
2. Run `check_appliance ERP create date.sql`

**Remaining discrepancies (round 4, product feed cross-check):** Several appliance SKUs showed mismatches because the product feed was overriding appliance ERP dates. Resolved by adding `coalesce(a.erp_sku_create_date, p.erp_sku_create_date)` logic to give priority to the appliance feed's date. Examples: `ADRD18H34`, `AER6303MFW`, `BCSEK136WW`.

#### 6b. ERP Create Date — Products and Kits

**Products:** `min(dwin_record_added_date)` from `sqleagle.hh.dw_item` where `dwin_store = 'M'`
**Kits:** `max(create_dtm)` of individual components from `titan.live.dbo.sku`
**Priority rule:** If a SKU exists as both a kit and an Eagle product, use the kit date.

**Known defect history (all resolved):**
- Round 1: 5,000+ feed discrepancies and 11,000+ Akeneo discrepancies. Most feed discrepancies were kits (incorrect join). Most Akeneo discrepancies were variants.
- Round 2: Kit date logic not set up to insert into temp table.
- Round 3: 12 SKUs not hitting the full feed table. Examples: `1861043`, `1866278`, `17140012`, `T575085`, `1731263`.

**Persistent known issues (rounds 3–4):** `1903262`, `1903277`, `4410T`, `1106198` — dates remain NULL in Akeneo; flagged as known update issues tied to other feed defects. `1738340` — kit SKU with source discrepancy in sandbox.

Steps:
1. Run `Get_Products_All_Table`
2. Run `check_product erp create date.sql`

#### 6c. Appliance type, data source, and other metadata

| # | Test | Feed | Source Script | Pass Condition |
|---|------|------|---------------|----------------|
| 6.1 | `core_product_data_source = 'homesource'` for all active Centerspec SKUs | Appliance | `check_appliance data source.sql` | Zero rows with wrong source |
| 6.2 | `appliance_type` matches code from `integration.appl.typemap` via `Centerspecclassifications` | Appliance | `check_appliance types.sql` | `Type_Check = True` for all active SKUs |
| 6.3 | Appliance `erp_sku_create_date` = minimum `insertdate` from `centerspecappliances` | Appliance | `check_appliance ERP create date.sql` | `date_compare = true` |
| 6.4 | Appliance ERP date is not overwritten by the product feed | Product | `check_product erp create date.sql` (Appliance sheet) | No appliance SKUs show mismatched dates from product feed override |
| 6.5 | Eagle product `erp_sku_create_date` = min `dwin_record_added_date` from `dw_item` (store M) | Product | `check_product erp create date.sql` | `date_compare = true` (both program and Akeneo checks) |
| 6.6 | Kit `erp_sku_create_date` = max component `create_dtm` from `titan.live.dbo.sku` | Product | `check_product erp create date.sql` | `date_compare = true` |
| 6.7 | When a SKU is both a kit and Eagle product, kit ERP date takes priority | Product | `check_product erp create date.sql` | Kit date used, not Eagle date |
| 6.8 | Kit QOH per store = `MIN(FLOOR(component_QOH / component_quantity))` | Product | `check_product kit quantities.sql` | `QOH_compare = true` for stores 1, 2, 4 |
| 6.9 | Kit committed, future order, and safety stock use same floor-divide logic | Product | `check_product kit quantities.sql` | All three quantity comparisons true |
| 6.10 | `core_product_data_source` set correctly: `'eagle'`, `'NatOrd-Kit'`, `'LEHImport'`, or `'Akeneo only'` | Product | `check_appliance data source.sql` | Zero rows with unexpected source |

---

## Known Gaps / Recommended Additional Tests

| Gap | Recommendation |
|-----|----------------|
| Archived SKUs in feed output | Validate that `shopify_status = 'archived'` records are fully excluded from feed file rows, not just status-checked |
| Rental item exclusion consistency | Confirm `ISNULL(rental_item, 'false') <> 'true'` filter applied consistently across all product feed checks |
| Amazon channel flags (product) | Amazon web checks commented out in v1/v2 scripts — document final decision from Jenn/Ken and update scripts accordingly |
| Bosch UPC Eagle vs. Homesource alignment | `check_bosch upc.sql` compares Eagle UPC to Homesource UPC — add to master run as cross-system check |
| UPC control character | SKU `4410T` has control character (`\x1B`) in Eagle UPC — flag Eagle data quality issue for remediation |
| Multi-UPC tie-breaking | SKUs with multiple UPCs, no primary flag, no 'M' source, and identical dates cannot be resolved by the cascade — define expected behavior and add explicit test |
| Price clear behavior | When a product's price no longer exists in Eagle, define whether feed should clear the Akeneo price or leave it (see SKU `1852499`) |
| Scheduled run validation | Add smoke-test confirming feed executed at scheduled times — early rounds failed because jobs were left disabled |
| Null dimension fields | Several dimension fields (e.g., certain measurement attributes) are all null in Akeneo. Confirm whether this reflects genuinely missing source data or a feed gap |
| POR SKU matching validation | Confirm behavior when a `rental_item = 'true'` SKU in Akeneo has no matching record in `POR.dbo.ItemFile` — program logs a warning; determine if any action is required |
| Centerspec multiple-record tie-breaking | Formally document the dedup rule for SKUs with identical `updatedate` values to prevent regression (linked to ERP date and pricing issues) |
| Data source — appliances in Eagle | Some Homesource appliances also exist in Eagle. Confirm whether `core_product_data_source` should be `'homesource'` or `'eagle'` for these SKUs (noted as open question in appliance QA) |

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
| `check_POR data.sql` | POR | Pricing / Channel Flags |
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
