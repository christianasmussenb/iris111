# Copilot Prompts — Quick Reference
## Sprint-by-sprint ready-to-use prompts

**Cómo usar:** Copypaste el prompt exacto en un comentario o chat de Copilot, Copilot sugerirá completions.

---

## SPRINT 1

### S1 — Agent-1 (Bronze)

**Prompt: Create Bronze.POSEvent class**

```
Create an IRIS ObjectScript persistent class Bronze.POSEvent that:

Purpose: Store raw POS events without transformation
Extends: %Persistent
Fields (in order):
  - sourceId (String, key/unique identifier)
  - receivedAt (TimeStamp, UTC time of ingestion)
  - transactionId (String)
  - transactionDateTime (TimeStamp)
  - storeCode (String)
  - registerNumber (String)
  - employeeId (String)
  - customerId (String, nullable)
  - lineNumber (Integer)
  - itemCode (String)
  - itemDescription (String)
  - quantity (Numeric)
  - quantityUOM (String)
  - unitPrice (Numeric)
  - lineAmount (Numeric)
  - discount (Numeric, nullable)
  - taxCode (String)
  - taxAmount (Numeric)
  - totalLineAmount (Numeric)
  - rawPayload (Stream.GlobalBinary for audit)
  - loadError (String, nullable)

Indices:
  - sourceId (unique)
  - storeCode
  - transactionDateTime

No methods needed for now. Include docstring at class level explaining purpose.
```

**Prompt: Create POSService Inbound Service**

```
Create IRIS Inbound Service Inbound.POSService that:

Purpose: Ingest POS boletas from file system or queue
Extends: Ens.BusinessService
Adapter: EnsLib.File.InboundAdapter

Methods to implement:
1. OnProcessInput(pInput, pOutput, ByRef pHint)
   - Override from parent
   - Parse JSON/CSV from pInput
   - Call persistToBronze() for each boleta
   - Handle errors: if parsing fails, log to Ens.MessageHeader with error details
   
2. parseJSON(payload As %String) As %DynamicObject
   - Parse JSON boleta payload
   - Validate required fields
   - Return %DynamicObject representing the boleta
   
3. persistToBronze(boleta As %DynamicObject) As %Status
   - Create Bronze.POSEvent object
   - Populate fields from boleta
   - If any field missing/invalid, set loadError and return error status
   - Persist to DB
   - Return $$$OK if successful

Include docstrings for each method explaining inputs/outputs/throws.
```

**Prompt: Generate test_bronze.script**

```
Generate an IRIS ObjectScript test script test_bronze.script that:

1. Load 100 sample boletas from a test JSON array
2. Persist each to Bronze.POSEvent via POSService
3. Verify Bronze.POSEvent.Extent() returns >= 100
4. Verify all sourceIds are unique (no duplicates)
5. Verify receivedAt timestamps are in UTC and monotonically increasing
6. Verify no loadError is set for valid records
7. Query by storeCode index and verify results
8. Query by transactionDateTime index and verify results

Output test results:
✓ Bronze.POSEvent.Extent() = 100
✓ All sourceIds unique
✓ Timestamps monotonic
✓ No loadErrors for valid data
✓ Index queries work

Script should be runnable via `do ^test_bronze`
```

---

### S1 — Agent-2 (Masters)

**Prompt: Create MD.SKU master data class**

```
Create IRIS persistent class MD.SKU for product master data:

Purpose: Store product/SKU information
Extends: %Persistent
Fields:
  - sku (String, 13 digits GTIN, unique key)
  - description (String)
  - categoryCode (String, reference to MD.Category)
  - categoryKeyId (ObjectIdentity, FK to MD.Category.%ObjectId)
  - baseUOM (String, unit of measure: UN, kg, L, pack)
  - active (Boolean, default 1)
  - effectiveFromDate (Date)
  - effectiveToDate (Date, nullable)
  - createdAt (TimeStamp, auto-set)
  - updatedAt (TimeStamp, auto-update)

Indices:
  - skuIdx on sku (unique)
  - categoryIdx on categoryCode
  - descriptionIdx on description

No complex methods. Just data container with proper docstrings.
```

**Prompt: Create MD.Store master data class**

```
Create IRIS persistent class MD.Store for store/location master:

Purpose: Store store locations and hierarchy
Extends: %Persistent
Fields:
  - storeCode (String, unique identifier like "GT-0145")
  - storeName (String)
  - region (String)
  - zone (String)
  - storeFormat (String, e.g., "SUPERMARKET", "EXPRESS")
  - timezone (String, e.g., "America/Guatemala")
  - address (String)
  - phone (String, nullable)
  - managerName (String, nullable)
  - active (Boolean, default 1)
  - openedDate (Date)
  - closedDate (Date, nullable)
  - createdAt (TimeStamp)
  - updatedAt (TimeStamp)

Indices:
  - storeCodeIdx on storeCode (unique)
  - regionZoneIdx on (region, zone)

No complex methods. Data container.
```

**Prompt: Create MD.Category master data class**

```
Create IRIS persistent class MD.Category for product categories:

Purpose: Organize products into categories for aggregation
Extends: %Persistent
Fields:
  - categoryCode (String, unique, e.g., "BEVA-GASA")
  - categoryName (String)
  - parentCategoryCode (String, nullable, for hierarchy)
  - active (Boolean, default 1)
  - createdAt (TimeStamp)
  - updatedAt (TimeStamp)

Indices:
  - categoryCodeIdx on categoryCode (unique)
  - parentIdx on parentCategoryCode

No complex methods. Data container.
```

**Prompt: Create MD.SalesBudget class**

```
Create IRIS persistent class MD.SalesBudget for sales targets:

Purpose: Store daily sales budget targets by store/category
Extends: %Persistent
Fields:
  - storeCode (String, FK to MD.Store)
  - categoryCode (String, FK to MD.Category)
  - budgetDate (Date, the day this budget applies)
  - budgetQuantity (Numeric, target qty for the day)
  - budgetRevenue (Numeric, target revenue for the day)
  - budgetCurrency (String, default "COP")
  - source (String, e.g., "MANUAL", "SYSTEM_PLAN")
  - loadedAt (TimeStamp)
  - loadedBy (String, user who loaded)
  - notes (String, nullable)

Indices:
  - storeCategoryDayIdx on (storeCode, categoryCode, budgetDate) (unique composite)

No complex methods. Data container.
```

**Prompt: Generate mock_data_loader.py**

```
Generate a Python script mock_data_loader.py that:

1. Creates 50 SKUs with:
   - GTIN-13 codes (random but valid EAN format)
   - Descriptions (realistic product names)
   - Categories (BEVA-GASA, ACEI-VEG, GALL-DUL, LACT, CARN)
   - baseUOM (UN, kg, L, pack)

2. Creates 5 stores:
   - Codes: GT-0145, GT-0320, GT-0088, CR-0050, CL-0075
   - Names, regions, timezones matching countries

3. Creates 10 categories with hierarchy

4. Generates 30 days of budgets (May 1-30, 2026) for each (store, category) combination

5. Outputs to CSV files:
   - data/skus.csv
   - data/stores.csv
   - data/categories.csv
   - data/budgets.csv

Script should be runnable via: python3 mock_data_loader.py
```

---

### S1 — Agent-3 (Config + Integration)

**Prompt: Create Config/Constants.cls**

```
Create IRIS class Config.Constants as utility for global configuration:

Purpose: Single source of truth for all thresholds, windows, settings
Format: Class parameters (ClassParameter), no instances

Parameters to define:
  - VERSION = "0.1.0-S1"
  - PACE_CRITICAL_THRESHOLD = -25 (percentage points)
  - PACE_SUSTAINED_THRESHOLD = -10
  - SUSTAINED_COUNT = 3 (consecutive windows)
  - GOLD_WINDOW_MINUTES = 15
  - RULE_EVAL_INTERVAL_MINUTES = 15
  - BUDGET_LOAD_TIME = "06:00"
  - DEFAULT_CURRENCY = "COP"
  - LOG_LEVEL = "DEBUG"
  - LOG_FORMAT = "JSON"

Include docstring explaining what each parameter controls.
No methods needed.
```

**Prompt: Generate setup_local.sh script**

```
Generate bash script setup_local.sh for local development setup:

Steps to automate:
1. Check IRIS Community is running (ping localhost:52773)
2. Check IRIS_PASSWORD env var is set, else prompt
3. Load Config/Constants.cls
4. Load all Bronze, Silver, Gold, Masters classes via ./scripts/load_classes.sh
5. Run mock_data_loader.py to generate test data
6. Import CSV data (skus, stores, categories, budgets) into IRIS
7. Verify: count records in each master table, verify Bronze is empty
8. Run test_bronze.script to test ingestion

Output on completion:
✓ IRIS running
✓ Classes compiled
✓ Master data loaded ({N} SKUs, {N} Stores, ...)
✓ test_bronze PASSED

Script should be runnable via: ./scripts/setup_local.sh
```

---

## SPRINT 2

### S2 — Agent-1 (Silver Model)

**Prompt: Create Silver.SaleLine class**

```
Create IRIS persistent class Silver.SaleLine for normalized sales data:

Purpose: Store POS sales lines after normalization and enrichment
Extends: %Persistent
Fields:
  - bronzeEventId (ObjectIdentity, reference to Bronze.POSEvent)
  - normalizedAt (TimeStamp, UTC when normalized)
  - storeCode (String, matches MD.Store.storeCode)
  - storeKeyId (ObjectIdentity, FK to MD.Store)
  - transactionDateTime (TimeStamp, when sale occurred)
  - transactionId (String)
  - lineNumber (Integer)
  - sku (String, GTIN-13 normalized)
  - skuKeyId (ObjectIdentity, FK to MD.SKU)
  - quantity (Numeric, in baseUOM)
  - baseUOM (String, always normalized unit)
  - unitPrice (Numeric)
  - lineAmount (Numeric)
  - amountAfterTax (Numeric)
  - categoryCode (String, derived from SKU)
  - categoryKeyId (ObjectIdentity, FK to MD.Category)
  - validationStatus (String, enum: OK, WARN, ERROR)
  - validationMessage (String, nullable)

Indices:
  - storeCodeIdx on storeCode
  - skuIdx on sku
  - transactionDateTimeIdx on transactionDateTime
  - categoryIdx on categoryCode

No complex methods. Data container with docstrings.
Public query contract (for Gold later):
  SELECT * FROM Silver.SaleLine WHERE transactionDateTime > ? AND categoryCode = ?
```

**Prompt: Generate test_silver.script**

```
Generate IRIS test script test_silver.script:

1. Manually create 10 Silver.SaleLine records with valid references to:
   - MD.Store (use storeKeyId from GT-0145)
   - MD.SKU (use skuKeyId from an existing SKU)
   - MD.Category (use categoryKeyId from category)

2. Verify each record persists successfully

3. Query by storeCode index: SELECT * WHERE storeCode="GT-0145"
   Verify returns expected records

4. Query by transactionDateTime index: SELECT * WHERE transactionDateTime > ?
   Verify returns expected records

5. Verify validationStatus is populated (OK)

6. Verify no data loss from Bronze

Output:
✓ Silver.SaleLine.Extent() >= 10
✓ Index storeCode works (returns records)
✓ Index transactionDateTime works (returns records)
✓ All required fields populated
✓ validationStatus = OK

Runnable via: do ^test_silver
```

---

### S2 — Agent-2 (BPL Pipeline)

**Prompt: Create BPL Pipeline as ObjectScript class**

```
Create IRIS BPL (Business Process Language) exported as ObjectScript class Pipeline/SalesProcess.cls:

Purpose: Orchestrate the flow from Bronze to Silver (and eventually Gold)

Process flow:
1. Receive message from Inbound service (Bronze.POSEvent)
2. For each line in the boleta:
   a. Lookup MD.SKU by GTIN
   b. If not found, set validationStatus=ERROR, validationMessage="SKU not found"
   c. Lookup MD.Store by storeCode
   d. Resolve category from SKU
   e. Persist to Silver.SaleLine
3. After all lines processed, count Silver records and log summary
4. Fire event: "SalesProcessCompleted" (for future Rule evaluation)

Error handling:
- If any line fails, log but continue (don't block other lines)
- If entire transaction fails, set validationStatus=ERROR

Implementation:
- Use %Persistent classes, not BPL visual XML (for version control)
- Include docstrings for each step
- Call Silver.Normalizer.normalize() (placeholder, Agent-3 will implement)

Methods:
- OnRequest(pRequest, pResponse) - main entry point
- pProcessLine(pBronzeId, pLineNumber) - process one line
- pLookupSKU(pGTIN) - lookup in MD.SKU
- pLookupStore(pStoreCode) - lookup in MD.Store
```

---

### S2 — Agent-3 (Silver Normalizer)

**Prompt: Create Silver/Normalizer.cls**

```
Create IRIS class Silver.Normalizer for normalizing Bronze → Silver:

Purpose: Transform raw POS event to normalized sales line
Extends: %SerialObject (utility class)

Public method:
  ClassMethod normalize(pBronzeId As %String) As Silver.SaleLine
    - Input: Bronze.POSEvent ObjectId
    - Lookup Bronze record
    - For each line (Bronze has multiple lines):
      1. Normalize SKU (validate GTIN-13)
      2. Normalize UOM (convert to base unit if needed)
      3. Lookup category from SKU
      4. Validate required fields
      5. Create and persist Silver.SaleLine
    - Return the Silver.SaleLine (last one, or first if only one)
    - Throw exception if critical field missing (storeCode, transactionDate, etc)
    - Set validationStatus based on outcome

Private helper methods:
  - pNormalizeSKU(gtin As %String) As %String
    - Pad with zeros if needed, validate check digit
  - pNormalizUOM(input As %String) As %String
    - Map "botella" → "UN", "litro" → "L", etc.
  - pValidateRequired(line As %DynamicObject) As %Status
    - Check storeCode, transactionDate, lineNumber, itemCode, quantity present
  - pLookupCategory(skuId As %ObjectIdentity) As %String
    - Query MD.SKU to get categoryCode

Include comprehensive docstrings.
```

---

## SPRINT 3

### S3 — Agent-1 (Gold Model + Calculator)

**Prompt: Create Gold/CategoryPace.cls**

```
Create IRIS persistent class Gold.CategoryPace for sales pace tracking:

Purpose: Store aggregated sales by time window for pace monitoring
Extends: %Persistent
Fields:
  - storeCode (String)
  - categoryCode (String)
  - dateOfDay (Date, the calendar day)
  - hourOfDay (Integer, 0-23 local time)
  - windowStartUTC (TimeStamp, start of 15-min window UTC)
  - windowEndUTC (TimeStamp, end of 15-min window UTC)
  - windowDuration (Integer, minutes: 15, 60, 1440)
  - transactionCount (Integer, # of boletas in window)
  - lineItemCount (Integer, # of lines in window)
  - quantitySold (Numeric, total qty sold)
  - revenueSold (Numeric, total revenue sold)
  - budgetQuantity (Numeric, daily target qty)
  - budgetRevenue (Numeric, daily target revenue)
  - paceCompletionPct (Numeric, % of budget relative to time elapsed)
  - deviationPct (Numeric, negative if behind pace)
  - hoursElapsed (Numeric, hours since store opened)
  - projectedFinalCompletionPct (Numeric, extrapolated to close)
  - ruleTriggeredId (String, nullable)
  - ruleTriggeredAt (TimeStamp, nullable)
  - isOutOfPace (Boolean)

Indices:
  - storeCategoryDayIdx on (storeCode, categoryCode, dateOfDay)
  - storeCategoryHourIdx on (storeCode, categoryCode, windowStartUTC)

No methods needed (Agent-1 will create GoldCalculator).
```

**Prompt: Create Gold/GoldCalculator.cls**

```
Create IRIS class Gold.GoldCalculator for pace calculations:

Purpose: Calculate pace metrics from Silver sales data
Extends: %SerialObject (utility)

Main public method:
  ClassMethod calculatePace(storeCode, categoryCode, budgetDate, currentTimeUTC) As Gold.CategoryPace
    - Query Silver.SaleLine for (store, category) since store open until currentTimeUTC on budgetDate
    - Read MD.SalesBudget for (store, category, budgetDate)
    - Calculate:
      * quantitySold = SUM(quantity) from Silver
      * revenueSold = SUM(lineAmount) from Silver
      * hoursElapsed = (currentTimeUTC - store open time) / 3600
      * expectedQtyAtThisTime = budgetQuantity * (hoursElapsed / hoursInOperatingDay)
      * paceCompletionPct = (quantitySold / expectedQtyAtThisTime) * 100 if expectedQty > 0
      * deviationPct = paceCompletionPct - 100 (negative if behind)
    - Create Gold.CategoryPace record with calculated values
    - Return the record (newly persisted)

Helper method:
  ClassMethod calculateForWindow(storeCode, categoryCode, windowStartUTC, windowEndUTC) As Gold.CategoryPace
    - Query Silver for lines within window
    - Aggregate qty, revenue
    - Create Gold record for window

Helper method:
  ClassMethod pEvalDeviationVsBudget(sold, budget, hoursElapsed, hoursTotal) As %Numeric
    - Internal pace formula

Include docstrings with examples of pace calculation.
```

---

### S3 — Agent-2 (Rules Engine)

**Prompt: Create Rules/ThresholdRule.cls and seed data**

```
Create IRIS persistent class Rules.ThresholdRule for configurable rules:

Purpose: Store rule definitions that trigger on Gold aggregates
Extends: %Persistent
Fields:
  - ruleId (String, unique, e.g., "PACE_CRITICAL")
  - description (String)
  - enabled (Boolean, default 1)
  - ruleExpression (String, e.g., "deviationPct < -25")
  - thresholdValue (Numeric)
  - severityLevel (String, enum: HIGH, MEDIUM, INFO)
  - windowTypeMinutes (Integer, 60 or 1440)
  - minOccurrences (Integer, default 1)
  - createdAt (TimeStamp)
  - updatedAt (TimeStamp)

Indices:
  - ruleIdIdx on ruleId (unique)

No complex methods.

Seed 5 rules into the database:
1. PACE_CRITICAL: deviationPct < -25, severity=HIGH, window=60min
2. PACE_SUSTAINED: deviationPct < -10 for 3 windows, severity=MEDIUM
3. STOCKOUT_INFERRED: quantitySold=0 for 2h, severity=HIGH
4. RECOVERY: deviationPct crosses 0 (negative to positive), severity=INFO
5. OOS_TOP_SKU: stockout in top-20 SKU, severity=HIGH
```

**Prompt: Create Rules/RuleEvaluator.cls**

```
Create IRIS class Rules.RuleEvaluator for evaluating Gold records against rules:

Purpose: Check which rules fire for a given Gold.CategoryPace record
Extends: %SerialObject

Main public method:
  ClassMethod evaluateAllRules(pGoldRecord As Gold.CategoryPace) As %List
    - Loop through all enabled Rules.ThresholdRule
    - Call evaluateRule() for each
    - Return list of ruleIds that triggered (may be empty list)

Method:
  ClassMethod evaluateRule(pGoldRecord, pRuleId) As %Boolean
    - Load Rules.ThresholdRule by ruleId
    - Call pEvaluateExpression() to test rule against Gold record
    - Return 1 if rule triggers, 0 otherwise

Private method:
  ClassMethod pEvaluateExpression(pExpression, pGoldRecord) As %Boolean
    - Parse expression like "deviationPct < -25" or "quantitySold = 0"
    - Evaluate against Gold record fields
    - Return 1 or 0

Include docstrings.
```

---

### S3 — Agent-3 (REST API)

**Prompt: Create API/UIController.cls with REST endpoints**

```
Create IRIS REST controller API.UIController:

Purpose: Expose application state to frontend via REST API
Extends: %CSP.REST

Endpoints to implement:

1. GET /api/v1/stores/{storeCode}/categories/{categoryCode}/pace
   - Query Gold.CategoryPace for today + current hour
   - Return JSON: { storeCode, categoryCode, paceCompletionPct, deviationPct, quantitySold, budgetQuantity, isOutOfPace, ruleTriggeredId }

2. GET /api/v1/recommendations/pending?storeCode={code}
   - Query Ops.Recommendation where feedbackStatus='PENDING'
   - Return JSON array: [ { id, categoryCode, actionName, parameters, recommendedAt }, ... ]

3. POST /api/v1/recommendations/{recommendationId}/feedback
   - Payload: { status: 'ACCEPTED'|'REJECTED'|'MODIFIED', modifications: {...} }
   - Update Ops.Recommendation record
   - Return updated record

4. GET /api/v1/dashboard/store/{storeCode}
   - Return summary for store today (all categories aggregated)

5. GET /api/v1/health
   - Return { status: "ok", timestamp: now, version }

Methods to implement:
- GET(pUrl, pDocObj) - override to dispatch
- pGetPace(storeCode, categoryCode) - returns %DynamicObject
- pGetRecommendationsPending(storeCode) - returns %DynamicArray
- pPostFeedback(recId, payload) - updates DB, returns %DynamicObject
- pGetDashboard(storeCode) - returns %DynamicObject
- pHealthCheck() - returns %DynamicObject

Error handling:
- 404 if resource not found
- 400 if bad parameters
- 500 on DB error (don't expose stack trace)
- Log all requests to Ens.MessageHeader

Include docstrings for each endpoint describing inputs/outputs.
```

---

## SPRINT 4

### S4 — Agent-1 (React Components)

**Prompt: React Setup + Components**

```
Setup React project with Vite and create 3 components:

1. Project init:
   - npm create vite@latest iris-poc-ui -- --template react
   - npm install axios tailwindcss
   - Setup tailwind.config.js with custom colors (teal, navy)

2. Component: RecommendationsPending.jsx
   - Fetch from GET /api/v1/recommendations/pending?storeCode=...
   - Display as list of cards:
     * Category code
     * Action name (e.g., "Mover palet a entrada")
     * Parameters (discount %, SKU, etc.)
     * Buttons: "Aceptar", "Rechazar", "Modificar"
   - On accept: call POST /api/v1/recommendations/{id}/feedback
   - Mobile-responsive (Tailwind)

3. Component: ComplianceDashboard.jsx
   - Fetch from GET /api/v1/stores/{code}/categories/{category}/pace
   - Display:
     * Large % of pace (big number)
     * Arrow up/down (green if on pace, red if behind)
     * Time elapsed (hours)
     * Qty sold vs budget (side-by-side comparison)
   - Auto-refresh every 5 minutes

4. Component: HistoryTable.jsx
   - Fetch recommendations history (feedback_received_at is not null)
   - Table: Date | Action | Status (Accepted/Rejected) | Effect (qty lift)
   - Sortable by date

Components should:
- Use React hooks (useState, useEffect)
- Import axios from shared service (placeholder)
- Use Tailwind for styling (no CSS files)
- Include propTypes for type checking
```

---

### S4 — Agent-2 (React Services + API Client)

**Prompt: Create React services and REST client**

```
Create axios REST client and state management:

File: src/services/api.js
- Create axios instance with baseURL = "/api/v1"
- Implement methods:
  * getPace(storeCode, categoryCode) - GET /stores/{}/categories/{}/pace
  * getRecommendationsPending(storeCode) - GET /recommendations/pending
  * postFeedback(recommendationId, status, modifications) - POST /recommendations/{}/feedback
  * getDashboard(storeCode) - GET /dashboard/store/{}
  * getHealth() - GET /health

File: src/services/auth.js (stub for now)
- mockAuth() - fake auth, set localStorage['storeCode']
- getCurrentStore() - read from localStorage
- logout() - clear localStorage

File: src/App.jsx (main router)
- Simple router: Home page, click to select store, then show 3 components
- Pass storeCode as prop to all child components
- Error boundary

File: .env.example
- VITE_API_URL=http://localhost:52773

Test on mobile browser (devtools, <375px width) and verify responsive.
```

---

## Quick prompts for debugging / common tasks

### "Copilot, I need to add a field to a class"

```
I need to add a new field to Silver.SaleLine class:
- Field name: productPromoCode
- Type: String (nullable)
- Purpose: Track promotional code applied at POS

Update the class definition, add docstring for the new field.
Do not break any existing functionality or indices.
```

### "Copilot, generate a test for this method"

```
I have a method Gold.GoldCalculator.calculatePace() that takes (storeCode, categoryCode, budgetDate, currentTimeUTC) and returns Gold.CategoryPace.

Generate a unit test that:
1. Sets up 10 Silver.SaleLine records for store GT-0145, category BEVA-GASA, date 2026-05-13
2. Distributes sales across 12 operating hours (06:00 to 18:00)
3. Budget for the day: 50 units (4.2 units/hour needed to stay on pace)
4. Calls calculatePace() at hour 10:00 (4 hours elapsed, expecting ~17 units sold)
5. Verifies paceCompletionPct and deviationPct are calculated correctly

Test should be runnable and assertions should clearly state expected vs actual values.
```

### "Copilot, refactor this code to avoid duplication"

```
I have three methods that all do similar query + aggregate patterns:

Class Gold.GoldCalculator {
  aggregateByDay(store, cat, date) { ... }
  aggregateByHour(store, cat, date, hour) { ... }
  aggregateByWindow(store, cat, start, end) { ... }
}

All three methods:
1. Query Silver.SaleLine with different WHERE clauses
2. SUM(quantity) and SUM(lineAmount)
3. Create Gold.CategoryPace and persist

Refactor to DRY principle by extracting common logic into a helper method.
```

---

**End of prompts document.**

**How to use:**
1. Copy the prompt for your sprint/component
2. Paste into GitHub Copilot or Claude Code chat
3. Let Copilot generate the code
4. Review output: does it match the _MODULE_INFO.md contract?
5. If yes, commit; if no, adjust prompt and retry

**Tips:**
- Be specific about inputs/outputs
- Reference _MODULE_INFO.md in prompts
- Include docstring requirements
- Ask for error handling explicitly
- Request test coverage

