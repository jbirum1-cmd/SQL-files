# Cross-Program QA Failure Pattern Analysis

## Overview

This report synthesizes pass/fail data from 11 integration programs across four domains: Akeneo Feeds, Inventory, Amazon/Partner, and Shopify Orders. Together these programs cover 52 tracked specifications. 34 of those specs (65%) failed on their first QA round, and 8 recurring root causes account for the vast majority of all failures observed.

---

## Programs Analyzed

| Program | Domain | Specs Tracked | Rounds |
|---------|--------|---------------|--------|
| Akeneo Appliance Feed | Akeneo | 13 | 6 |
| Akeneo Product Feed | Akeneo | 21 | 5 |
| POR Feed (original) | Akeneo | 9 | 2 |
| POR Feed (updated) | Akeneo | 9 | 2 |
| FBM Updates | Amazon / Inventory | 2 | 4 |
| Festool Updates | Inventory / Partner | 5 | 6 |
| Shopify Inventory Rewrite | Inventory | 7 | 5 |
| Shop Open Orders Update | Inventory | 3 | 2 |
| Shopify Inventory Updates (HK) | Inventory | 6 | 3 |
| Kit Update Logic (Shipping) | Shopify Orders | 5 | 4 |
| Shop Shipping Feed | Shopify Orders | 7 | 4 |

---

## Summary Statistics

| Metric | Value |
|--------|-------|
| Total programs | 11 |
| Total specs tracked | 52 |
| Specs failing round 1 | 34 (65%) |
| Specs needing 3+ rounds to resolve | 10 |
| Unique recurring root causes | 8 |
| Longest resolution | 6 rounds (appliance web flag) |

---

## Failure Frequency by Root Cause

| Root cause | Occurrences | Domains affected |
|------------|-------------|-----------------|
| Kit / component logic errors | 10 | All four |
| SKU scope / eligibility filter gaps | 9 | All four |
| Pending / open order deduction errors | 8 | Inventory only |
| Multi-record / dedup logic | 7 | Akeneo, Amazon, Orders |
| Lifecycle / status handling | 7 | Akeneo, Amazon |
| Wrong join / subquery key | 6 | All four |
| Force-push vs. delta confusion | 5 | Akeneo, Inventory |
| Channel / location ID misconfiguration | 5 | Akeneo, Inventory |
| Null / default value not handled | 4 | Akeneo, Inventory |
| Multi-line / multi-shipment order logic | 3 | Shopify Orders only |
| Operational (config / schedule) | 2 | Akeneo |

---

## Root Cause Heat Map by Domain

| Root cause | Akeneo Feeds | Inventory | Amazon / Partner | Shopify Orders |
|------------|-------------|-----------|-----------------|----------------|
| Kit logic errors | 5 | 4 | 1 | 1 |
| SKU scope gaps | 3 | 3 | 2 | 1 |
| Pending order deduction | 0 | 8 | 0 | 0 |
| Multi-record dedup | 5 | 0 | 1 | 1 |
| Lifecycle / status handling | 6 | 0 | 1 | 0 |
| Channel / location ID config | 1 | 4 | 0 | 0 |
| Multi-line / shipment order logic | 0 | 0 | 0 | 3 |

---

## Detailed Pattern Analysis

### Pattern 1: Kit logic is the most failure-prone area, across every domain

Kit-related failures appeared in 9 of the 11 programs. The bugs vary by domain but cluster into the same underlying mistakes.

In **inventory programs**, kit QOH was duplicated due to join fanout before the floor-divide logic was applied, and component quantities were never aggregated to the minimum-per-store before being linked back to the parent SKU. The Shopify Inventory Rewrite took three rounds just to get component SKUs reliably re-mapped back to their parent kit SKU in the final output.

In **Akeneo feeds**, the floor-divide (`MIN(FLOOR(QOH / component_quantity))`) was initially missing or applied incorrectly across stores, and kit priority over Eagle product dates was an afterthought.

In the **Festool feed**, the discontinued-component exclusion logic was over-exclusionary — dropping entire kit SKUs when only one component was flagged discontinued, even if inventory existed.

In the **Kit Update / Shipping feed**, kit line items weren't falling off the stored procedure correctly after fulfillment, causing them to be reprocessed on subsequent runs.

The consistent thread: **kit logic is treated as an extension of product logic, when in practice it requires its own separate code path.** Every program that handles both products and kits introduced a kit-specific bug because the two were conflated.

---

### Pattern 2: Pending and open order deductions are consistently miscounted in inventory programs

Every inventory program had at least one round where the wrong deduction was applied to the wrong channel. The Shopify Inventory Rewrite failed on three separate deduction errors:
- Amazon pending wasn't being deducted from HH and Middlefield
- Shopify pending was being double-deducted from the Shopify location feed (Shopify already deducts its own pending orders)
- The shop open orders add-back was scoped to only the HHH warehouse code, bleeding into other location calculations

The Shop Open Orders program introduced another wrinkle: Shopify open orders should be *added back in* to avoid double-deduction — counterintuitive, and missed on first pass. The HK program had shop pending added to Middlefield where it shouldn't apply at all.

This is a domain-specific pattern concentrated entirely in inventory programs, but universal within that domain. **No inventory program got all deductions right on the first pass.** The complexity comes from several concurrent deduction sources (Eagle committed, product reserve, safety stock, Amazon pending, Shopify pending, Shopify open orders) that each have different scoping rules by warehouse, channel, and location.

---

### Pattern 3: SKU scope and eligibility filters always miss edge cases on first implementation

Three categories of scoping failures appeared across the new programs:

The **Festool feed** went through four rounds of eligibility fixes: it first excluded discontinued items that had remaining inventory, then pulled in non-Festool kits from other vendors (JD, 5V&VA), then dropped valid kits due to over-exclusionary discontinued-component logic, then silently dropped 8 kit SKUs due to null values on the catalog alias table.

The **Shopify Inventory Rewrite** dropped all Homesource SKUs because the logic to bring them in was never added. A second class of mystery SKUs then appeared — SKUs in Akeneo and Shopify not in Eagle — requiring separate investigation.

The **FBM Updates** feed silently dropped 8 kit SKUs because nulls on the catalog alias table caused inadvertent join-based exclusions — the same root cause as Festool, independently rediscovered.

This convergence on the same bug (null catalog alias values silently dropping records) across two unrelated programs is significant. **Joins to lookup or reference tables fail silently when records are missing or null, and programs have no mechanism to report the drop.**

---

### Pattern 4: Multi-channel programs consistently misconfigure channel routing on first pass

The Shopify Inventory Rewrite's location ID issues persisted for four consecutive rounds: production LEH IDs used instead of sandbox, mapping table updated but the case statement wasn't, sandbox ID duplicated instead of sandbox/production pair, and log data missing four location IDs in round 4. Each fix addressed only the symptom tested in that round.

The Shop Shipping Feed had a related issue: HH and LEH operate differently at the tracking table level (HH has one record per order, LEH has multiple), but the program assumed both channels work identically. The LEH multiple-shipment logic failed because this structural difference wasn't known at build time.

The POR updated program missed the web value update in round 1. The FBM feed added NatOrd order logic only in the fifth round — it wasn't in the original spec.

**Programs routing to multiple channels are built with one channel in mind, and the second channel is a retrofit.** The second channel consistently surfaces its own edge cases that the first channel never had.

---

### Pattern 5: Multi-record ordering and tie-breaking fails without explicit handling

This was the dominant Akeneo failure mode and reappears in the Shopify Shipping feed. When tracking numbers aren't ordered by date (the `MIN(date_shipped)` rule), the program picks up whichever record the query returns first — nondeterministic behavior that will fail under specific timing conditions.

The multi-line item scenario in the Shipping feed produced the clearest example: when one line item shipped but not the other, the program applied the first line item's tracking number to all line items on the order, incorrectly marking the unshipped line as fulfilled.

**Any time a query can return multiple rows where the business rule requires exactly one, and there's no explicit ordering or ranking, the behavior is undefined and will fail in production.**

---

### What the operational programs revealed that Akeneo data alone could not

Three failure categories become prominent only when the operational programs are included:

**Silent record drops from reference table nulls.** Two programs independently failed because null values on a lookup table (`catalog_alias`) dropped records with no error or warning. Akeneo programs had similar join-based exclusions but they were caught by audit SQL. These operational programs had no equivalent population audit to catch the loss.

**Shopify deduction double-counting.** The entire class of pending/open order deduction math is unique to inventory programs and wasn't visible in the Akeneo data at all. It's the most complex calculation family across all programs, with the most moving parts, and every program got it wrong in round 1.

**Order-level multi-line isolation.** Shipping fulfillment at the line-item level is a completely different problem space. The key failure mode — shipping data leaking from one line item to another — has no analog in the Akeneo world but is critical for order accuracy.

---

## Recommended QA Focus Areas

### From Akeneo program analysis (original 8)

1. **Lifecycle edge case coverage before round 1.** Verify the program has explicit branches for obsolete/archived records, not just active ones. What does the program send for a product being obsoleted for the first time? What about one already obsolete when the program first runs?

2. **Multi-record source table stress test.** For any source table that can hold multiple rows per SKU, add test cases with: a SKU with null update date, a SKU with two records sharing the same update date, and a SKU whose records have different insert dates. Verify the correct record is selected.

3. **Force-push vs. delta specification document.** Before development starts, require a written field-level spec categorizing every output field as: send on first run only / send on every run (force push) / send only when changed (delta). QA should verify each category in separate scenarios.

4. **Null and default value sweep.** After each round, query `AllProductsTable` checking for unexpected nulls on every field the program populates. Fields with a defined default should never be null for eligible products.

5. **Population-scale audit before spot-check validation.** Run the audit SQL scripts comparing the full source population to the destination before scenario-based spot checks. Structural join errors and encoding issues produce bulk failures not detectable by testing a handful of SKUs.

6. **Scheduled job verification as a day-one check.** Confirm the job ran at the expected times before evaluating any data results. A job that didn't run produces false passes (values unchanged = looks correct) alongside failures.

7. **Cross-feed interference testing.** Whenever two programs write to overlapping fields, QA must include a test that runs both programs in sequence and confirms neither overwrites the other's values. Most critical for shared fields like `erp_sku_create_date`, `core_product_data_source`, and Shopify flags.

8. **Regression check on previously passing specs.** Each new QA round should start by re-running all previously-passing checks before testing new fixes — not just the checks related to current development work.

### From cross-program analysis (4 new additions)

9. **Silent drop audit for all reference table joins.** Any join to a lookup or reference table (catalog alias, SKU cross-reference, location map) should have a corresponding count check. If the output row count is materially lower than the input, the program should log the discrepancy rather than silently pass the smaller file.

10. **Inventory deduction checklist before coding.** Before implementing any inventory calculation, document the complete deduction stack for each channel: which deductions apply, which channels deduct their own pending orders (Shopify does; Amazon does not in the same way), and which amounts need to be added back. This checklist should be signed off before any code is written.

11. **Separate kit code paths with their own test pass.** Every program handling both products and kits should have kit-specific test cases running independently of product test cases — different test SKUs, separate SQL validation queries, and explicit checks for join-fanout and the floor-divide calculation. Kit logic that passes as part of a general product sweep is not tested kit logic.

12. **Second-channel parity test before any multi-channel program ships.** For programs routing to HH and LEH (or any two channels), the final QA round should include a structured comparison using identical test SKUs to confirm both channels behave symmetrically. Structural differences between channels should be documented in the spec before development, not discovered in QA.
