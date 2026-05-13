# Arquitectura Técnica — PoC Cumplimiento de Presupuesto en Tiempo Real sobre IRIS
## Documento para Equipo de Desarrollo — Plan de Sprints + Entregables

---

**Documento:** Especificación técnica y plan de ejecución
**Para:** Equipo de desarrollo (1 developer + GitHub Copilot + Claude Code)
**Fecha:** Mayo 2026
**Versión:** 1.0 — Borrador técnico

---

## Tabla de contenidos

1. Visión técnica general
2. Arquitectura de capas
3. Modelos de datos estándar (agnóstico de vendor)
4. Flujos de datos y procesos
5. Componentes IRIS
6. Opciones de integración POS
7. Plan de sprints (8 semanas, MVP en S2-S3)
8. Entregables por sprint
9. Stack de herramientas de desarrollo
10. Consideraciones de IA para desarrollo
11. Checklist de implementación

---

## 1. Visión técnica general

### 1.1 Objetivos de arquitectura

- **Agnóstico de vendor:** usar esquemas estándar de industria (no amarrados a SAP, Oracle, etc.)
- **Event-driven:** flujo basado en eventos POS sin latencia excesiva.
- **Stateless pero persistente:** cada boleta es procesada independientemente, pero el estado agregado se persiste.
- **Escalable a multi-local:** la PoC es single-local, pero la arquitectura debe escalar sin refactoring.
- **Debuggable:** toda transacción y decisión queda auditada y replayable.

### 1.2 Decisiones clave

| Decisión | Fundamento |
|----------|-----------|
| Patrón Medallion (Bronze/Silver/Gold) | Estándar Databricks, reconocible por cualquier data engineer |
| JSON para intercambio de datos | Agnóstico, independiente de SAP/Oracle |
| BPL para orquestación | Nativo IRIS, visual, versionable |
| Business Rules para decisiones | Editables sin desarrollo |
| Rest API para UI | Desacoplamiento frontend-backend |

---

## 2. Arquitectura de capas

### 2.1 Diagrama de capas

```
┌─────────────────────────────────────────────────────────────────┐
│ TIER 1: INGESTA (Real-time + Batch)                             │
│ ┌─────────────────────────┐  ┌──────────────────────────────┐   │
│ │ POS Event Stream        │  │ Budget Load (Daily Batch)    │   │
│ │ (Kafka/API/File Polling)│  │ (File Upload / API Import)   │   │
│ └────────────┬────────────┘  └──────────────┬───────────────┘   │
│              │                              │                   │
└──────────────┼──────────────────────────────┼───────────────────┘
               │                              │
┌──────────────▼──────────────────────────────▼───────────────────┐
│ TIER 2: SERVICIOS DE INGESTA (IRIS Inbound Adapters)            │
│ ┌─────────────────────────┐  ┌──────────────────────────────┐   │
│ │ POSEventService         │  │ BudgetImportService         │   │
│ │ (Kafka / REST / File)   │  │ (REST / CSV Upload)         │   │
│ │ Emite: POSEvent         │  │ Emite: BudgetUpdate         │   │
│ └────────────┬────────────┘  └──────────────┬───────────────┘   │
│              │                              │                   │
└──────────────┼──────────────────────────────┼───────────────────┘
               │                              │
┌──────────────▼──────────────────────────────▼───────────────────┐
│ TIER 3: ORQUESTACIÓN (BPL + Enriquecimiento)                    │
│ ┌──────────────────────────────────────────────────────────┐    │
│ │ POSProcessingBPL                                         │    │
│ │ 1. Valida evento (schema, campos requeridos)            │    │
│ │ 2. Persiste en Bronze (raw)                             │    │
│ │ 3. Enriquece con maestros (SKU, Store, Budget)          │    │
│ │ 4. Persiste en Silver (normalized)                      │    │
│ │ 5. Agrega en Gold (rolling windows)                     │    │
│ │ 6. Evalúa reglas vía Decision Engine                    │    │
│ │ 7. Si regla dispara: emite Recommendation               │    │
│ └──────────┬───────────────────────────────────────────────┘    │
└───────────┼────────────────────────────────────────────────────┘
            │
┌───────────▼─────────────────────────────────────────────────────┐
│ TIER 4: PERSISTENCIA (IRIS Database - Medallion Pattern)        │
│ ┌─────────────────────────┐  ┌──────────────────────────────┐   │
│ │ Bronze (Raw Events)     │  │ Master Data                  │   │
│ │ - POSEvent raw          │  │ - SKU                        │   │
│ │ - BudgetUpdate raw      │  │ - Store                      │   │
│ │                         │  │ - Category                   │   │
│ └─────────────────────────┘  └──────────────────────────────┘   │
│ ┌─────────────────────────┐  ┌──────────────────────────────┐   │
│ │ Silver (Normalized)     │  │ Configuration                │   │
│ │ - Sale (normalized)     │  │ - Rules                      │   │
│ │ - Budget (normalized)   │  │ - Actions Catalog            │   │
│ │                         │  │ - Thresholds                 │   │
│ └─────────────────────────┘  └──────────────────────────────┘   │
│ ┌─────────────────────────┐  ┌──────────────────────────────┐   │
│ │ Gold (Analytics-Ready)  │  │ Operational                  │   │
│ │ - CategoryPace (hourly) │  │ - Recommendation (out)       │   │
│ │ - CategoryPace (daily)  │  │ - Feedback (in)              │   │
│ │ - CategoryPace (weekly) │  │ - Audit Log                  │   │
│ └─────────────────────────┘  └──────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
               │
┌──────────────▼─────────────────────────────────────────────────┐
│ TIER 5: OUTBOUND (API + Notifications)                         │
│ ┌──────────────────────────┐  ┌──────────────────────────────┐ │
│ │ RecommendationService    │  │ NotificationService         │ │
│ │ (REST API para UI)       │  │ (Email/Slack/Push)         │ │
│ └──────────────────────────┘  └──────────────────────────────┘ │
│ ┌──────────────────────────┐  ┌──────────────────────────────┐ │
│ │ Dashboard API            │  │ Audit Log API               │ │
│ │ (Métricas + Estado)      │  │ (Trazabilidad)              │ │
│ └──────────────────────────┘  └──────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────────────────┐
│ TIER 6: UI (Frontend)                                            │
│ ┌──────────────────────────┐  ┌──────────────────────────────┐ │
│ │ Store Manager UI         │  │ Supervisor Dashboard         │ │
│ │ (Mobile-first, React)    │  │ (Desktop, React/Vue)        │ │
│ └──────────────────────────┘  └──────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

### 2.2 Tecnologías por capa

| Capa | Componente | Tecnología | Responsabilidad |
|------|-----------|-----------|-----------------|
| 1 | Ingesta POS | Kafka / REST API / File polling | Traer boletas |
| 1 | Ingesta Budget | File upload / REST API | Traer presupuesto diario |
| 2 | POS Service | IRIS Inbound Adapter (Kafka/REST/File) | Parse, emit POSEvent |
| 2 | Budget Service | IRIS Inbound Adapter (REST/File) | Parse, emit BudgetUpdate |
| 3 | Orquestación | IRIS BPL (`POSProcessingBPL`) | Flujo: ingest → enrich → aggregate → decide |
| 3 | Decisión | IRIS Business Rules + Lookup Tables | Evalúa desvío, selecciona acción |
| 4 | Bronze | IRIS %Persistent + SQL | Raw event storage |
| 4 | Silver | IRIS %Persistent + SQL | Normalized, enriched |
| 4 | Gold | IRIS SQL Views + materialized tables | Agregados y pace |
| 4 | Masters | IRIS %Persistent + SQL | SKU, Store, Category, Budget |
| 4 | Config | IRIS %Persistent + SQL | Rules, actions, thresholds |
| 5 | Outbound | IRIS Business Operation (REST) | Push recommendations, metrics |
| 5 | Notifications | IRIS Notification adapter (SMTP/Webhook) | Email, Slack, push |
| 6 | UI | React / Vue (lightweight) | Dashboards, action interface |

---

## 3. Modelos de datos estándar (agnóstico de vendor)

### 3.1 Eventos POS — Entrada

**Formato estándar: JSON, compatible con NRF (National Retail Federation)**

```json
{
  "event_type": "sale",
  "event_timestamp": "2026-05-13T14:03:45Z",
  "event_id": "POS-20260513-LOCAL001-TRX000123",
  "source_system": "POS_SYSTEM_NAME",
  "store": {
    "store_code": "LOCAL001",
    "store_name": "Éxito Centro",
    "region": "Bogotá"
  },
  "transaction": {
    "transaction_id": "TRX000123",
    "transaction_timestamp": "2026-05-13T14:03:00Z",
    "cashier_id": "CASH001",
    "terminal_id": "TERM005"
  },
  "line_items": [
    {
      "line_number": 1,
      "sku": {
        "vendor_sku": "VENDOR-SKU-123",  // Código del proveedor POS
        "unit_of_measure": "EA",          // Estándar: EA, CS, KG, L, etc.
        "description": "Agua Mineral Con Gas 500ml"
      },
      "quantity": 3,
      "unit_price": 2500,
      "line_total": 7500,
      "currency": "COP"
    }
  ],
  "transaction_totals": {
    "subtotal": 7500,
    "tax": 1200,
    "total": 8700,
    "currency": "COP"
  },
  "payment_method": "CASH",
  "metadata": {
    "receipt_number": "RCP-123456",
    "loyalty_program_id": null
  }
}
```

**Mapeo agnóstico:** El Inbound Service toma el `vendor_sku` y lo mapea a un `internal_sku` mediante tabla de lookup.

### 3.2 Presupuesto de Ventas — Carga diaria

**Formato estándar: CSV o JSON, simple y agnóstico**

```json
{
  "budget_import_id": "BUDGET-20260513-001",
  "import_date": "2026-05-13",
  "budget_effective_date": "2026-05-13",
  "store_code": "LOCAL001",
  "budget_lines": [
    {
      "sku": "INTERNAL-SKU-WATER-500ML",
      "category_code": "BEVERAGES_CARBONATED",
      "daily_target_units": 50,
      "daily_target_revenue": 125000,
      "currency": "COP",
      "notes": "Meta diaria para agua con gas"
    },
    {
      "sku": "INTERNAL-SKU-OIL-SUNFLOWER-1L",
      "category_code": "OILS_AND_CONDIMENTS",
      "daily_target_units": 20,
      "daily_target_revenue": 180000,
      "currency": "COP",
      "notes": "Aceite girasol 1L"
    }
  ]
}
```

**Carga:** Via REST API POST o CSV file upload diario (default: 7:00 AM local time).

### 3.3 Maestro de SKU (agnóstico)

```objectscript
Class MD.SKU Extends (%Persistent) {
  Property internal_sku As %String [ Required, Unique ];
  Property vendor_sku As %String;  // Código del POS del cliente
  Property description As %String;
  Property category_code As %String;
  Property unit_of_measure As %String;  // EA, CS, KG, L, etc.
  Property active As %Boolean [ InitialValue = 1 ];
  Property created_date As %TimeStamp [ InitialValue = {NOW()} ];
  Property metadata As %JSON.Adaptive;  // Para extensiones
}
```

### 3.4 Maestro de Locales

```objectscript
Class MD.Store Extends (%Persistent) {
  Property store_code As %String [ Required, Unique ];
  Property store_name As %String;
  Property region As %String;
  Property district As %String;
  Property active As %Boolean [ InitialValue = 1 ];
  Property created_date As %TimeStamp [ InitialValue = {NOW()} ];
}
```

### 3.5 Presupuesto (tabla de datos)

```objectscript
Class MD.SalesBudget Extends (%Persistent) {
  Property budget_date As %Date [ Required ];
  Property store_code As %String [ Required ];
  Property internal_sku As %String [ Required ];
  Property category_code As %String;
  Property daily_target_units As %Integer;
  Property daily_target_revenue As %Numeric;
  Property currency As %String;
  Property created_date As %TimeStamp [ InitialValue = {NOW()} ];
  
  Index DateStoreSkuIdx On (budget_date, store_code, internal_sku) [ Unique ];
}
```

### 3.6 Evento normalizado (Silver)

```objectscript
Class Silver.Sale Extends (%Persistent) {
  Property sale_id As %String [ Required, Unique ];
  Property event_timestamp As %TimeStamp;
  Property transaction_timestamp As %TimeStamp;
  Property store_code As %String;
  Property internal_sku As %String;
  Property quantity As %Integer;
  Property unit_price As %Numeric;
  Property line_total As %Numeric;
  Property currency As %String;
  Property category_code As %String;  // Joined from SKU master
  Property sale_date As %Date;
  Property created_at As %TimeStamp [ InitialValue = {NOW()} ];
}
```

### 3.7 Agregado diario (Gold)

```objectscript
Class Gold.CategoryPace Extends (%Persistent) {
  Property pace_id As %String [ Required, Unique ];
  Property pace_date As %Date [ Required ];
  Property pace_hour As %Integer;  // 0-23, null = daily aggregate
  Property store_code As %String [ Required ];
  Property category_code As %String [ Required ];
  Property units_sold As %Integer;
  Property revenue_sold As %Numeric;
  Property units_budget As %Integer;
  Property revenue_budget As %Numeric;
  Property units_cumulative As %Integer;
  Property revenue_cumulative As %Numeric;
  Property pct_pace_units As %Numeric;  // 0-100 (%)
  Property pct_pace_revenue As %Numeric;
  Property variance_units As %Integer;  // budget - sold (puede ser negativo)
  Property variance_revenue As %Numeric;
  Property last_updated As %TimeStamp [ InitialValue = {NOW()} ];
  
  Index DateStoreCategoryIdx On (pace_date, store_code, category_code);
}
```

### 3.8 Recomendación (outbound)

```objectscript
Class Ops.Recommendation Extends (%Persistent) {
  Property recommendation_id As %String [ Required, Unique ];
  Property triggered_at As %TimeStamp;
  Property store_code As %String;
  Property category_code As %String;
  Property rule_fired As %String;  // Ej. "PACE_NEGATIVE_CRITICAL"
  Property action_code As %String;  // Ej. "MOVE_PALLET_TO_ENTRANCE"
  Property action_description As %String;
  Property action_parameters As %JSON.Adaptive;
  Property status As %String;  // "PENDING", "ACCEPTED", "REJECTED", "MODIFIED"
  Property accepted_by As %String;
  Property accepted_at As %TimeStamp;
  Property execution_status As %String;  // "NOT_EXECUTED", "EXECUTED", "PARTIAL"
  Property executed_at As %TimeStamp;
  Property effectiveness_score As %Numeric;  // 0-100, medido post-ejecución
  Property created_at As %TimeStamp [ InitialValue = {NOW()} ];
}
```

---

## 4. Flujos de datos y procesos

### 4.1 Flujo de una boleta POS (end-to-end)

```
[POS System emits JSON event] 
      ↓
[Kafka / REST API / File]
      ↓
[POSEventService (Inbound Adapter)]
      ↓ (emits POSEvent message)
[POSProcessingBPL]
      │
      ├─→ Validate schema
      ├─→ Persist to Bronze (raw JSON)
      ├─→ Lookup SKU mapping (vendor_sku → internal_sku)
      ├─→ Enrich with category
      ├─→ Persist to Silver (normalized Sale)
      ├─→ Increment Gold.CategoryPace (hour + day windows)
      │
      └─→ [Decision Engine evaluates Rules]
          │
          ├─ IF variance_units < threshold
          │     ├─→ Emit Recommendation message
          │     ├─→ Persist to Ops.Recommendation
          │     └─→ Send notification (email/push)
          │
          └─ ELSE (pace is OK)
                └─→ No action
```

**Tiempo total esperado:** < 5 segundos (validación + enriquecimiento + persistencia).

### 4.2 Flujo de carga diaria de presupuesto

```
[Finance system exports CSV / REST API sends JSON]
      ↓
[BudgetImportService (Inbound Adapter)]
      ↓ (emits BudgetUpdate message for each store)
[BudgetProcessingBPL]
      │
      ├─→ Parse & validate budget structure
      ├─→ Lookup store_code, internal_sku existence
      ├─→ Persist to MD.SalesBudget (replace previous day's record)
      │
      └─→ [Notification]: "Budget loaded for LOCAL001 (2026-05-13)"
```

**Frecuencia:** Once per day, default 7:00 AM local time.
**Rollback:** Previous day's budget kept until new day's load is confirmed.

### 4.3 Flujo de evaluación de reglas (cada N minutos)

```
[Scheduled Job: Every 15 minutes]
      ↓
[EvaluateRulesOperation]
      │
      ├─→ Query Gold.CategoryPace for last 60 min
      ├─→ For each (store, category):
      │     │
      │     ├─ Fetch MD.SalesBudget for today
      │     ├─ Compare actual vs pace
      │     │
      │     └─ FOR each rule in Rules.Threshold:
      │           │
      │           ├─ IF rule condition matches:
      │           │     ├─→ Select action from Catalog.Action
      │           │     ├─→ Emit Recommendation
      │           │     └─→ Send notification
      │           │
      │           └─ ELSE: no action
      │
      └─→ Log evaluation result to Audit
```

---

## 5. Componentes IRIS

### 5.1 Servicios de ingesta (Adapters)

#### POSEventService (POS Inbound)

```objectscript
Class Service.POSEventService Extends Ens.InboundAdapter {
    Parameter SETTINGS = "AdapterType,SourcePath,MessageTemplate";
    
    Property AdapterType As %String [ InitialValue = "kafka" ];  // kafka|rest|file
    Property SourcePath As %String;
    
    Method OnConnected() As %Status {
        // Conectar a Kafka/escuchar REST/poolear archivos
    }
    
    Method OnTask() As %Status {
        // Parsear boleta JSON
        // Validar schema
        // Emitir POSEvent al BPL
    }
}
```

#### BudgetImportService (Budget Inbound)

```objectscript
Class Service.BudgetImportService Extends Ens.InboundAdapter {
    Parameter SETTINGS = "ImportPath,Format,ImportSchedule";
    
    Property ImportPath As %String;  // /path/to/budget or REST endpoint
    Property Format As %String [ InitialValue = "json" ];  // json|csv
    
    Method OnTask() As %Status {
        // Descargar presupuesto (csv o json)
        // Parsear líneas
        // Emitir BudgetUpdate para cada store
    }
}
```

### 5.2 BPL (Business Process)

```objectscript
Class Process.POSProcessingBPL Extends Ens.BusinessProcessBPL {
    // Este es editable visualmente en IRIS Management Portal
    
    // Estructura visual en BPL:
    // 1. Start
    // 2. Receive POSEvent
    // 3. Call Validate() routine
    // 4. Persist to Bronze
    // 5. Call Enrich() routine
    // 6. Persist to Silver
    // 7. Call UpdateGold() routine
    // 8. Call EvaluateRules() routine
    // 9. Decision: rules fired?
    //    YES → Send to DecisionEngine
    //    NO → End
}
```

### 5.3 Business Rules (Decision Engine)

```objectscript
Class Rules.PaceRules Extends Ens.Rule.Definition {
    // Rules editables vía Rule Editor sin tocar código
    
    Rule "PaceNegativeCritical" {
        Constraint: variance_units < -25
        Action: SelectAction("MOVE_PALLET_TO_ENTRANCE")
    }
    
    Rule "PaceNegativeSustained" {
        Constraint: hours_below_pace >= 3
        Action: SelectAction("ACTIVATE_PROMOTIONAL_PRICE")
    }
}
```

### 5.4 Lookup Tables (Catalog de acciones)

```objectscript
Class Config.ActionCatalog Extends %Persistent {
    Property action_code As %String [ Required, Unique ];
    Property action_name As %String;
    Property action_description As %String;
    Property applicable_categories As %String;  // CSV
    Property parameters As %JSON.Adaptive;  // Parámetros configurables
    Property effectiveness_history As %JSON.Adaptive;  // Histórico de efectividad
}
```

**Ejemplos precargados:**
- `MOVE_PALLET_TO_ENTRANCE`: Para categorías con rotación rápida.
- `ACTIVATE_PROMOTIONAL_PRICE`: Descuento automático (default 5-10%).
- `REFRESH_SHELF`: Reposición de góndola.
- `ACTIVATE_INSTORE_MESSAGE`: Mensaje en pantallas del local.

### 5.5 REST API (Outbound)

```objectscript
Class API.RecommendationAPI Extends %CSP.REST {
    // GET /api/recommendations/{store_code}/{date}
    // POST /api/recommendations/{recommendation_id}/feedback
    // GET /api/dashboard/{store_code}
}
```

---

## 6. Opciones de integración POS

### 6.1 Opción 1: Kafka (Recomendada si disponible)

```
POS System → [Kafka Topic: "pos.events"] → IRIS Kafka Adapter
```

**Ventajas:**
- Real-time puro
- Desacoplado
- Replayable

**Configuración IRIS:**
```objectscript
% kafka.ConnectionString = "localhost:9092"
% kafka.Topic = "pos.events"
% kafka.ConsumerGroup = "iris-pos-consumer"
```

### 6.2 Opción 2: REST API (Backup flexible)

```
POS System → [POST /api/pos/events] → IRIS REST Service
```

**Ventajas:**
- Simple
- No requiere infraestructura adicional
- Soporta polling del lado POS

**Endpoint:**
```
POST /api/pos/events
Content-Type: application/json

[POS Event JSON]
```

### 6.3 Opción 3: File Polling (Fallback)

```
POS System → [CSV export every 5 min] → /mnt/pos/incoming/
↓
IRIS File Adapter pollea directory cada 1 min
```

**Archivo de muestra:**
```csv
transaction_id,store_code,sku,quantity,unit_price,timestamp
TRX000123,LOCAL001,VENDOR-SKU-123,3,2500,2026-05-13T14:03:00Z
```

### 6.4 Decisión para Grupo Éxito (S1)

**En semana 1 validar con cliente:**
- ¿Tiene Kafka/Pulsar? → Opción 1
- ¿Tiene API REST capaz? → Opción 2
- ¿Solo export CSV? → Opción 3

Para la PoC, **implementar Opción 2 (REST API)** como principal + Opción 3 (File polling) como fallback.

---

## 7. Plan de sprints (8 semanas, MVP en S2-S3)

### 7.1 Cronograma general

| Sprint | Semanas | Objetivo | Entregables clave |
|--------|---------|----------|------------------|
| **Sprint 0 (Setup)** | 1 | Infraestructura + ambiente | VM GCP, IRIS instalado, repos creados |
| **Sprint 1** | 2 | Ingesta + modelo de datos | Adapters, Bronze/Silver schema, test harness |
| **Sprint 2 (MVP Part 1)** | 3 | Orquestación + primeras reglas | BPL, Decision Engine, 3 reglas iniciales |
| **Sprint 3 (MVP Part 2)** | 4 | APIs + notificaciones | REST APIs, email/Slack notifications |
| **Sprint 4** | 5-6 | UI + real data | Store manager UI funcional |
| **Sprint 5** | 7 | Piloto + ajustes | Correr con datos del cliente, tuning |
| **Sprint 6 (Cierre)** | 8 | Hardening + documentación | Runbooks, demos, handover |

### 7.2 Sprint 0 (Semana 1) — Setup & Infraestructura

**Objetivo:** Ambiente productivo listo para desarrollo.

**Entregables:**

1. **Infraestructura GCP**
   - [x] Compute Engine VM (n2-standard-2, 8GB RAM, 50GB SSD)
   - [x] Cloud Storage bucket para backups
   - [x] VPC + firewall rules
   - [x] Cloud Monitoring setup

2. **IRIS Community instalado & configurado**
   - [x] IRIS 2026.1+ en Linux Ubuntu LTS
   - [x] Management Portal accesible
   - [x] SSL/TLS habilitado
   - [x] Namespace "IRIS" creado para desarrollo

3. **Repositorio Git**
   - [x] GitHub/GitLab repo con estructura:
     ```
     iris-poc/
     ├── src/
     │   ├── adapters/
     │   ├── processes/
     │   ├── classes/
     │   ├── queries/
     │   └── tests/
     ├── config/
     │   ├── production.iris.xml
     │   └── rules.xml
     ├── docs/
     │   ├── architecture.md
     │   └── api.md
     ├── sql/
     │   └── schema.sql
     └── README.md
     ```
   - [x] GitHub Copilot + Claude Code integrados en VS Code

4. **Documentación de setup**
   - [x] `SETUP.md`: pasos para provisionar IRIS desde cero
   - [x] `CREDENTIALS.md` (git-ignored): credenciales de test
   - [x] `ARCHITECTURE.md`: este documento

**Artefactos a entregar:**

```
Sprint 0 Deliverables:
├── GCP VM IP & SSH credentials
├── IRIS Management Portal URL
├── GitHub repo con estructura base
├── README con instrucciones de setup
└── VS Code workspace configurado con Copilot
```

**Esfuerzo estimado:** 40 horas (4 días a 10h/día)

---

### 7.3 Sprint 1 (Semanas 2-3) — Ingesta & Modelo de datos

**Objetivo:** Datos fluyendo del POS a IRIS, esquema completo definido.

**Entregables:**

1. **Modelos de datos (Classes %Persistent)**
   - [x] `MD.SKU` (maestro de productos)
   - [x] `MD.Store` (maestro de locales)
   - [x] `MD.Category` (maestro de categorías)
   - [x] `MD.SalesBudget` (presupuesto diario)
   - [x] `Bronze.POSEvent` (raw event)
   - [x] `Silver.Sale` (normalized)
   - [x] `Config.Rules` (reglas)
   - [x] `Config.ActionCatalog` (acciones)

   **Patrón:** Todas las clases heredan de `%Persistent` y exponen tablas SQL.

2. **Inbound Adapters (Ingesta)**
   - [x] `Service.POSEventService` (Kafka / REST / File)
   - [x] `Service.BudgetImportService` (REST / CSV upload)
   - [x] Configurables sin hardcoding

3. **Validación & Schema**
   - [x] JSON schema validation para POSEvent (agnóstico)
   - [x] Budget CSV schema validation
   - [x] Error handling + retry logic

4. **Test Harness**
   - [x] Simulador de boletas JSON (faker data)
   - [x] Simulador de presupuesto (CSV generator)
   - [x] Postman collection para testing manual de APIs

5. **Documentación**
   - [x] `DATA_MODEL.md`: schemas explicados
   - [x] `TESTING.md`: cómo correr tests localmente

**Artefactos a entregar:**

```
Sprint 1 Deliverables:
├── Classes/
│   ├── MD.SKU.cls
│   ├── MD.Store.cls
│   ├── MD.Category.cls
│   ├── MD.SalesBudget.cls
│   ├── Bronze.POSEvent.cls
│   └── Silver.Sale.cls
├── Services/
│   ├── POSEventService.cls
│   └── BudgetImportService.cls
├── Validation/
│   ├── POSEventValidator.cls
│   └── BudgetValidator.cls
├── Tests/
│   ├── POSEventServiceTest.cls (usando Postman)
│   └── BudgetImportTest.cls
├── Fixtures/
│   ├── sample_pos_events.json
│   ├── sample_budget.csv
│   └── postman_collection.json
└── Docs/
    ├── DATA_MODEL.md
    └── TESTING.md
```

**Criterios de aceptación:**

- ✓ Todas las clases compiladas sin errores
- ✓ Test harness genera 100 boletas por segundo sin error
- ✓ Budget CSV cargado correctamente
- ✓ Postman collection tiene requests funcionales
- ✓ Schema agnóstico, sin hardcoding de vendor

**Esfuerzo estimado:** 80 horas (2 sprints x 40h)

---

### 7.4 Sprint 2 (Semana 4) — Orquestación & Decision Engine (MVP PART 1)

**Objetivo:** El flujo principal funciona: boleta → enriquecimiento → decisión.

**Entregables:**

1. **BPL (Business Process Language)**
   - [x] `Process.POSProcessingBPL`: flujo visual
     1. Receive POSEvent
     2. Validate schema
     3. Persist Bronze
     4. Enrich (lookup SKU, Store, Category)
     5. Persist Silver
     6. Update Gold aggregates
     7. Evaluate rules
     8. Route to Decision Engine if rules fire
   - [x] Editable visualmente en Management Portal
   - [x] Error handling + DLQ (dead letter queue)

2. **Decision Engine (Business Rules)**
   - [x] `Rules.PaceRules`: al menos 3 reglas iniciales
     - Rule 1: `PACE_NEGATIVE_CRITICAL` (variance < -25pp)
     - Rule 2: `PACE_NEGATIVE_SUSTAINED` (3 horas seguidas bajo pace)
     - Rule 3: `STOCKOUT_INFERRED` (0 ventas en 2h de tráfico normal)
   - [x] Reglas editables sin desarrollo (via Rule Editor)
   - [x] Lookup table para umbrales y tolerancias

3. **Gold Layer (Analítica)**
   - [x] `Gold.CategoryPace`: tabla de agregados
   - [x] SQL procedure que actualiza Gold cada 5 min
   - [x] Ventanas móviles: última hora, día actual, semanal
   - [x] Cálculo de `variance_units`, `pct_pace`, etc.

4. **Testing & Validation**
   - [x] Test scenario: 50 boletas en 1h, cumplimiento = 50%
     - Esperar → debería disparar `PACE_NEGATIVE_CRITICAL`
   - [x] Trace visual en Management Portal (BPL trace)
   - [x] SQL queries para validar Gold.CategoryPace

5. **Documentación**
   - [x] `DECISION_ENGINE.md`: cómo funcionan las reglas
   - [x] `RULES_CONFIG.md`: tabla de umbrales y cómo modificarlos

**Artefactos a entregar:**

```
Sprint 2 Deliverables:
├── Processes/
│   ├── POSProcessingBPL.cls
│   └── POSProcessingBPL.bpl (visual definition)
├── Rules/
│   ├── PaceRules.cls
│   └── Rules metadata (umbrales, tolerancias)
├── Tables/
│   ├── Gold/CategoryPace.cls
│   └── SQL procedure: sp_UpdateGoldPace.sql
├── Tests/
│   ├── ScenarioTest_PaceNegativeCritical.json
│   └── SQL_ValidationQueries.sql
└── Docs/
    ├── DECISION_ENGINE.md
    └── RULES_CONFIG.md
```

**Criterios de aceptación:**

- ✓ BPL flujo completo sin errores en trace
- ✓ Gold.CategoryPace actualizado correctamente cada 5 min
- ✓ Rule dispara cuando variance < -25pp
- ✓ Rule evalúa correctamente in-memory (< 100ms)
- ✓ Reglas editables via Rule Editor (sin recompilación)

**Esfuerzo estimado:** 60 horas (1 sprint x 40h + testing)

**🎯 MILESTONE:** MVP PART 1 completo. Sistema ingesta → decisión funciona.

---

### 7.5 Sprint 3 (Semana 5) — APIs + Notificaciones (MVP PART 2)

**Objetivo:** Recomendaciones salen del sistema y llegan al usuario + dashboard.

**Entregables:**

1. **REST APIs (Outbound)**
   - [x] `API.RecommendationAPI`
     - GET `/api/recommendations/{store}/{date}` → lista del día
     - POST `/api/recommendations/{id}/feedback` → aceptar/rechazar/modificar
     - GET `/api/dashboard/{store}` → estado actual (cumplimiento %)
   - [x] Response format JSON estándar
   - [x] Authentication: API Key + JWT (simple, no OAuth para PoC)
   - [x] Rate limiting: 100 req/min por cliente

2. **Outbound Service (Notificaciones)**
   - [x] `Service.NotificationService`
     - Email (SMTP)
     - Slack webhook
     - Opcional: push mobile via Firebase
   - [x] Plantillas de notificación (Handlebars/Mustache)
   - [x] Retry logic: max 3 reintentos

3. **Persistence de Recomendaciones**
   - [x] `Ops.Recommendation` table (ya en Sprint 1, ahora se usa)
   - [x] Rastreo de feedback: accepted_at, executed_at, effectiveness_score
   - [x] Audit log: toda acción queda registrada

4. **Business Operation (Outbound)**
   - [x] `Operation.RecommendationSender`
   - [x] Maneja retry, logging, error handling

5. **Testing & Integration**
   - [x] Postman collection actualizada con nuevos endpoints
   - [x] Test de notificación: enviar email/Slack de prueba
   - [x] End-to-end: boleta → regla → recomendación → notificación

6. **Documentación**
   - [x] `API_SPEC.md`: OpenAPI/Swagger spec
   - [x] `NOTIFICATIONS.md`: configuración de canales

**Artefactos a entregar:**

```
Sprint 3 Deliverables:
├── API/
│   ├── RecommendationAPI.cls
│   ├── DashboardAPI.cls
│   └── BaseAPI.cls (clase base con autenticación)
├── Services/
│   ├── NotificationService.cls
│   ├── EmailNotificationHandler.cls
│   └── SlackNotificationHandler.cls
├── Operations/
│   ├── RecommendationSender.cls
│   └── NotificationLogger.cls
├── Config/
│   ├── email_templates.json
│   ├── slack_templates.json
│   └── notification_config.xml
├── Tests/
│   ├── APITest_GetRecommendations.cls
│   ├── APITest_PostFeedback.cls
│   └── NotificationTest_Email.cls
├── Postman/
│   └── POC_Collection_v2.json (actualizado)
└── Docs/
    ├── API_SPEC.md
    └── NOTIFICATIONS.md
```

**Criterios de aceptación:**

- ✓ Todos los endpoints retornan 200 OK con payload correcto
- ✓ POST /feedback actualiza status en Ops.Recommendation
- ✓ Email/Slack se envían correctamente (test)
- ✓ Rate limiting funciona
- ✓ Error handling devuelve 4xx/5xx con mensajes descriptivos
- ✓ API documentada en OpenAPI spec

**Esfuerzo estimado:** 60 horas (1 sprint x 40h + testing)

**🎯 MILESTONE:** MVP PART 2 completo. Recomendaciones llegan al usuario.

---

### 7.6 Sprint 4 (Semanas 5-6) — UI + Dashboard

**Objetivo:** Administrador del local puede ver acciones y responder.

**Entregables:**

1. **Store Manager UI (Mobile-first)**
   - [x] React SPA (single-page app)
   - [x] Screens:
     1. **Home:** cumplimiento % del día, flecha arriba/abajo, hora de cierre proyectada
     2. **Actions Pending:** lista de recomendaciones no ejecutadas
     3. **Action Detail:** descripción, parámetros, botones Aceptar/Rechazar/Modificar
     4. **History:** acciones ejecutadas hoy, efecto medido
   - [x] Responsive: funciona en mobile + tablet
   - [x] Offline-first: cachea estado local

2. **Supervisor Dashboard (Desktop)**
   - [x] Vue o React (a elegir)
   - [x] Screens:
     1. **Overview:** vista de N locales, cumplimiento comparado
     2. **Store Detail:** métricas detalladas de un local
     3. **Actions Effectiveness:** tabla de acciones + tasa de éxito
     4. **Audit Log:** histórico de cambios
   - [x] Exportable a CSV/PDF

3. **Frontend Stack**
   - [x] Framework: React 18+ o Vue 3+
   - [x] State management: Redux o Pinia (simple, no overkill)
   - [x] HTTP client: axios con interceptores
   - [x] Build: Vite (rápido)
   - [x] Styling: Tailwind CSS (agnóstico, no jQuery)

4. **Integración con IRIS API**
   - [x] Base URL configurable (env variables)
   - [x] Auth token manejo (JWT)
   - [x] Error handling + retry
   - [x] WebSocket opcional para real-time (si tiempo)

5. **Testing**
   - [x] Unit tests: vitest
   - [x] E2E: Cypress o Playwright (básico)
   - [x] Accessibility: WCAG 2.1 AA (keyboard nav, screen reader compat)

6. **Documentación**
   - [x] `FRONTEND_SETUP.md`: npm install, dev server, build
   - [x] `FRONTEND_COMPONENTS.md`: componentes principales y props

**Artefactos a entregar:**

```
Sprint 4 Deliverables:
├── frontend/
│   ├── public/
│   ├── src/
│   │   ├── components/
│   │   │   ├── Home.vue
│   │   │   ├── ActionsPending.vue
│   │   │   ├── ActionDetail.vue
│   │   │   └── History.vue
│   │   ├── services/
│   │   │   └── api.ts (client HTTP)
│   │   ├── store/
│   │   │   └── index.ts (state management)
│   │   ├── App.vue
│   │   └── main.ts
│   ├── vite.config.ts
│   ├── package.json
│   ├── README.md
│   └── tests/
│       └── components.test.ts
└── Docs/
    ├── FRONTEND_SETUP.md
    └── FRONTEND_COMPONENTS.md
```

**Criterios de aceptación:**

- ✓ UI carga sin errores
- ✓ Home screen muestra cumplimiento % correcto
- ✓ Actions pending lista se actualiza (polling o WS)
- ✓ Aceptar acción envía POST /api/recommendations/{id}/feedback
- ✓ Responsive: funciona en iPhone 12 + iPad
- ✓ Accessibility: navegable con teclado

**Esfuerzo estimado:** 80 horas (2 sprints x 40h)

---

### 7.7 Sprint 5 (Semana 7) — Piloto + Ajustes

**Objetivo:** Sistema corre con datos reales del cliente, ajustes finos.

**Entregables:**

1. **Data Real del Cliente**
   - [x] Cargador de histórico (últimos 12 meses)
   - [x] Validación de data (nulls, outliers, etc.)
   - [x] Mappeo de vendor_sku ↔ internal_sku
   - [x] Presupuesto real cargado

2. **Tuning & Calibración**
   - [x] Ajustar umbrales de reglas según histórico real
   - [x] Validar latencia end-to-end con volumen real
   - [x] Optimizar queries Gold (add índices si needed)

3. **Monitoreo & Alerting**
   - [x] Cloud Monitoring setup (CPU, memory, queries slow)
   - [x] Alertas: si latencia > 30s o error rate > 1%
   - [x] Dashboard de salud del sistema

4. **Documentation**
   - [x] `DEPLOYMENT.md`: pasos para deploy a GCP
   - [x] `RUNBOOK.md`: troubleshooting común
   - [x] `METRICS.md`: KPIs y cómo leerlos

5. **Testing Real**
   - [x] Correr 1 semana completa con el local real
   - [x] Medir: latencia, correctitud, tasa de falsos positivos
   - [x] Reunión con cliente: feedback sobre acciones

**Artefactos a entregar:**

```
Sprint 5 Deliverables:
├── Tools/
│   ├── DataHistoricalLoader.cls
│   └── DataValidationReport.cls
├── Config/
│   ├── production.iris.xml (tuned)
│   └── threshold_config.json (calibrated)
├── Monitoring/
│   ├── monitoring_dashboard.json (GCP)
│   └── alert_policies.json
├── Reports/
│   ├── Week1_Performance_Report.md
│   ├── Accuracy_Analysis.csv
│   └── False_Positives_Review.md
└── Docs/
    ├── DEPLOYMENT.md
    ├── RUNBOOK.md
    └── METRICS.md
```

**Criterios de aceptación:**

- ✓ Sistema corre 24/7 sin crashes
- ✓ Latencia p50 < 5s, p95 < 30s
- ✓ Accuracy de reglas ≥ 90% (validado manualmente)
- ✓ False positive rate < 5%
- ✓ Tasa de aceptación de acciones ≥ 50%

**Esfuerzo estimado:** 40 horas (1 sprint)

---

### 7.8 Sprint 6 (Semana 8) — Cierre & Hardening

**Objetivo:** Documentación, demos, handover al cliente.

**Entregables:**

1. **Documentación Completa**
   - [x] `ARCHITECTURE.md`: este documento (actualizado)
   - [x] `USER_GUIDE.md`: cómo usar la UI
   - [x] `ADMIN_GUIDE.md`: cómo configurar reglas, maestros, presupuesto
   - [x] `API_SPEC.md`: OpenAPI spec completo
   - [x] `TROUBLESHOOTING.md`: problemas comunes + soluciones

2. **Knowledge Transfer**
   - [x] 2 sesiones de capacitación: equipo IT + operaciones del cliente
   - [x] Grabación de demos (20 min: flujo end-to-end)
   - [x] Presentación ejecutiva: resultados de la PoC

3. **Testing Final**
   - [x] Smoke tests: todos los flows principales
   - [x] Regression tests: asegurar no se rompió nada
   - [x] Load test: simular 10x volumen normal, validar comportamiento

4. **Código Clean-up**
   - [x] Code review final
   - [x] Eliminar debug logs
   - [x] Standarizar nombres y comentarios
   - [x] Check: no hardcoding de valores

5. **Deliverables Finales**
   - [x] GitHub repo con todo el código (limpio, documentado)
   - [x] VM snapshot para replicar environment
   - [x] Backups de data (si el cliente lo solicita)
   - [x] Licence keys / credentials (si aplica)

**Artefactos a entregar:**

```
Sprint 6 Deliverables:
├── Documentation/
│   ├── ARCHITECTURE.md (final)
│   ├── USER_GUIDE.md
│   ├── ADMIN_GUIDE.md
│   ├── API_SPEC.md (OpenAPI/Swagger)
│   ├── TROUBLESHOOTING.md
│   └── HANDOVER_CHECKLIST.md
├── Training/
│   ├── Demo_Recording.mp4
│   ├── Presentation_ExecutiveSummary.pptx
│   └── Training_Materials/
├── Testing/
│   ├── SmokeTests.md
│   ├── RegressionTests.md
│   └── LoadTestResults.md
├── Final/
│   ├── GitHub_Repo_URL
│   ├── GCP_VM_Snapshot_ID
│   └── Credentials_File (encrypted)
└── Reports/
    ├── PoC_Results_Summary.md
    └── Recommendations_for_Scale.md
```

**Criterios de aceptación:**

- ✓ Documentación 100% completa y sin typos
- ✓ Demos y training videos publicados
- ✓ Equipo del cliente capaz de mantener el sistema
- ✓ Todos los tests pasen
- ✓ No hay known bugs críticos

**Esfuerzo estimado:** 40 horas (1 sprint)

---

## 8. Entregables por sprint (resumen)

| Sprint | Semana | Entregables clave | Status |
|--------|--------|-------------------|--------|
| **0** | 1 | VM GCP, IRIS, Repo, Copilot setup | TBD |
| **1** | 2-3 | Adapters, Esquema BD, Test harness | TBD |
| **2** | 4 | BPL, Decision Engine, 3 reglas | **MVP P1** |
| **3** | 5 | APIs, Notificaciones | **MVP P2** |
| **4** | 5-6 | Store Manager UI, Dashboard | TBD |
| **5** | 7 | Piloto con data real, ajustes | TBD |
| **6** | 8 | Documentación, training, cierre | TBD |

---

## 9. Stack de herramientas de desarrollo

### 9.1 IDE & Editors

- **VS Code** (primary)
  - Extensions: 
    - `InterSystems IRIS` (syntax highlighting, debugging)
    - `GitHub Copilot`
    - `Git Graph`
    - `REST Client`
    - `Thunder Client` (o Postman)

- **IRIS Management Portal** (visual editing de BPL, Rules, etc.)

### 9.2 Lenguajes

| Componente | Lenguaje | Razón |
|-----------|----------|-------|
| Classes, Adapters, Services | ObjectScript | Nativo IRIS |
| BPL | Visual (punto-y-click en Management Portal) | Diseño visual |
| Business Rules | Visual (Rule Editor) | Sin código, configurable |
| SQL | SQL (IRIS SQL) | Queries, procedimientos |
| REST API | ObjectScript + JSON | Clase %CSP.REST nativa |
| Frontend | TypeScript (React/Vue) | Type safety |
| Tests | ObjectScript (unittest) + vitest (frontend) | Cobertura completa |

### 9.3 Versionamiento & CI/CD

- **Git:** GitHub o GitLab
- **Branching:** `main` (producción) + `develop` (integration) + feature branches
- **GitHub Actions** (CI): 
  - Lint + compile ObjectScript
  - Unit tests
  - Build frontend
  - Deploy a GCP (manual trigger)

### 9.4 Monitoreo & Logging

- **Cloud Logging:** todos los eventos IRIS → GCP Cloud Logging
- **Cloud Monitoring:** dashboards de performance
- **ELK Stack (opcional):** si cliente quiere alertas avanzadas

---

## 10. Consideraciones de IA para desarrollo

### 10.1 GitHub Copilot (para ObjectScript)

**Casos de uso:**

- Autocompletar métodos repetitivos (getters, setters, validación)
- Generar boilerplate de clases %Persistent
- Escribir SQL queries simples
- Tests unitarios (templates)

**Instrucciones al developer:**

```
// En VS Code, al escribir:
Method ValidatePOSEvent(pEvent As %DynamicObject) As %Status {
    // Press Ctrl+Space → Copilot sugiere validaciones comunes
}

// Aceptar sugerencias si son correctas; rechazar si no aplican.
// Copilot es helper, no gospel. Code review siempre.
```

**Efectividad esperada:** +30% velocidad en boilerplate.

### 10.2 Claude Code (para Backend + Integración)

**Casos de uso:**

- Diseñar la lógica del BPL (paso a paso)
- Generar adaptadores complejos (Kafka, REST)
- Arquitectura de APIs REST
- Documentación técnica
- Debugging de flujos complejos

**Workflow:**

```
1. Developer: "Necesito un Inbound Adapter para Kafka que valide JSON"
2. Claude Code:
   - Genera clase base
   - Explica cada método
   - Sugiere error handling
3. Developer: copia a VS Code, refina, testa
```

**Efectividad esperada:** +50% velocidad en diseño, investigación.

### 10.3 Copilot for Frontend (para React/Vue)

**Casos de uso:**

- Componentes React boilerplate
- CSS Tailwind (sugerencias de clases)
- Integración HTTP (axios interceptores)
- Tests vitest
- TypeScript types

**Instrucciones:**

```jsx
// Escribir:
function ActionCard({ action, onAccept }) {
  // Copilot sugiere: card layout, buttons, state handlers
}

// Aceptar sugerencias ajustadas a tu diseño.
```

**Efectividad esperada:** +40% velocidad en UI.

### 10.4 Reglas de oro para IA tools

1. **Nunca confíes ciegamente.** Toda sugerencia de IA → code review.
2. **Mantén contexto.** Los agentes olvidan. Repetir contexto en preguntas ayuda.
3. **Usa para boilerplate y exploración, no para decisiones arquitectónicas.** Esas son tuyas.
4. **Tests primero.** Si Copilot genera código, escribe tests primero (TDD).
5. **Documenta excepciones.** Si rechazas una sugerencia de IA, explica por qué en un comentario.

---

## 11. Checklist de implementación

### 11.1 Pre-desarrollo

- [ ] VM GCP provisioned & accesible
- [ ] IRIS instalado y Management Portal funcional
- [ ] GitHub repo creado con estructura base
- [ ] GitHub Copilot + Claude Code integrados en VS Code
- [ ] Postman instalado o Thunder Client configurado
- [ ] VPN/SSH acceso confirmado
- [ ] Credenciales de cliente validadas (acceso a POS, presupuesto)

### 11.2 Durante desarrollo (cada sprint)

- [ ] Daily standup (15 min)
- [ ] Code pushed a develop branch cada 2 días
- [ ] Tests corridos antes de push
- [ ] PRs reviewed (even self-review)
- [ ] Issues/blockers registrados en GitHub Issues
- [ ] Documentación actualizada en paralelo

### 11.3 Fin de cada sprint

- [ ] Sprint review: demo de features
- [ ] Sprint retrospective: qué salió bien, qué mejorar
- [ ] Backlog refinement para siguiente sprint
- [ ] Documentación del sprint guardada en `/docs/sprints/sprint-N.md`

### 11.4 Pre-deployment (Sprint 6)

- [ ] Código: zero compiler errors, zero linter warnings
- [ ] Tests: 100% de coverage en lógica critical
- [ ] Documentación: README, API spec, runbook (completos)
- [ ] Security review: sin hardcoding de secrets, sin SQL injection, auth funciona
- [ ] Performance: latency < 30s p95, memory stable
- [ ] Backup: data del cliente respaldado

---

## 12. Anexos

### 12.1 Estructura de directorio Git (recomendada)

```
iris-poc/
├── .github/
│   └── workflows/
│       ├── ci.yml (lint, compile, tests)
│       └── deploy.yml (manual trigger)
├── src/
│   ├── adapters/
│   │   ├── POSEventService.cls
│   │   └── BudgetImportService.cls
│   ├── processes/
│   │   └── POSProcessingBPL.cls
│   ├── classes/
│   │   ├── MD/
│   │   │   ├── SKU.cls
│   │   │   ├── Store.cls
│   │   │   ├── Category.cls
│   │   │   └── SalesBudget.cls
│   │   ├── Bronze/
│   │   │   └── POSEvent.cls
│   │   ├── Silver/
│   │   │   └── Sale.cls
│   │   ├── Gold/
│   │   │   └── CategoryPace.cls
│   │   ├── Ops/
│   │   │   ├── Recommendation.cls
│   │   │   └── Feedback.cls
│   │   ├── Config/
│   │   │   ├── Rules.cls
│   │   │   └── ActionCatalog.cls
│   │   ├── API/
│   │   │   ├── RecommendationAPI.cls
│   │   │   └── DashboardAPI.cls
│   │   ├── Services/
│   │   │   ├── NotificationService.cls
│   │   │   ├── EmailHandler.cls
│   │   │   └── SlackHandler.cls
│   │   ├── Operations/
│   │   │   └── RecommendationSender.cls
│   │   ├── Routines/
│   │   │   ├── UpdateGoldPace.mac
│   │   │   ├── ValidateEvent.mac
│   │   │   └── EnrichSale.mac
│   │   └── Tests/
│   │       ├── POSEventTest.cls
│   │       ├── BudgetTest.cls
│   │       └── RulesTest.cls
│   ├── rules/
│   │   └── pace_rules.xml (exported from Rule Editor)
│   └── queries/
│       ├── GetRecommendationsByStore.sql
│       └── GetCategoryPaceDaily.sql
├── frontend/
│   ├── public/
│   ├── src/
│   │   ├── components/
│   │   ├── services/
│   │   ├── store/
│   │   ├── App.vue
│   │   └── main.ts
│   ├── vite.config.ts
│   ├── package.json
│   └── README.md
├── config/
│   ├── production.iris.xml
│   ├── development.iris.xml
│   ├── notification_config.json
│   └── threshold_config.json
├── sql/
│   ├── schema.sql (DDL inicial)
│   ├── seed_data.sql (maestros iniciales)
│   └── procedures.sql (stored procedures)
├── docs/
│   ├── ARCHITECTURE.md (este)
│   ├── DATA_MODEL.md
│   ├── API_SPEC.md
│   ├── SETUP.md
│   ├── DEPLOYMENT.md
│   ├── RUNBOOK.md
│   ├── TROUBLESHOOTING.md
│   └── sprints/
│       ├── sprint-0.md
│       ├── sprint-1.md
│       └── ... (cada sprint)
├── tools/
│   ├── test_harness.cls (simulador POS)
│   ├── data_loader.cls (cargador histórico)
│   └── validation_report.cls (validación de datos)
├── postman/
│   └── POC_Collection.json
├── .gitignore
├── README.md
└── CONTRIBUTING.md
```

### 12.2 Plantilla de PR (para code review)

```markdown
## Descripción
Breve resumen de qué cambió.

## Tipo
- [ ] Feature
- [ ] Bugfix
- [ ] Refactor
- [ ] Docs

## Cambios
- [ ] Clases %Persistent
- [ ] Adapters
- [ ] BPL
- [ ] APIs
- [ ] Frontend
- [ ] Documentación

## Testing
- [ ] Unit tests escritos
- [ ] Tests passed locally
- [ ] Manual testing hecho (descripción)

## Checklist
- [ ] Código sigue convenciones del proyecto
- [ ] Comentarios claros
- [ ] No hay console.log() o debug statements
- [ ] Documentación actualizada

## Screenshots (si UI)
[Adjuntar si aplica]
```

### 12.3 Convenciones de código

**ObjectScript:**
```objectscript
// Nombres: CamelCase para métodos/propiedades, UPPERCASE para constantes
Method ValidatePOSEvent(pEvent As %DynamicObject) As %Status { ... }
Property internal_sku As %String [ Required ];

// Documentación: XMLDoc para clases públicas
/// Esta clase persiste eventos de POS normalizados.
/// <para>Usada internamente por el Silver layer.</para>
Class Silver.Sale Extends %Persistent { ... }
```

**SQL:**
```sql
-- Nombres: lowercase_with_underscores
-- Índices: nombre_table_idx_fieldsABCS
SELECT sale_id, store_code, category_code, units_sold 
FROM silver.sale 
WHERE sale_date = ? 
ORDER BY event_timestamp DESC;
```

**Frontend (TypeScript/React):**
```typescript
// PascalCase para componentes, camelCase para variables
function ActionCard({ action, onAccept }: ActionCardProps) { ... }
const [isLoading, setIsLoading] = useState(false);
```

### 12.4 Plantilla de bug report

```markdown
## Título
[Componente] Descripción breve del bug

## Reproducir
Pasos para reproducir el bug:
1. ...
2. ...

## Comportamiento esperado
...

## Comportamiento actual
...

## Logs / Error messages
```
[Pegar logs aquí]
```

## Ambiente
- OS: Windows / macOS / Linux
- IRIS version: 2026.1.x
- Frontend: Chrome / Firefox / Safari
```

---

## Conclusión

Este documento es la brújula técnica para el desarrollo. Cada sprint refinará detalles, pero la arquitectura de capas, los modelos de datos agnósticos y el uso de IA para acelerar development permanecen.

**Próximos pasos:**

1. **Semana 0:** Setup de infraestructura (esta semana)
2. **Semana 1:** Developer comienza Sprint 0 (infraestructura)
3. **Weekly syncs:** standup de 15 min + demo semanal
4. **Sprint reviews:** cierre formal cada sprint

**Contacto técnico:**
- Arquitecto: [Christian Asmussen / Juan Pablo Bartel]
- Developer: [1 person + Copilot + Claude Code]
- Client contact: [TBD después de cierre comercial]

---

*Versión 1.0 — Mayo 2026*
*Documento vivo: actualizará conforme avancen los sprints.*
