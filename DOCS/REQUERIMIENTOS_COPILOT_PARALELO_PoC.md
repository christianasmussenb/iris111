# Requerimientos para Desarrollo Paralelo con GitHub Copilot
## PoC Cumplimiento de Presupuesto en Tiempo Real — IRIS

**Versión:** 1.0  
**Fecha:** Mayo 2026  
**Modalidad:** 2-3 agentes Copilot en paralelo, sin conflictos de integración  
**Objetivo:** Acelerar desarrollo mantieniendo integridad del código y fácil merge

---

## 1. Estructura del repositorio (anti-conflicto)

### 1.1 Layout raíz

```
iris-poc/
├── .github/
│   ├── workflows/
│   │   ├── ci-bronze.yml
│   │   ├── ci-silver.yml
│   │   ├── ci-gold.yml
│   │   ├── ci-api.yml
│   │   ├── ci-frontend.yml
│   │   └── merge-check.yml
│   └── COPILOT_PROMPTS.md (este archivo)
├── objectscript/
│   ├── Bronze/
│   │   ├── POSEvent.cls
│   │   └── _MODULE_INFO.md
│   ├── Silver/
│   │   ├── SaleLine.cls
│   │   ├── Normalizer.cls
│   │   └── _MODULE_INFO.md
│   ├── Gold/
│   │   ├── CategoryPace.cls
│   │   ├── GoldCalculator.cls
│   │   └── _MODULE_INFO.md
│   ├── Inbound/
│   │   ├── POSService.cls
│   │   └── _MODULE_INFO.md
│   ├── Pipeline/
│   │   ├── SalesProcess.bpl (export as .cls)
│   │   └── _MODULE_INFO.md
│   ├── Decision/
│   │   ├── ActionSelector.cls
│   │   └── _MODULE_INFO.md
│   ├── API/
│   │   ├── UIController.cls
│   │   └── _MODULE_INFO.md
│   └── Config/
│       ├── Constants.cls
│       └── GlobalConfig.cls
├── frontend/
│   ├── src/
│   │   ├── components/
│   │   ├── services/
│   │   ├── pages/
│   │   └── styles/
│   ├── tests/
│   ├── package.json
│   └── .env.example
├── tests/
│   ├── objectscript/
│   │   ├── test_bronze.script
│   │   ├── test_silver.script
│   │   ├── test_gold.script
│   │   ├── test_api.script
│   │   └── test_e2e.script
│   └── frontend/
│       ├── integration.test.js
│       └── unit.test.js
├── scripts/
│   ├── load_classes.sh
│   ├── run_tests.sh
│   ├── setup_local.sh
│   └── mock_data_loader.py
├── docs/
│   ├── ARCHITECTURE.md
│   ├── DATA_MODEL.md
│   ├── API_SPEC.md
│   └── TROUBLESHOOTING.md
├── data/
│   ├── skus.csv (master data)
│   ├── stores.csv (master data)
│   ├── budgets.csv (sample)
│   └── sample_boletas_500.json
├── config.yml
├── .gitignore
├── README.md
└── CONTRIBUTING.md
```

### 1.2 Convención: _MODULE_INFO.md

Cada módulo tiene un archivo `_MODULE_INFO.md` que documenta:

```markdown
# Module: Bronze

## Purpose
Raw POS events, without transformation.

## Classes
- Bronze.POSEvent (main persistent class)

## Interfaces (INGRESA)
Input: JSON/CSV from Inbound Service
Schema: See ../../../docs/API_SPEC.md#inbound

## Interfaces (SALE)
Output: Read by Silver.Normalizer (only via SQL queries, no object refs)
Query contract: SELECT * FROM Bronze.POSEvent WHERE receivedAt > ? AND loadError IS NULL

## Dependencies
- None (foundational layer)

## Tests
- tests/objectscript/test_bronze.script

## Status
✓ Sprint 1 deliverable

## Last Updated
2026-05-13 by Copilot-Agent-1
```

**Función:** evita que los agentes generen dependencias circulares y confusiones sobre responsabilidades.

---

## 2. Estrategia de branching (Git)

### 2.1 Ramas principales

```
main/
├── develop (rama de integración semanal)
└── feature/
    ├── feature/bronze-model (Agent 1)
    ├── feature/silver-normalizer (Agent 2)
    ├── feature/gold-aggregation (Agent 3)
    ├── feature/api-endpoints
    └── feature/react-ui
```

### 2.2 Reglas de branching

1. **Cada agente Copilot trabaja en su propia rama `feature/XXXX`**
   - Agent 1: `feature/bronze-model` + `feature/inbound-service`
   - Agent 2: `feature/silver-normalizer` + `feature/pipeline-bpl`
   - Agent 3: `feature/gold-calculation` + `feature/decision-engine`

2. **Nombres de rama descriptivos:**
   ```
   feature/{sprint}-{component}-{description}
   
   Ejemplos:
   feature/s1-bronze-pos-event
   feature/s2-silver-normalizer
   feature/s3-gold-calculator
   feature/s4-react-ui-pending-actions
   ```

3. **NO hacer commits a `main` directamente**
   - Siempre: feature branch → PR → code review → merge a `develop`
   - Semanalmente: `develop` → PR → merge a `main` (release)

4. **No compartir ramas entre agentes**
   - Si dos agentes tocan el mismo archivo, resolver ANTES de empezar (definir responsable en este documento)

### 2.3 Arquivos "que no se tocan en paralelo"

Estos archivos son críticos y solo UNO toca por sprint:

```
config.yml                          ← Agent "Config Master" (semana 1)
Config/Constants.cls                ← Agent "Config Master" (semana 1)
Config/GlobalConfig.cls             ← Agent "Config Master" (semana 1)
.github/workflows/merge-check.yml   ← Human only (CI)
```

Todos los demás archivos pueden tocarse en paralelo si respetan las interfaces del módulo.

---

## 3. Asignación de agentes por sprint

### 3.1 Sprint 1 — Setup + Data Model (5 días)

| Agente | Responsabilidad | Rama | Entregables | Dependencias |
|--------|---|---|---|---|
| **Agent-1** (Copilot A) | Bronze, Inbound Service, test suite | `feature/s1-bronze-model` | Bronze.POSEvent, POSService.cls, test_bronze.script | Ninguna |
| **Agent-2** (Copilot B) | Master Data (SKU, Store, Category, Budget) | `feature/s1-masters` | MD.SKU, MD.Store, MD.Category, MD.SalesBudget, mock_loader.py | Ninguna |
| **Agent-3** (Copilot C) | Config + índices + test data | `feature/s1-config` | Config/Constants.cls, data/*.csv, load_classes.sh, mock_data_loader.py | Depende de Agent-1, Agent-2 |

**Timeline:**
- Día 1-2: Agent-1 + Agent-2 en paralelo (sin dependencias)
- Día 3: Agent-3 integra resultados de Agent-1 y Agent-2
- Día 4: merge a develop, primer test end-to-end
- Día 5: documentación + ajustes

**Merge order:** Agent-1 → Agent-2 → Agent-3 (semanal a main)

---

### 3.2 Sprint 2 — Ingesta + Silver (5 días) ← MVP Parcial

| Agente | Responsabilidad | Rama | Entregables | Dependencias |
|---|---|---|---|---|
| **Agent-1** | Silver.SaleLine, validación | `feature/s2-silver-model` | Silver.SaleLine.cls, test_silver.script | Depende: Bronze (S1) ✓, Masters (S1) ✓ |
| **Agent-2** | BPL Pipeline, orchestration | `feature/s2-pipeline-bpl` | Pipeline/SalesProcess.bpl, Pipeline/SalesProcess.cls | Depende: Bronze (S1) ✓, Silver (S2 Agent-1) |
| **Agent-3** | Normalizer (Bronze → Silver), transform logic | `feature/s2-silver-normalizer` | Silver/Normalizer.cls, test_e2e_ingesta.script | Depende: Bronze (S1) ✓, Silver (S2 Agent-1) |

**Timeline:**
- Día 1: Agent-1 modela Silver (sin dependencias de BPL)
- Día 1-2: Agent-3 trabaja en Normalizer (usa Silver.SaleLine de Agent-1 cuando merge)
- Día 2-3: Agent-2 construye BPL (usa Silver de Agent-1)
- Día 4: todos merge a develop en orden: Agent-1 → Agent-3 → Agent-2
- Día 5: integración + test de 100 boletas

**Merge order:** Agent-1 (Silver) → Agent-3 (Normalizer) → Agent-2 (BPL)

**Blocking rule:** Agent-2 no mergea hasta que Silver y Normalizer estén en develop

---

### 3.3 Sprint 3 — Gold + Rules + MVP Completo (5 días) ← MVP

| Agente | Responsabilidad | Rama | Entregables | Dependencias |
|---|---|---|---|---|
| **Agent-1** | Gold.CategoryPace, aggregation logic | `feature/s3-gold-model` | Gold/CategoryPace.cls, Gold/GoldCalculator.cls, test_gold.script | Depende: Silver (S2) ✓ |
| **Agent-2** | Business Rules Engine, evaluator | `feature/s3-rules-engine` | Rules/ThresholdRule.cls, Rules/RuleEvaluator.cls | Depende: Gold (S3 Agent-1) |
| **Agent-3** | API REST endpoints + test | `feature/s3-api-endpoints` | API/UIController.cls, test_api.script, endpoints documentados | Depende: Gold (S3 Agent-1), Rules (S3 Agent-2) |

**Timeline:**
- Día 1-2: Agent-1 modela Gold + agregaciones
- Día 2: Agent-2 empieza Rules (puede adelantar sin Gold, solo actualiza después)
- Día 3: Agent-3 empieza API (igual, puede adelantar)
- Día 4: merge a develop en orden: Agent-1 → Agent-2 → Agent-3
- Día 5: integration test de 500 boletas → 10+ recomendaciones

**Merge order:** Agent-1 (Gold) → Agent-2 (Rules) → Agent-3 (API)

---

### 3.4 Sprint 4 — UI + Feedback (5 días)

| Agente | Responsabilidad | Rama | Entregables | Dependencias |
|---|---|---|---|---|
| **Agent-1** | React setup, components (Pending, Dashboard, History) | `feature/s4-react-components` | React project, 3 components, Tailwind config | Depende: API de S3 ✓ |
| **Agent-2** | REST client, state management, routing | `feature/s4-react-services` | api.js (axios client), routing, auth stub | Depende: API de S3 ✓ |
| **Agent-3** | Tests, Slack webhook integration, responsiveness | `feature/s4-integration-tests` | Cypress tests, Slack notifier, mobile fixes | Depende: Components (S4 Agent-1), Services (S4 Agent-2) |

**Timeline:**
- Día 1-2: Agent-1 construye componentes (puede hacer stubs de API calls)
- Día 1-2: Agent-2 construye cliente REST (puede mock responses)
- Día 3-4: Agent-3 integra tests (usa resultados de Agent-1 + Agent-2)
- Día 4: merge a develop
- Día 5: integración UI + backend

**Merge order:** Agent-1 (Components) + Agent-2 (Services) en paralelo, luego Agent-3

---

### 3.5 Sprint 5 — Hardening (4 días)

| Agente | Responsabilidad | Rama | Entregables | Dependencias |
|---|---|---|---|---|
| **Agent-1** | Logging, health checks, observability | `feature/s5-logging` | logging setup, metrics, health endpoint | Depende: Core (S3) ✓ |
| **Agent-2** | Retry logic, idempotency, deduplication | `feature/s5-resilience` | retry handler, hash dedup, transaction safety | Depende: Inbound (S2) ✓, Pipeline (S2) ✓ |
| **Agent-3** | Runbook, troubleshooting, load test | `feature/s5-ops-docs` | RUNBOOK.md, load test script, dashboards | Depende: Logging (S5 Agent-1), Resilience (S5 Agent-2) |

**Merge order:** Agent-1 + Agent-2 en paralelo, luego Agent-3

---

### 3.6 Sprint 6 — Multi-local + Demo (5 días)

| Agente | Responsabilidad | Rama | Entregables | Dependencias |
|---|---|---|---|---|
| **Agent-1** | Refactor: añadir tenant_id a todas las clases | `feature/s6-multi-tenant` | Refactored clases, migration script | Depende: TODO de S3-S5 |
| **Agent-2** | Scenario demo: script + data | `feature/s6-demo-scenario` | DEMO_SCRIPT.md, sample data (3 locales), run_demo.sh | Depende: Multi-tenant (S6 Agent-1) |
| **Agent-3** | Presentación técnica, handover docs | `feature/s6-handover` | HANDOVER.md, INSTALLATION.md, PRESENTATION.md | Depende: Todo completado |

**Merge order:** Agent-1 → Agent-2 → Agent-3

---

## 4. Convenciones de código (para evitar conflictos)

### 4.1 Naming conventions (ObjectScript)

```objectscript
// Clases por capa
Class Bronze.POSEvent Extends %Persistent { }
Class Silver.SaleLine Extends %Persistent { }
Class Gold.CategoryPace Extends %Persistent { }
Class MD.SKU Extends %Persistent { }

// Servicios
Class Inbound.POSService Extends Ens.BusinessService { }
Class Pipeline.SalesProcess Extends Ens.BusinessProcessBPL { }
Class Decision.ActionSelector Extends %SerialObject { }

// Métodos
// - Simples: action(), calculate(), normalize()
// - Queries: findBy...(), listBy...()
// - Handlers: handleError(), onReceive()

// Privados con @
// - Private: doPersist(), doCal culate()
```

### 4.2 Estructura de métodos

```objectscript
Class Silver.Normalizer Extends %Persistent {

    /// PUBLIC METHOD: Normalizar un evento Bronze a Silver
    /// Entrada: Bronze.POSEvent ObjectId
    /// Salida: Silver.SaleLine (persistido)
    /// Throws: Exception si falla lookup de SKU o tienda
    ClassMethod normalize(pBronzeId As %String) As Silver.SaleLine {
        // Implementation
    }
    
    /// PRIVATE: lookup de SKU en maestro
    ClassMethod pLookupSKU(pGTIN As %String) As MD.SKU {
        // Implementation
    }
    
    /// PRIVATE: validar contra esquema
    ClassMethod pValidate(pLine As Silver.SaleLine) As %Status {
        // Implementation
    }
}
```

**Regla:** todo método tiene docstring con Entrada/Salida/Throws

### 4.3 Índices (no duplicar)

En cada `_MODULE_INFO.md` se listan qué índices define ese módulo. Copilot **NO crea índices** en otras capas.

Ejemplo:
```
Module: Bronze

Índices creados:
- Index sourceIdIdx On sourceId
- Index storeCodeIdx On storeCode
- Index transactionDateTimeIdx On transactionDateTime

Índices que otros módulos pueden usar:
- sourceIdIdx (Silver lo usa en búsquedas)
```

**Regla:** Silver.SaleLine **NO crea** índices sobre Bronze.POSEvent; solo los usa.

### 4.4 Imports y referencias

```objectscript
// CORRECTO: Silver importa/usa Bronze solo para lectura
Class Silver.SaleLine Extends %Persistent {
    Relationship bronzeEvent As Bronze.POSEvent [ Cardinality = one, Inverse = none ];
}

// INCORRECTO: Circular, Bronze no debe importar Silver
// Class Bronze.POSEvent { ... Reference silverLine As Silver.SaleLine }

// CORRECTO: Gold solo lee Silver vía SQL, no importa
Class Gold.CategoryPace Extends %Persistent {
    ClassMethod calculate() {
        &sql(SELECT COUNT(*) INTO cnt FROM Silver.SaleLine WHERE ...)
    }
}
```

**Regla:** flujo unidireccional: Bronze → Silver → Gold. Nada regresa atrás.

### 4.5 Queries públicas (contrato entre capas)

Cada módulo publica sus queries en `_MODULE_INFO.md`:

```markdown
## Queries Públicas (usadas por otros módulos)

### Silver → Gold
Query: SELECT * FROM Silver.SaleLine WHERE transactionDateTime > ? AND categoryCode = ?
Parámetros: startTime (timestamp), categoryCode (string)
Resultado: todas las líneas desde startTime para una categoría

### Gold → Decision Engine
Query: SELECT * FROM Gold.CategoryPace WHERE storeCode = ? AND dateOfDay = CURRENT_DATE()
Parámetros: storeCode (string)
Resultado: pace actual del día para alertas
```

**Regla:** Copilot respeta estas queries, no inventa otras.

---

## 5. Prompts específicos para cada agente por sprint

### 5.1 Sprint 1 — Agent-1 (Bronze + Inbound Service)

```
=== COPILOT PROMPT: Sprint 1 - Agent-1 (Bronze) ===

Context:
- PoC: Cumplimiento de Presupuesto en Tiempo Real
- Plataforma: InterSystems IRIS Community
- Arquitectura: Event-driven, Medallion (Bronze/Silver/Gold)
- Repositorio: iris-poc (rama: feature/s1-bronze-model)

Task:
Create the Bronze layer - raw POS events without transformation.

Component: Bronze.POSEvent
- Extends %Persistent
- Fields: 
  * sourceId (unique, PK)
  * receivedAt (timestamp, UTC)
  * transactionId, transactionDateTime, storeCode, registerNumber
  * employeeId, customerId
  * lineNumber, itemCode, itemDescription
  * quantity, quantityUOM, unitPrice, lineAmount, discount, taxCode, taxAmount, totalLineAmount
  * rawPayload (Stream for audit)
  * loadError (optional, if ingestion failed)
- Indices: sourceId (unique), storeCode, transactionDateTime
- Methods: NONE (just data container for now)

Component: Inbound.POSService
- Extends Ens.BusinessService
- Adapter: EnsLib.File.InboundAdapter (reads JSON/CSV from folder)
- Input: JSON schema from docs/API_SPEC.md#inbound-pos
- Output: Persists to Bronze.POSEvent
- Error handling: If malformed, set loadError field, log to Ens.MessageHeader
- Methods:
  * parseJSON(pPayload) - returns message object
  * persistToBronze(pMessage) - writes to Bronze.POSEvent

Tests (test_bronze.script):
- Load 100 sample boletas (from data/sample_boletas_500.json)
- Verify Bronze.POSEvent.Extent() >= 100
- Verify no loadError for valid records
- Verify all 100 sourceIds are unique
- Verify timestamps are UTC and monotonic

Deliverable checklist:
[ ] Bronze.POSEvent class compiles without errors
[ ] Inbound.POSService class compiles without errors
[ ] 100 test records loaded to Bronze
[ ] All indices functional
[ ] test_bronze.script passes
[ ] _MODULE_INFO.md documented
[ ] Commit message: "Sprint 1: Bronze layer + Inbound service"

Dependencies: NONE (foundational)

Do not:
- Add Silver or Gold layers
- Create Business Rules or Decision logic
- Modify Frontend code
- Create REST endpoints yet

Reference: objectscript/Bronze/_MODULE_INFO.md for contract details
```

### 5.2 Sprint 2 — Agent-1 (Silver Model)

```
=== COPILOT PROMPT: Sprint 2 - Agent-1 (Silver) ===

Context:
- Sprint 2 begins after Sprint 1 merged to develop
- Bronze.POSEvent exists and has 10,000+ test records
- Masters (SKU, Store, Category) exist from S1 Agent-2
- Objetivo: Silver layer (normalized + enriched)

Component: Silver.SaleLine
- Extends %Persistent
- Relationship: bronzeEventId (ref to Bronze.POSEvent, no inverse)
- Fields:
  * normalizedAt (timestamp)
  * storeCode (ref to MD.Store, also storeKeyId)
  * transactionDateTime, transactionId, lineNumber
  * sku (GTIN normalized, ref to MD.SKU, also skuKeyId)
  * quantity (normalized to baseUOM), baseUOM
  * unitPrice, lineAmount, amountAfterTax
  * categoryCode (derived from SKU), categoryKeyId
  * validationStatus (OK, WARN, ERROR)
  * validationMessage
- Indices: storeCode, sku, transactionDateTime, categoryCode
- Methods: NONE (just data container, normalization done by Silver.Normalizer)

Query Contract (for Gold later):
SELECT * FROM Silver.SaleLine WHERE transactionDateTime > ? AND categoryCode = ?

Tests (test_silver.script):
- Create 10 records manually with valid references
- Verify each line has storeKeyId, skuKeyId, categoryKeyId resolved
- Verify validationStatus is populated
- Verify indices work: query by sku, by transactionDateTime
- Verify no data loss from Bronze

Deliverable:
[ ] Silver.SaleLine compiles
[ ] Can insert 10 valid records
[ ] Indices functional
[ ] test_silver.script passes
[ ] _MODULE_INFO.md updated
[ ] Commit: "Sprint 2: Silver model with enrichment fields"

Do not:
- Write the Normalizer (that's Agent-3's job)
- Create BPL yet (Agent-2)
- Touch Bronze or Gold
```

### 5.3 Sprint 3 — Agent-1 (Gold Model + Calculator)

```
=== COPILOT PROMPT: Sprint 3 - Agent-1 (Gold) ===

Context:
- Silver has 10,000+ records from S2
- Masters have budgets loaded
- Goal: Gold layer (aggregates by time window)

Component: Gold.CategoryPace
- Extends %Persistent
- Fields:
  * storeCode, categoryCode, dateOfDay, hourOfDay
  * windowStartUTC, windowEndUTC, windowDuration (minutes)
  * transactionCount, lineItemCount, quantitySold, revenueSold
  * budgetQuantity, budgetRevenue
  * paceCompletionPct (% vs budget for the elapsed period)
  * deviationPct (negative = behind pace)
  * hoursElapsed, projectedFinalCompletionPct
  * ruleTriggeredId, ruleTriggeredAt, isOutOfPace
- Indices: (storeCode, categoryCode, dateOfDay) [composite]
- Methods: NONE

Component: Gold.GoldCalculator
- Extends %SerialObject (or utility class)
- Methods:
  * calculatePace(storeCode, categoryCode, budgetDate, currentTime) → Gold.CategoryPace
    - Sums all Silver.SaleLine for (store, category) up to currentTime
    - Reads budget from MD.SalesBudget
    - Calculates paceCompletionPct (actual qty sold / expected qty for elapsed hours)
    - Calculates deviationPct (negative if behind)
    - Calculates projectedFinalCompletionPct
  * calculateForWindow(storeCode, categoryCode, windowStartUTC, windowEndUTC) → Gold.CategoryPace
    - Aggregates Silver lines within window
  * pEvalDeviationVsBudget(sold, budget, hoursElapsed, hoursTotal) → %Numeric
    - Internal formula for pace calculation

Tests (test_gold.script):
- Create 50 Silver.SaleLine records for store GT-0145, category BEVA-GASA, date 2026-05-13
  * Spread across hours 06:00 to 18:00 (12 hours)
  * Budget: 50 units total (should be 4.2 units/hour to stay on pace)
- Call calculatePace() for various times:
  * At 10:00 (4 hours elapsed): sold 15, expected ~17 → deviationPct ≈ -11%
  * At 14:00 (8 hours elapsed): sold 35, expected ~34 → deviationPct ≈ +3%
  * At 18:00 (12 hours elapsed): sold 50 → deviationPct = 0%
- Verify Gold.CategoryPace records are created
- Verify indices work

Deliverable:
[ ] Gold.CategoryPace compiles
[ ] Gold.GoldCalculator compiles, all methods work
[ ] 50 test records produce 3+ Gold aggregates
[ ] Pace calculations validated against manual math
[ ] test_gold.script passes
[ ] _MODULE_INFO.md updated with pace formula
[ ] Commit: "Sprint 3: Gold aggregation layer + pace calculator"

Do not:
- Write Rules or Decision Engine (Agent-2, Agent-3)
- Trigger actions (that comes later)
- Touch API yet
```

### 5.4 Sprint 3 — Agent-2 (Business Rules)

```
=== COPILOT PROMPT: Sprint 3 - Agent-2 (Rules Engine) ===

Context:
- Gold.CategoryPace is being calculated
- Need Business Rules that trigger actions when deviations detected

Components: Rules.ThresholdRule + Rules.RuleEvaluator

Rules.ThresholdRule (persistent metadata):
- Extends %Persistent
- Fields: ruleId, description, enabled, ruleExpression, thresholdValue, severityLevel, windowTypeMinutes, minOccurrences
- Methods: NONE (just metadata)
- Seed data (5 rules):
  * PACE_CRITICAL: deviationPct < -25, severity=HIGH, window=60min
  * PACE_SUSTAINED: deviationPct < -10 for 3 consecutive 1-hour windows, severity=MEDIUM
  * STOCKOUT_INFERRED: quantitySold=0 for 2 hours when store is open, severity=HIGH
  * CATCHUP_WINDOW: deviationPct crosses 0 (negative to positive), severity=INFO
  * OOS_TOP_SKU: stockout in top-20 SKU by volume, severity=HIGH

Rules.RuleEvaluator:
- Extends %SerialObject (utility)
- Methods:
  * evaluateAllRules(pGoldRecord As Gold.CategoryPace) → List of triggered rule IDs
    - Loop through all enabled Rules.ThresholdRule
    - Evaluate pGoldRecord against each rule
    - Return list of matching ruleIds
  * evaluateRule(pGoldRecord, pRuleId) → %Boolean
    - Evaluate one rule against one Gold record
    - Handle expressions like: deviationPct < -25, quantitySold = 0, etc.
  * pEvaluateExpression(pExpression, pGoldRecord) → %Boolean
    - Helper to evaluate expressions like "deviationPct < -25"

Seed data (SQL INSERT or ObjectScript):
INSERT INTO Rules.ThresholdRule (ruleId, description, enabled, ruleExpression, thresholdValue, severityLevel, windowTypeMinutes) 
VALUES ('PACE_CRITICAL', 'Pace desvío crítico', 1, 'deviationPct < -25', -25, 'HIGH', 60)
...

Tests (test_rules.script - part of test_e2e.script):
- Create 10 Gold.CategoryPace records with various deviations:
  * Some with deviationPct = -30 (should trigger PACE_CRITICAL)
  * Some with deviationPct = -5 (should NOT trigger PACE_CRITICAL)
  * Some with quantitySold = 0 (should trigger STOCKOUT_INFERRED)
- Call evaluateAllRules() on each
- Verify triggered rules match expected set
- Verify disabled rules do not trigger

Deliverable:
[ ] Rules.ThresholdRule compiles, 5 rules seeded
[ ] Rules.RuleEvaluator compiles, all methods work
[ ] Manual tests pass (5+ rules triggered correctly)
[ ] test_e2e.script includes rule evaluation
[ ] _MODULE_INFO.md updated with rule list
[ ] Commit: "Sprint 3: Business rules engine + 5 threshold rules"

Do not:
- Implement Decision Engine (Agent-3 will map rules to actions)
- Create API endpoints yet
- Modify Silver or Bronze
```

### 5.5 Sprint 3 — Agent-3 (REST API)

```
=== COPILOT PROMPT: Sprint 3 - Agent-3 (API Endpoints) ===

Context:
- Gold.CategoryPace calculated continuously
- Rules.RuleEvaluator can detect deviations
- Decision.ActionSelector will map rules to actions (placeholder for now)
- Need REST API to expose current state to UI

Component: API.UIController (extends %CSP.REST)

Routes to implement:

1. GET /api/v1/stores/{storeCode}/categories/{categoryCode}/pace
   - Returns: current Gold.CategoryPace for (store, category) today
   - Query: SELECT * FROM Gold.CategoryPace WHERE storeCode=? AND categoryCode=? AND dateOfDay=CURRENT_DATE() AND hourOfDay=CURRENT_HOUR()
   - Response: { storeCode, categoryCode, paceCompletionPct, deviationPct, quantitySold, budgetQuantity, isOutOfPace, ruleTriggeredId, ... }

2. GET /api/v1/recommendations/pending?storeCode={code}
   - Returns: list of Ops.Recommendation where feedbackStatus='PENDING'
   - Response: [ { recommendationId, categoryCode, actionName, parameters, recommendedAt, ... }, ... ]

3. POST /api/v1/recommendations/{recommendationId}/feedback
   - Payload: { status: 'ACCEPTED'|'REJECTED'|'MODIFIED', modifications: {...} }
   - Updates: Ops.Recommendation.feedbackStatus, feedbackReceivedAt, feedbackModifications
   - Returns: { success: true, updatedRecommendation: {...} }

4. GET /api/v1/dashboard/store/{storeCode}
   - Returns: summary for store today (all categories)
   - Response: { storeCode, date, categories: [ { categoryCode, paceCompletionPct, ... }, ... ], totalDayProgress }

5. GET /api/v1/health
   - Returns: { status: "ok", timestamp, version }

Error handling:
- 404 if store/category not found
- 400 if invalid parameters
- 500 if DB error (with message, not stack trace)
- Log all requests to Ens.MessageHeader

Methods (in API.UIController):
- GET(pUrl, pDocObj) [override] - dispatches to private handlers
- pGetPace(storeCode, categoryCode) → %DynamicObject
- pGetRecommendationsPending(storeCode) → %DynamicArray
- pPostFeedback(recommendationId, payload) → %DynamicObject
- pGetDashboard(storeCode) → %DynamicObject
- pHealthCheck() → %DynamicObject

Tests (test_api.script):
- Load test data into Gold, Ops.Recommendation
- Mock HTTP calls to each endpoint
- Verify responses match schema
- Verify error cases (404, 400, 500) return proper JSON

Deliverable:
[ ] API.UIController compiles
[ ] All 5 endpoints respond with valid JSON
[ ] Proper error handling (400, 404, 500)
[ ] test_api.script passes
[ ] API_SPEC.md updated with full route definitions
[ ] Commit: "Sprint 3: REST API endpoints + responses"

Do not:
- Modify Gold, Rules, or Silver
- Implement authentication yet (add later in S5)
- Return HTML (only JSON)

Reference: docs/API_SPEC.md (to be created by Agent-3)
```

---

## 6. Workflow de integración (evitar conflictos)

### 6.1 Checklist pre-merge

Antes de mergear feature branch a develop:

```
BRANCH: feature/s{N}-{component}

PRE-MERGE CHECKLIST:
[ ] Code compiles without errors
[ ] No console/debug logs left
[ ] All methods have docstrings (Entrada/Salida/Throws)
[ ] Tests pass: ./scripts/run_tests.sh {component}
[ ] No hardcoded values (use Config/Constants.cls)
[ ] Respeta _MODULE_INFO.md dependencies
[ ] No circular imports
[ ] Indices defined only in own module
[ ] Public queries documented in _MODULE_INFO.md
[ ] SQL uses parameterized queries (no concatenation)
[ ] Commit message: "Sprint {N}: {component} - {brief description}"
[ ] Create PR with description of changes
[ ] Self-review: "Does this break any other module?"

MERGE STRATEGY:
[ ] Squash commits into single logical commit
[ ] Merge: feature/s{N}-{component} → develop
[ ] Delete feature branch after merge
[ ] Run full test suite: ./scripts/run_tests.sh all
[ ] Verify no regressions on other components
```

### 6.2 Resolución de conflictos

Si dos agentes tocan el mismo archivo (debería ser raro):

```
Prioridad de resolución:

1. EVITAR primero: 
   - Comunicar en Slack antes de empezar
   - Si posible, asignar archivo a un solo agente

2. Si conflicto ocurre:
   - Human revisa el conflicto
   - Entiende intención de ambos agentes
   - Resuelve en develop branch
   - Documenta en PR por qué se resolvió así
   - NO merge feature branch hasta resolver en develop

Ejemplo conflicto:
- Agent-1 modifica Silver.SaleLine.cls (añade campo X)
- Agent-2 modifica Silver.SaleLine.cls (añade validación)
- Solución: merge Agent-1 a develop primero, Agent-2 rebase y resuelve contra develop

Command:
git fetch origin develop
git rebase origin/develop feature/s2-silver-enhancement
# Resolve conflicts
git add Silver.SaleLine.cls
git rebase --continue
git push -f
```

### 6.3 Testing entre sprints

Después de cada merge a develop:

```bash
# Después de merge Agent-X
./scripts/run_tests.sh all

# Expect:
# ✓ test_bronze.script
# ✓ test_silver.script  
# ✓ test_gold.script
# ✓ test_api.script
# ✓ test_e2e.script

# Si falla alguno, revert merge y investigar:
git revert HEAD
# Fix issue
# Re-merge
```

---

## 7. Archivos de configuración (una fuente de verdad)

### 7.1 Config/Constants.cls (NO lo toquen en paralelo)

```objectscript
Class Config.Constants
{
    // Versión
    ClassParameter VERSION = "0.1.0-S1";
    
    // Umbrales de reglas (parametrizables)
    ClassParameter PACE_CRITICAL_THRESHOLD = -25;
    ClassParameter PACE_SUSTAINED_THRESHOLD = -10;
    ClassParameter SUSTAINED_COUNT = 3;
    
    // Windows
    ClassParameter GOLD_WINDOW_MINUTES = 15;
    ClassParameter RULE_EVAL_INTERVAL_MINUTES = 15;
    ClassParameter BUDGET_LOAD_TIME = "06:00";
    
    // Moneda default
    ClassParameter DEFAULT_CURRENCY = "COP";
    
    // Logging
    ClassParameter LOG_LEVEL = "DEBUG";
    ClassParameter LOG_FORMAT = "JSON";
}
```

**Regla:** Copilot lee de Config.Constants, no hardcodea valores.

### 7.2 .github/workflows/merge-check.yml

```yaml
name: Merge Check

on:
  pull_request:
    branches: [ develop, main ]

jobs:
  compile:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Compile ObjectScript
        run: ./scripts/load_classes.sh
      - name: Run tests
        run: ./scripts/run_tests.sh all
      - name: Check for conflicts
        run: grep -r "^<<<<<<< HEAD" objectscript/ && exit 1 || echo "No merge conflicts"
```

**Función:** CI/CD previene merges con errores de compilación o tests fallidos.

---

## 8. Checklist semanal de integración

Al fin de cada semana (viernes):

```
SPRINT X WEEKLY INTEGRATION

[ ] Todos los agentes han mergeado sus ramas a develop
[ ] ./scripts/run_tests.sh all PASSES
[ ] No warnings de compilación
[ ] Verificar que no hay ramas stale (cleanup)

PREPARE RELEASE:
[ ] Create PR: develop → main
[ ] Documentation updated (CHANGELOG.md)
[ ] Tag commit: v0.1.0-s{N}
[ ] Merge to main
[ ] Create release notes

NEXT WEEK KICKOFF:
[ ] Update COPILOT_PROMPTS.md for Sprint {N+1}
[ ] Re-assign agents (avoid burnout)
[ ] Kickoff meeting: 15 min
```

---

## 9. Dependencias y bloqueos (comunicación)

### 9.1 Matriz de dependencias

```
SPRINT 2 Dependency Graph:

Agent-1 (Silver)
  ↓ reads
Agent-2 (BPL) ← BLOCKED until Agent-1 merged
  ↓ uses
Agent-3 (Normalizer) ← CAN START in parallel, waits for Silver on day 2

RULE: No agent espera más de 2 días. Si blocked > 2d, escalar.
```

### 9.2 Slack notifications (automation)

```
#iris-poc Slack channel

Bot posts daily:
- 09:00: "Sprint {N} standups in 5 min. Agents report status."
- 17:00: "End of day. {Agent-X} merged to develop. All tests passed."
- 14:00 (if issue): "@team Merge conflict in Silver.SaleLine.cls. Resolve in 1 hour."

Agent commits to feature branch:
- Auto-comment on PR: "✓ Compiles, ✓ Tests passed ({N} test cases)"

When PR ready to merge:
- Human reviews in 30 min
- Merge with message: "Sprint {N}: {component} - {summary}"
```

---

## 10. Documentación obligatoria por commit

Cada commit debe tener:

```
Commit message format:
Sprint {N}: {Component} - {Brief description}

Body (if complex):
- What was added/changed
- Why (reference to requirements)
- Any breaking changes? NO (for S1-S6)
- Tests added: test_{component}.script

Example:
Sprint 1: Bronze layer + Inbound service

- Created Bronze.POSEvent persistent class with 12 fields
- Implemented Inbound.POSService (File adapter)
- Added test_bronze.script with 100 sample records
- Seeded config.yml with inbound path

Tests: test_bronze.script passes (100/100 records loaded)
```

---

## 11. Matriz de responsabilidades

| Componente | Sprint | Agent | Rama | Status |
|---|---|---|---|---|
| Bronze | S1 | Agent-1 | feature/s1-bronze-model | To start |
| Masters | S1 | Agent-2 | feature/s1-masters | To start |
| Config | S1 | Agent-3 | feature/s1-config | Blocked until S1 Agent-1,2 done |
| Silver | S2 | Agent-1 | feature/s2-silver-model | Depends S1 Agent-1 ✓ |
| Normalizer | S2 | Agent-3 | feature/s2-silver-normalizer | Depends S2 Agent-1 + S1 Agent-1 ✓ |
| BPL Pipeline | S2 | Agent-2 | feature/s2-pipeline-bpl | Depends S2 Agent-1,3 |
| Gold | S3 | Agent-1 | feature/s3-gold-model | Depends S2 Agent-1 ✓ |
| Rules | S3 | Agent-2 | feature/s3-rules-engine | Depends S3 Agent-1 |
| API | S3 | Agent-3 | feature/s3-api-endpoints | Depends S3 Agent-1,2 |
| React UI | S4 | Agent-1 | feature/s4-react-components | Depends S3 ✓ |
| Services | S4 | Agent-2 | feature/s4-react-services | Depends S3 ✓ |
| Tests | S4 | Agent-3 | feature/s4-integration-tests | Depends S4 Agent-1,2 |
| Observability | S5 | Agent-1 | feature/s5-logging | Depends S3 ✓ |
| Resilience | S5 | Agent-2 | feature/s5-resilience | Depends S2 ✓ |
| Ops Docs | S5 | Agent-3 | feature/s5-ops-docs | Depends S5 Agent-1,2 |
| Multi-tenant | S6 | Agent-1 | feature/s6-multi-tenant | Depends all S5 ✓ |
| Demo | S6 | Agent-2 | feature/s6-demo-scenario | Depends S6 Agent-1 |
| Handover | S6 | Agent-3 | feature/s6-handover | Depends all |

---

## 12. Comandos rápidos (CLI)

```bash
# Setup local (first time)
./scripts/setup_local.sh

# Load classes from objectscript/
./scripts/load_classes.sh

# Run tests for a component
./scripts/run_tests.sh bronze
./scripts/run_tests.sh silver
./scripts/run_tests.sh all

# Merge feature to develop (manual process for now)
git checkout develop
git pull origin develop
git merge feature/s{N}-{component} --squash
git commit -m "Sprint {N}: {component} - {summary}"
git push origin develop

# Clean up merged branches
git branch -d feature/s{N}-{component}
git push origin --delete feature/s{N}-{component}
```

---

## 13. Troubleshooting paralelo

| Problema | Causa | Solución |
|---|---|---|
| "Agent-2 esperando a Agent-1" | Dependency delay | Agent-2 avanza con stubs, espera merge en 1d |
| "Compilación falla después de merge" | Conflicto silencioso | Revert merge, human resolve, re-merge |
| "Test pasa local, falla en CI" | Timestamp/timezone issue | Add timezone parameter a mocks |
| "Índices duplicados" | Agent toca otro módulo | Revert, fix _MODULE_INFO.md, re-merge |
| "Circular import" | Design error | Review design, refactor, communicate |

---

## Resumen

| Aspecto | Estrategia |
|---|---|
| **Ramas** | feature/{sprint}-{component} por agente |
| **Orden merge** | Define en sprint, agentes respetan dependencias |
| **Conflictos** | Evitar primero (naming, índices), resolver en human review |
| **Testing** | Cada component tiene test_{component}.script, ejecuta en CI |
| **Documentación** | _MODULE_INFO.md por módulo, docstrings en métodos |
| **Comunicación** | Slack daily, PR reviews en 30 min, blockers escalados |
| **Configuración** | Una fuente de verdad (Config/Constants.cls) |
| **Velocidad** | 70% código por Copilot, 30% humano (review + ajuste) |

Este es el blueprint para que 2-3 agentes Copilot trabajen en paralelo sin pisarse.

