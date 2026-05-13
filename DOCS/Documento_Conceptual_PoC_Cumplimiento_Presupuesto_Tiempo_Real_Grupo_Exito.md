# Documento Conceptual — Prueba de Concepto
## Plataforma de Cumplimiento de Presupuesto de Venta en Tiempo Real sobre InterSystems IRIS

---

**Documento:** Propuesta de Prueba de Concepto
**Cliente:** Grupo Éxito (Colombia)
**Proveedor:** MyAllSupport SpA — Santiago, Chile
**Versión:** 1.0
**Fecha:** Mayo 2026
**Autores:** Christian Asmussen · Juan Pablo Bartel
**Clasificación:** Confidencial — Compartido con cliente
**Modalidad:** Prueba de Concepto acotada con opción de escalamiento

---

## Tabla de contenidos

1. Resumen ejecutivo
2. Contexto y oportunidad
3. Tesis de la propuesta
4. Caso de uso de la PoC
5. Arquitectura de la solución
6. Flujo end-to-end
7. Modelo conceptual de datos
8. Motor de reglas y catálogo de acciones
9. Experiencia del administrador del local
10. Stack tecnológico
11. Alcance de la PoC
12. Plan de trabajo
13. Métricas de éxito
14. Riesgos y mitigación
15. Supuestos y dependencias del cliente
16. Próximos pasos
17. Anexos

---

## 1. Resumen ejecutivo

Este documento describe una Prueba de Concepto (PoC) acotada para implementar, sobre **InterSystems IRIS**, una plataforma que monitoree en tiempo casi-real el cumplimiento del presupuesto de venta a nivel de local y categoría, y entregue al administrador del local **acciones operativas concretas** cuando se detecte un desvío que ponga en riesgo el cumplimiento del día.

La PoC se ejecuta en **un solo local y una sola categoría** durante 6 a 8 semanas, con el objetivo de demostrar:

- Que la captura continua de datos transaccionales desde frentes de caja (POS) permite calcular el cumplimiento del presupuesto con latencia operativa útil (5–20 minutos).
- Que un motor de reglas declarativo puede traducir desvíos detectados en **acciones tangibles** ejecutables por el administrador del local (mover un palet a la entrada, activar promoción tipo "lechero", refrescar góndola, ajustar precio dinámico, etc.).
- Que la arquitectura es escalable a la totalidad de la cadena sin reescritura, manteniendo el modelo "construir-no-comprar" que prefiere el cliente.

**Diferencial conceptual:** la propuesta implementa explícitamente un **loop cerrado de "analítica → acción → analítica"**, en contraste con dashboards descriptivos que requieren que el usuario sepa qué hacer con la información. La acción es la salida primaria del sistema; la métrica es subproducto.

**Antecedente externo:** Christian Asmussen implementó una solución funcionalmente análoga en Walmart, con resultados de negocio medibles. La presente PoC traslada ese patrón al stack moderno de IRIS, aprovechando capacidades nativas de interoperabilidad, persistencia híbrida transaccional-analítica y orquestación visual que no existían en la implementación original.

---

## 2. Contexto y oportunidad

### 2.1 El problema operacional

En un supermercado, el cumplimiento del presupuesto de venta diario se determina **durante el día**, no al final del mes. Si a las 18:00 horas un local lleva 10 unidades vendidas de una SKU cuya meta diaria son 50, el administrador del local tiene tres horas operativas para corregir, o el día se pierde — y los días perdidos son acumulativos y no recuperables.

Hoy, en la práctica, ese ciclo de detección y corrección depende de:

- Reportes nocturnos o de cierre, que llegan **después** de que la oportunidad de acción se cerró.
- Intuición del administrador del local, que necesariamente trabaja en muestreo manual sobre miles de SKU.
- Llamadas y correos de supervisión, que añaden latencia y solo cubren un puñado de categorías priorizadas.

El resultado: los desvíos se descubren cuando ya no son corregibles, las metas mensuales se erosionan acumulando déficits diarios, y los bonos por cumplimiento se ven afectados en cadena hasta el gerente del local.

### 2.2 La oportunidad

La data necesaria **ya existe** en los frentes de caja del cliente. Lo que falta es:

1. Capturarla continuamente, no por lote nocturno.
2. Cruzarla con el presupuesto de venta granular (local × categoría × día).
3. Evaluarla contra umbrales de desvío configurables.
4. Traducir el desvío a una **acción concreta** que el administrador del local pueda ejecutar en los minutos siguientes.
5. Cerrar el loop midiendo el efecto de la acción.

Este es el alcance funcional de la PoC.

### 2.3 Validación del modelo

El patrón está validado tanto operacionalmente (implementación previa en Walmart) como conceptualmente por la literatura del sector. McKinsey lo describe como analítica que recomienda timing de promociones y cambios de surtido en categorías específicas para subir tráfico y rotación, generando recomendaciones cuyo impacto en revenue es rápidamente medible (ver Anexo 17.2). Las arquitecturas de referencia de Databricks para retail incluyen explícitamente un componente llamado *Store Manager Assistant* que cumple esta función dentro de su modelo de "AI Agents" para retail (ver Anexo 17.2).

---

## 3. Tesis de la propuesta

La tesis se sostiene en tres principios:

### 3.1 Acción sobre dashboard

La salida primaria del sistema no es un gráfico — es una **acción ejecutable**, descrita en lenguaje operacional ("mover palet de agua mineral a entrada", "activar precio promocional de 8% en aceite girasol"), con un destinatario claro (el administrador del local) y una ventana de ejecución acotada (próximas 2–3 horas).

El dashboard existe, pero como complemento del flujo de acción, no como el producto. Esto es deliberadamente opuesto al modelo dominante de la industria, donde el dashboard es el deliverable y la acción es responsabilidad del usuario.

### 3.2 Loop cerrado verificable

Cada acción recomendada genera un registro auditable: hora de emisión, hora de aceptación o rechazo por el administrador, hora de ejecución reportada, y medición del cumplimiento de la categoría en los 30, 60 y 120 minutos posteriores. Esto permite:

- Medir empíricamente qué acciones funcionan y cuáles no.
- Aprender qué administradores tienen mejor disciplina de ejecución.
- Refinar las reglas del motor en base a datos propios del cliente, no en base a supuestos.

### 3.3 Construir, no comprar

La PoC se construye **sobre una plataforma**, no se configura sobre un SaaS vertical. Esto preserva la libertad del cliente para:

- Adueñarse del código y de los modelos de datos.
- Integrar con su ecosistema de 100+ soluciones existentes sin pasar por APIs de un tercero.
- Escalar a otros casos de uso (manejo de góndola vs bodega, consolidación de OCs centralizadas, análisis de mermas) reutilizando los mismos componentes.
- Evitar el modelo de cobro por transacción que el cliente ya descartó explícitamente.

---

## 4. Caso de uso de la PoC

### 4.1 Definición

Implementar, para **un local específico** de Grupo Éxito y **una sola categoría de producto** (por definir con el cliente — sugerencia: bebidas con gas, aceites, o galletas, todas con buena rotación y buen volumen de transacciones), el siguiente flujo continuo:

1. Cada boleta emitida en el frente de caja del local seleccionado se ingresa al sistema en cuestión de segundos.
2. El sistema agrega ventas de la categoría seleccionada en ventanas móviles (última hora, día corriente, vs presupuesto del día).
3. Cada N minutos (configurable, default 15), el motor evalúa reglas de desvío: ¿se está cumpliendo el ritmo necesario para llegar a la meta del día?
4. Si hay desvío relevante, el sistema selecciona la acción más apropiada del catálogo de acciones predefinido para esa categoría y la entrega al administrador del local.
5. El administrador acepta, rechaza o modifica la acción desde una pantalla simple.
6. El sistema registra la acción y mide el efecto en los minutos posteriores, alimentando el aprendizaje del propio motor.

### 4.2 Lo que la PoC incluye

- Captura de boletas del local seleccionado.
- Carga de presupuesto de venta de la categoría seleccionada (granularidad mínima: día).
- Carga de historial de venta de los últimos 12 meses para la categoría, para construir curvas estacionales y comparables.
- Motor de cruce y evaluación de desvíos.
- Catálogo inicial de 5–10 acciones para la categoría.
- UI mínima para el administrador del local (mobile-first o tablet).
- UI mínima de supervisión para la jefatura del local y para el área comercial.
- Métricas de cumplimiento y de efectividad de las acciones.

### 4.3 Lo que la PoC explícitamente no incluye

- Cobertura de otras categorías o de otros locales.
- Integración con sistemas de despacho, reabastecimiento o supply chain del cliente.
- Cambios en sistemas POS o ERP del cliente.
- Modificaciones de góndola física, mobiliario o señalética.
- Programa de incentivos atado al cumplimiento (es un caso de uso adyacente que puede plantearse en una segunda fase).
- Implementación productiva multi-local. La PoC es deliberadamente unitaria.

---

## 5. Arquitectura de la solución

### 5.1 Principio rector

La arquitectura sigue el patrón consolidado de **ingesta de eventos en streaming + persistencia en capas + motor de reglas declarativo + emisión de acciones**, ampliamente documentado por las arquitecturas de referencia de Databricks, AWS y Microsoft para retail. La PoC implementa este patrón sobre **InterSystems IRIS**, aprovechando que IRIS combina nativamente en un solo motor las capacidades de ingesta transaccional, orquestación, persistencia y analítica que en arquitecturas de referencia tradicionales requieren múltiples componentes.

Referencias canónicas (ver Anexo 17.2 para URLs completas):

- **Databricks Real-Time Point-of-Sale Analytics Solution Accelerator** — patrón de pipelines híbridos streaming + batch para datos POS.
- **Databricks Retail Demand Forecasting Reference Architecture** — incluye explícitamente el patrón de "Store Manager Assistant" como agente de asistencia inteligente al gerente de tienda.
- **AWS Streaming Analytics Reference Architecture** — patrón de enriquecimiento de stream contra datos de referencia (productos, promociones).
- **AWS Cloud POS Reference Architecture** — modelo de cuatro features de un POS cloud-based.
- **Microsoft Cloud for Retail Reference Implementation** — patrón enterprise para retail sobre Azure y Power Platform.

### 5.2 Diagrama lógico de alto nivel

```
┌──────────────────────────┐
│  Frente de caja (POS)    │
│  Local seleccionado       │
│  Boletas individuales     │
└────────────┬─────────────┘
             │
             │ Stream de eventos de venta
             ▼
┌────────────────────────────────────────────────────────────────────┐
│  InterSystems IRIS — Interoperability Production                   │
│                                                                    │
│  ┌──────────────┐   ┌─────────────┐   ┌──────────────────────┐    │
│  │  Inbound      │──▶│   BPL        │──▶│  Decision Engine     │    │
│  │  Service      │   │  Pipeline    │   │  (Reglas + Catálogo  │    │
│  │  (POS feed)   │   │              │   │   de Acciones)       │    │
│  └──────────────┘   └──────┬───────┘   └──────────┬───────────┘    │
│                            │                       │                │
│  ┌─────────────────────────▼──────────────────┐    │                │
│  │   Capa Bronze  (eventos raw)               │    │                │
│  │   Capa Silver  (eventos normalizados)      │    │                │
│  │   Capa Gold    (agregados por ventana)     │    │                │
│  └────────────────────────────────────────────┘    │                │
│                                                    │                │
│  ┌─────────────────────────┐  ┌──────────────────▼──────────┐      │
│  │   Maestros y presupuesto│  │   Outbound Service           │      │
│  │   (Master Data)         │  │   (notificación + UI)        │      │
│  └─────────────────────────┘  └──────────────┬───────────────┘      │
└────────────────────────────────────────────┼─────────────────────┘
                                              │
                                              ▼
                          ┌──────────────────────────────┐
                          │  UI del administrador        │
                          │  (mobile-first / tablet)     │
                          │  Acción recomendada          │
                          │  Aceptar / Rechazar / Editar │
                          └──────────────────────────────┘
```

### 5.3 Componentes

#### 5.3.1 Inbound Service

Responsable de recibir el flujo de eventos de venta desde el sistema POS del cliente. Se construye usando los adaptadores nativos de IRIS Interoperability. Las opciones técnicas concretas dependen de cómo el cliente exponga la data del POS y se definen en la primera semana de la PoC:

- **Si hay Kafka u otro bus de eventos:** consumer Kafka nativo de IRIS.
- **Si hay API REST:** polling configurable de la API.
- **Si hay base de datos transaccional accesible:** Change Data Capture vía adaptador SQL.
- **Si hay export plano (CSV, archivo de boletas):** adaptador File con polling.

Independientemente del mecanismo, el evento entra al sistema con latencia objetivo menor a 30 segundos desde su ocurrencia en caja.

#### 5.3.2 BPL Pipeline

Implementado como `Ens.BusinessProcessBPL`. Es el orquestador del flujo. Para cada boleta recibida ejecuta:

1. Normalización del evento (canonical model).
2. Persistencia en capa Bronze (raw).
3. Enriquecimiento contra maestros (categoría del SKU, presupuesto vigente, jerarquía de tienda) y persistencia en capa Silver.
4. Actualización de agregados rolantes (ventana 1h, día, vs presupuesto) en capa Gold.
5. Disparo asíncrono del Decision Engine si el agregado actualizado cruza algún umbral configurado.

El BPL es editable visualmente desde el Management Portal de IRIS, queda versionado en el repositorio de clases, y persiste estado entre pasos, lo que permite suspender y reanudar procesos largos sin pérdida de información (ver Anexo 17.2, documentación oficial BPL).

#### 5.3.3 Capas de datos (patrón Medallion)

Adoptamos el patrón Bronze / Silver / Gold formalizado por Databricks en su Lakehouse for Retail, por dos razones: es el estándar reconocido por cualquier ingeniero de datos moderno, y separa cleanamente las capas de calidad y propósito.

- **Bronze:** eventos POS tal como llegan, sin transformación.
- **Silver:** eventos normalizados al modelo canónico, enriquecidos con dimensiones de producto y tienda.
- **Gold:** agregados pre-computados por categoría, ventana temporal y comparación contra presupuesto. Listos para servir tanto al motor de decisión como a las pantallas del usuario.

En IRIS estas capas se implementan como clases persistentes con prefijos `Bronze.`, `Silver.` y `Gold.`, lo que mantiene la separación lógica sin requerir múltiples tecnologías.

#### 5.3.4 Decision Engine

Componente que evalúa el estado actual contra reglas configurables y selecciona la acción del catálogo a recomendar. Se implementa combinando dos mecanismos nativos de IRIS:

- **Business Rules:** reglas declarativas editables vía Rule Editor del Management Portal, versionables, no requieren código.
- **Lookup Tables:** catálogo de acciones disponibles por categoría, con parámetros (descuento sugerido, ubicación física, mensaje al administrador).

Para la PoC el motor es predominantemente determinístico (umbrales y reglas if-then sobre el estado del agregado). En una fase posterior puede incorporar IntegratedML de IRIS para refinar la selección de acción en base al histórico de efectividad.

#### 5.3.5 Outbound Service y UI

Componente que entrega la acción recomendada al administrador. Para la PoC se implementa como:

- API REST expuesta desde IRIS vía `%CSP.REST`.
- Frontend ligero (React o Vue, a definir según skill team), mobile-first para uso en piso de venta o tablet en oficina del local.
- Notificación adicional opcional vía email o webhook a Slack / Teams si el cliente lo prefiere.

### 5.4 Stack de despliegue

- **Cloud:** Google Cloud Platform (estándar de MyAllSupport SpA), Compute Engine con Linux Ubuntu.
- **IRIS:** Community Edition para la PoC (sin costo de licencia); migración a edición licenciada solo si la PoC se escala a producción.
- **Persistencia adjuntos / logs:** Cloud Storage de GCP.
- **Conectividad cliente:** VPN site-to-site o Cloud Interconnect según preferencia de Grupo Éxito.

---

## 6. Flujo end-to-end

A modo ilustrativo, el siguiente es el flujo para un caso concreto (ejemplo: agua mineral con gas, local Éxito Norte, día martes):

| Hora | Evento | Acción del sistema |
|------|--------|-------------------|
| 08:00 | Apertura del local | Sistema carga presupuesto del día: 50 unidades de agua con gas. Inicializa contador en 0. |
| 09:15 | Venta 1 (3 unidades) | Boleta ingresa al stream. Capa Bronze persiste. Silver normaliza. Gold actualiza: 3/50 = 6% de la meta, 6% del día transcurrido. **En pace.** |
| 11:30 | Acumulado 8 unidades | Gold: 8/50 = 16% de meta, 35% del día. **Leve desvío negativo (-19 pp).** Regla aún no dispara (umbral default 25 pp). |
| 14:00 | Acumulado 12 unidades | Gold: 24% de meta, 67% del día. **Desvío crítico (-43 pp).** Regla dispara. Decision Engine consulta catálogo de acciones para categoría "bebidas con gas". Selecciona: "mover palet a entrada del local". Emite acción al administrador. |
| 14:03 | Notificación recibida | Administrador acepta acción desde tablet. Ejecuta en piso. |
| 14:45 | Acumulado 22 unidades | Gold actualiza. Loop cerrado: registra que tras la acción, las ventas aceleraron de 2 a 10 unidades por 30 minutos. |
| 17:00 | Acumulado 38 unidades | Gold: 76% de meta, 90% del día. Sin nuevo disparo (en pace según ritmo post-acción). |
| 20:00 | Cierre, 48 unidades | Cumplimiento: 96%. Sistema persiste resultado del día y la efectividad de la acción para el aprendizaje del motor. |

El siguiente día, el mismo flujo se repite con la diferencia de que el sistema ya "sabe" que para esa categoría y ese local, mover el palet a la entrada produjo +8 unidades en 30 minutos. Esa información puede usarse para priorizar acciones en el futuro.

---

## 7. Modelo conceptual de datos

A nivel conceptual, las entidades centrales del sistema son las siguientes. La implementación física en IRIS usa clases persistentes (`%Persistent`) que se exponen simultáneamente como tablas SQL y como objetos.

| Entidad | Propósito | Capa |
|---------|-----------|------|
| `Bronze.POSEvent` | Evento crudo de venta tal como llega del POS | Bronze |
| `Silver.SaleLine` | Línea de venta normalizada y enriquecida con SKU, categoría, jerarquía de local | Silver |
| `Gold.CategoryPace` | Agregado por local, categoría y ventana temporal (hora, día) con cumplimiento vs presupuesto | Gold |
| `MD.SKU` | Maestro de productos (SKU, descripción, categoría, jerarquía) | Maestro |
| `MD.Store` | Maestro de locales (código, nombre, jerarquía geográfica, formato) | Maestro |
| `MD.SalesBudget` | Presupuesto de venta por local × categoría × día | Maestro |
| `Rules.Threshold` | Reglas de desvío evaluadas por el Decision Engine | Configuración |
| `Catalog.Action` | Catálogo de acciones disponibles por categoría | Configuración |
| `Ops.Recommendation` | Acción recomendada emitida, con destinatario, hora, parámetros | Operacional |
| `Ops.Feedback` | Respuesta del administrador (aceptada / rechazada / modificada) y resultado medido | Operacional |

La PoC opera en un único namespace de IRIS con todas las clases compartidas. La separación lógica entre capas se mantiene por el prefijo del paquete y por convenciones de acceso.

---

## 8. Motor de reglas y catálogo de acciones

### 8.1 Tipos de reglas iniciales

| Regla | Disparo | Severidad |
|-------|---------|-----------|
| **Pace negativo crítico** | Cumplimiento real < pace esperado − 25 puntos porcentuales | Alta |
| **Pace negativo sostenido** | Tres ventanas consecutivas de 1h con cumplimiento < pace esperado − 10 pp | Media |
| **Stockout inferido** | Cero ventas de un SKU del top-20 durante ventana de 2h con tráfico normal | Alta |
| **Día atípico** | Pace muy distinto del comparable estacional (mismo día, mismo período del año pasado), pero sin causa identificable | Información |
| **Recuperación lograda** | Tras acción aceptada, cumplimiento vuelve a pace en menos de 90 min | Confirmación positiva |

Las reglas son editables sin desarrollo, usando el Rule Editor visual de IRIS.

### 8.2 Catálogo inicial de acciones (ejemplo categoría "bebidas con gas")

| Acción | Cuándo aplica | Parámetros |
|--------|---------------|------------|
| Mover palet a entrada del local | Pace negativo crítico, hay stock en bodega | SKU específico, ubicación destino |
| Activar precio promocional ("lechero") | Pace negativo sostenido | % de descuento, vigencia, SKU |
| Refrescar góndola | Stockout inferido | SKU, ubicación |
| Activar mensaje en pantallas in-store | Pace negativo crítico, hay tráfico alto | Mensaje, duración |
| Reasignar reponedor | Stockout inferido, varios SKU afectados | Lista de SKU prioritarias |
| Revisar precio competencia | Día atípico negativo, sin causa interna | SKU, comparables |

El catálogo es extensible por el cliente sin desarrollo de código.

### 8.3 Aprendizaje

Cada acción ejecutada genera un registro de efectividad: cumplimiento antes vs después, tiempo a la recuperación, tasa de aceptación por el administrador. Esto alimenta dos análisis posibles:

- **Priorización heurística:** cuando la regla dispara y hay varias acciones candidatas, elegir la que históricamente funcionó mejor en condiciones similares.
- **Curva de aprendizaje del local:** identificar qué administradores ejecutan acciones consistentemente y qué locales responden mejor a qué tipos de intervención.

Estas capacidades de aprendizaje exceden el alcance de la PoC pero quedan habilitadas por el diseño.

---

## 9. Experiencia del administrador del local

La interfaz es deliberadamente mínima. La filosofía es que el administrador del local **no debe abrir un dashboard para enterarse** — el sistema lo busca a él.

### 9.1 Notificación

Cuando una acción se recomienda, el administrador recibe una notificación push, email o mensaje según preferencia del cliente. El mensaje incluye:

- Categoría afectada.
- Estado actual (acumulado vs presupuesto).
- Acción recomendada en lenguaje operacional, no técnico.
- Botón de "Aceptar y ejecutar" / "Rechazar" / "Modificar".

### 9.2 Pantalla principal del administrador

Vista única, mobile-first, con tres bloques:

1. **Acciones pendientes** (lo único que requiere atención inmediata).
2. **Cumplimiento del día** (vista resumen, no detallada — flecha arriba/abajo, % de cumplimiento, hora de cierre proyectada).
3. **Histórico del día** (acciones aceptadas, rechazadas, efecto observado).

### 9.3 Pantalla de supervisión

Para el jefe del local o el área comercial regional:

- Vista comparada de varios locales (cuando se escale).
- Categorías con mayor número de desvíos.
- Tasa de aceptación de acciones por administrador.
- Efectividad histórica del catálogo.

### 9.4 Mockups

Los mockups detallados se entregan como documento separado, en formato visual (PPT y/o Figma). Estos mockups acompañarán este documento para la presentación al cliente.

---

## 10. Stack tecnológico

### 10.1 Componentes core

| Capa | Tecnología | Justificación |
|------|------------|---------------|
| Plataforma de datos e integración | InterSystems IRIS Community Edition | Combina ingesta transaccional, persistencia, orquestación BPL, motor de reglas y analítica en un solo motor. Reduce footprint operativo. |
| Cloud | Google Cloud Platform | Estándar interno de MyAllSupport SpA; entrega Compute Engine, Cloud Storage y conectividad empresarial. |
| Sistema operativo | Linux Ubuntu LTS | Soporte estable, compatibilidad con runtime de IRIS. |
| Frontend del administrador | React o Vue | A definir según skill del equipo asignado. |
| Notificaciones | SMTP / Webhook (Slack, Teams) / Push | Según preferencia del cliente. |
| Conectividad con POS | A definir en semana 1 | Kafka, REST API, CDC SQL o file polling, según infraestructura del cliente. |

### 10.2 Por qué IRIS para este caso

- **Único motor para transacciones y analítica.** La latencia entre el evento POS y el cálculo del cumplimiento es de milisegundos a segundos, sin ETL intermedio. La documentación oficial de IRIS describe latencias de 10 a 20 milisegundos entre evento y dashboard cuando se opera sobre cubos in-engine (Anexo 17.2).
- **Orquestación visual y versionable.** BPL permite que tanto desarrolladores como analistas de negocio entiendan y modifiquen el flujo.
- **Persistencia de mensajes nativa.** Cada paso del pipeline queda registrado y es replayable, lo que facilita auditoría y debugging en producción.
- **Embebido de Python.** Permite incorporar modelos ML cuando se requiera, sin sacar la data del motor.
- **Multimodelo nativo.** Acepta SQL, objetos, JSON y globals sobre el mismo dato. Reduce las decisiones técnicas y la duplicación de esquemas.

### 10.3 Sobre Community Edition

IRIS Community es adecuada para esta PoC porque opera bajo el umbral de sus restricciones (5 conexiones concurrentes, 8 GB de capacidad de base de datos). Para escalar a producción multi-local se requiere migrar a edición licenciada de IRIS antes del go-live, decisión que se evalúa al cierre de la PoC.

---

## 11. Alcance de la PoC

### 11.1 Lo que se entrega

- Ambiente IRIS Community desplegado en GCP, operativo y accesible.
- Inbound Service capturando boletas del local seleccionado, latencia menor a 30 segundos.
- Modelo de datos completo y poblado (maestros + 12 meses de histórico + presupuesto del período).
- BPL Pipeline procesando eventos hasta capa Gold.
- Decision Engine con al menos 5 reglas activas y catálogo de 5–10 acciones para la categoría seleccionada.
- UI del administrador funcional, accesible desde mobile / tablet.
- UI de supervisión funcional, accesible desde escritorio.
- Set de métricas de cumplimiento y efectividad, mediblas al cierre.
- Documentación técnica para handover (arquitectura, modelo de datos, runbook operativo).
- Demostración en vivo al cliente al cierre, con escenarios reales del local.

### 11.2 Lo que no se entrega

- Productivización multi-local (es la fase siguiente).
- Migración a edición licenciada de IRIS.
- Integración con sistemas adicionales del cliente más allá del POS.
- Cambios en sistemas existentes del cliente.

### 11.3 Criterios de éxito de la PoC

La PoC se considera exitosa si al cierre se cumplen los siguientes criterios:

| # | Criterio | Métrica |
|---|----------|---------|
| 1 | Captura de boletas estable | Latencia mediana ≤ 30 seg durante las últimas 2 semanas |
| 2 | Cálculo de cumplimiento confiable | Diferencia ≤ 1% entre el cumplimiento del sistema y el cálculo manual de control |
| 3 | Reglas disparando útilmente | ≥ 10 acciones recomendadas durante el período de pilotaje |
| 4 | Aceptación del administrador | ≥ 50% de las acciones recomendadas son aceptadas o modificadas (no rechazadas) |
| 5 | Efectividad observada | Las acciones aceptadas muestran efecto positivo medible (mejora de pace post-acción) en al menos 40% de los casos |
| 6 | Estabilidad operativa | Sistema disponible ≥ 95% del horario operativo del local |
| 7 | Validación cualitativa | Entrevistas con el administrador y la jefatura del local arrojan valoración positiva del concepto |

---

## 12. Plan de trabajo

### 12.1 Cronograma de 8 semanas

| Fase | Semanas | Entregables |
|------|---------|-------------|
| **F1. Setup y descubrimiento** | 1–2 | VM GCP provisionada, IRIS Community instalado, definición de mecanismo de captura POS, acceso a maestros y presupuesto del cliente, definición de categoría y local de la PoC |
| **F2. Ingesta y modelo de datos** | 3–4 | Inbound Service capturando boletas en ambiente de QA, capas Bronze/Silver/Gold operativas, maestros cargados, presupuesto cargado, histórico de 12 meses cargado |
| **F3. Motor de reglas y catálogo** | 4–5 | Decision Engine con primeras reglas, catálogo de acciones definido con el cliente, BPL completo end-to-end con eventos simulados |
| **F4. UI y experiencia** | 5–6 | UI del administrador y de supervisión, integradas con IRIS vía REST, accesibles desde dispositivos del cliente |
| **F5. Pilotaje** | 7 | Sistema corriendo con boletas reales en el local seleccionado, ajuste fino de reglas y catálogo, medición de métricas |
| **F6. Cierre y demostración** | 8 | Reporte de resultados, demostración al cliente, documentación de handover, recomendación go/no-go para escalamiento |

### 12.2 Hitos de validación

- **Hito 1 (fin S2):** primera boleta del cliente capturada exitosamente en IRIS, demostrada en pantalla.
- **Hito 2 (fin S4):** flujo end-to-end con eventos simulados, demostración interna.
- **Hito 3 (fin S6):** UI funcional, demostración al cliente con datos cargados manualmente.
- **Hito 4 (fin S7):** primera acción recomendada y aceptada por el administrador real.
- **Hito 5 (fin S8):** demostración de cierre con resultados medidos del piloto.

---

## 13. Métricas de éxito

Más allá de los criterios técnicos de la PoC (sección 11.3), las métricas de negocio que se medirán durante el piloto son:

| Métrica | Definición | Lectura |
|---------|------------|---------|
| **Cumplimiento de la categoría en el local PoC** | % de cumplimiento de presupuesto de la categoría seleccionada durante el período de pilotaje | Comparado con el mismo período del año anterior y con otros locales sin sistema |
| **Tasa de aceptación de acciones** | % de acciones recomendadas que son aceptadas o modificadas por el administrador | Validación de utilidad práctica |
| **Tiempo a la acción** | Tiempo desde recomendación hasta confirmación de ejecución | Validación de usabilidad |
| **Uplift atribuible** | Mejora del pace de la categoría en los 60 min posteriores a una acción ejecutada | Validación de efectividad |
| **Cumplimiento del día** | % de días del período en que la categoría cerró sobre 95% de su presupuesto | Validación de impacto agregado |
| **Satisfacción del administrador** | Entrevista cualitativa al cierre | Validación cualitativa |

Estas métricas son la base para la decisión de escalamiento.

---

## 14. Riesgos y mitigación

| ID | Riesgo | Probabilidad | Impacto | Mitigación |
|----|--------|--------------|---------|------------|
| R1 | Acceso a la data POS del cliente no se materializa en plazo | Media | Alto | Definición del mecanismo en semana 1 como prerrequisito formal; backup con simulador de POS basado en data histórica del cliente |
| R2 | Calidad o granularidad insuficiente del presupuesto | Alta | Alto | Definición temprana de granularidad mínima requerida; uso de presupuesto inferido del histórico si el presupuesto formal del cliente es muy grueso |
| R3 | Administrador del local no adopta la herramienta | Media | Alto | Co-diseño de la UI con el administrador desde semana 4; entrenamiento; presencia del equipo durante la primera semana de pilotaje |
| R4 | Reglas no calibradas (muchos falsos positivos o falsos negativos) | Alta | Medio | Período de pilotaje incluye ajuste continuo; reglas son configurables sin desarrollo |
| R5 | Catálogo de acciones inadecuado para la realidad del local | Media | Alto | Catálogo se co-construye con el administrador del local y con el área comercial, no se impone |
| R6 | IRIS Community insuficiente incluso para la PoC | Baja | Medio | Volumen estimado del local seleccionado está cómodamente bajo el techo de Community; si emerge problema, migración temprana a edición licenciada con costo acotado |
| R7 | Conectividad GCP ↔ cliente bloqueada | Media | Alto | Coordinación desde semana 1; alternativa de despliegue híbrido con componente edge en infraestructura del cliente si fuera necesario |
| R8 | Cambio de prioridades del cliente durante la PoC | Media | Medio | Hitos semanales con sponsor del cliente; entregables incrementales y demostrables en cada hito |
| R9 | Resultados de la PoC no son concluyentes (efectividad ambigua) | Media | Medio | Definición temprana de qué constituye éxito (sección 11.3 y 13); período de pilotaje suficientemente largo para significancia estadística |
| R10 | Diferencias culturales o de proceso entre el local PoC y el resto de la cadena | Alta | Bajo | La PoC es deliberadamente unitaria; la generalización se evalúa al cierre, no se asume |

---

## 15. Supuestos y dependencias del cliente

Para que la PoC se ejecute en los plazos comprometidos, Grupo Éxito debe proveer durante las primeras dos semanas:

- **Acceso técnico a la data POS** del local seleccionado, en tiempo casi-real (Kafka, API REST, CDC sobre BD o export plano frecuente — cualquiera funciona, la elección depende de la infraestructura del cliente).
- **Maestro de productos (SKU)** del cliente, con categorización y jerarquía.
- **Maestro de locales** con jerarquía organizacional.
- **Presupuesto de venta** de la categoría seleccionada para el período de pilotaje, con granularidad mínima diaria.
- **Histórico de venta** de los últimos 12 meses para la categoría y el local seleccionado.
- **Designación del local PoC** y de la **categoría PoC** (decisión conjunta con el equipo de MyAllSupport SpA).
- **Designación del administrador del local** como contraparte operativa, con disponibilidad para co-diseño y entrenamiento.
- **Designación de un sponsor funcional** del lado del cliente que pueda resolver dudas de negocio y autorizar cambios en plazo de 24 horas hábiles.
- **Conectividad de red** entre el VPC de GCP de la consultora y los sistemas del cliente (VPN, peering, Interconnect — la modalidad la elige el cliente).
- **Aprobación de seguridad** para acceso a los datos del local PoC.

La ausencia de cualquiera de estos elementos al inicio del proyecto puede generar bloqueos imputables al cliente que impactarán el cronograma y serán gestionados como cambios de alcance.

---

## 16. Próximos pasos

Para avanzar, se propone la siguiente secuencia:

1. **Revisión conjunta de este documento** entre MyAllSupport SpA y el sponsor del cliente — agendar reunión la próxima semana.
2. **Presentación del concepto y los mockups** al decisor del cliente, con participación de Christian Asmussen para aportar credibilidad técnica del caso Walmart.
3. **Selección del local y la categoría** de la PoC, basándose en criterios operativos del cliente (volumen, criticidad, accesibilidad del administrador).
4. **Validación de prerrequisitos** del cliente (sección 15).
5. **Cierre comercial de la PoC** y fecha de arranque.
6. **Kickoff de proyecto** con equipo completo de ambas partes.

---

## 17. Anexos

### 17.1 Glosario

| Término | Definición |
|---------|------------|
| BPL | Business Process Language, lenguaje visual de orquestación de IRIS |
| Cumplimiento | % del presupuesto efectivamente vendido al momento de la medición |
| Decision Engine | Componente que aplica reglas y selecciona acciones |
| GCP | Google Cloud Platform |
| IRIS | InterSystems IRIS Data Platform |
| Loop cerrado | Modelo donde la acción es output, su efecto es medido y alimenta el aprendizaje |
| Medallion | Patrón de capas Bronze / Silver / Gold formalizado por Databricks |
| Pace | Ritmo de venta necesario para llegar a la meta del período |
| PoC | Prueba de Concepto |
| POS | Point of Sale, frente de caja |
| SKU | Stock Keeping Unit, unidad mínima de identificación de producto |

### 17.2 Referencias técnicas

**Plataforma InterSystems IRIS**
- InterSystems IRIS Architecture Guide (PDF oficial)
  https://www.intersystems.com/intersystems-iris-architecture-guide.pdf
- InterSystems IRIS — Developing BPL Processes (documentación oficial)
  https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=EBPL_use
- InterSystems IRIS — Documentation Home
  https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls
- InterSystems IRIS Data Platform Architecture (artículo developer community)
  https://community.intersystems.com/post/intersystems-iris-data-platform-architecture

**Demos y templates de InterSystems reutilizables como punto de partida**
- Workshop oficial de interoperability (joins, enriquecimiento, BPL)
  https://github.com/intersystems-ib/workshop-interop-intro
- Template básico de interoperability solution
  https://github.com/intersystems-community/iris-interoperability-template
- Demo Fraud Prevention con simulador POS Angular (funcionalmente la más cercana)
  https://github.com/intersystems-community/irisdemo-demo-fraudprevention

**Arquitecturas de referencia para Real-Time POS Analytics**
- Databricks Real-Time Point-of-Sale Analytics Solution Accelerator
  https://www.databricks.com/solutions/accelerators/real-time-point-of-sale-analytics
- Databricks — Retail Demand Forecasting Reference Architecture (incluye Store Manager Assistant)
  https://www.databricks.com/resources/architectures/retail-demand-forecasting-reference-architecture
- Databricks Blog — Real-Time Point-of-Sale Analytics with a Data Lakehouse
  https://www.databricks.com/blog/2021/09/09/real-time-point-of-sale-analytics-with-a-data-lakehouse.html
- AWS Cloud POS Reference Architecture (PDF)
  https://d1.awsstatic.com/architecture-diagrams/ArchitectureDiagrams/cloud-POS-reference-architecture.pdf
- AWS Analytics Reference Architecture — Streaming Analytics module
  https://aws-samples.github.io/aws-analytics-reference-architecture/high-level-design/modules/streaming/
- AWS Big Data Blog — Architectural Patterns for Real-Time Analytics using Kinesis Data Streams
  https://aws.amazon.com/blogs/big-data/architectural-patterns-for-real-time-analytics-using-amazon-kinesis-data-streams-part-1/
- Microsoft Cloud for Retail Reference Implementation
  https://github.com/microsoft/industry/blob/main/retail/referenceImplementation/README.md
- Microsoft Learn — Retail Channel Performance dashboard sobre Power BI
  https://learn.microsoft.com/en-us/dynamics365/fin-ops-core/dev-itpro/analytics/retail-channel-performance-dashboard-power-bi-data

**Fundamento conceptual de prescriptive analytics**
- McKinsey & Periscope — "Prescriptive analytics put powerful recommendations into the category manager's hands" (whitepaper PDF, 2017)
  https://www.mckinsey.com/~/media/McKinsey/Business%20Functions/Marketing%20and%20Sales/Periscope/Insights/White%20papers/Prescriptive%20analytics%20put%20powerful%20recommendations%20into%20the%20category%20managers%20hands/Retail_whitepaper_prescriptiveanalytics_mar2017.pdf

### 17.3 Antecedentes internos

- Caso de referencia: implementación funcionalmente análoga ejecutada por Christian Asmussen en Walmart, con resultados de cumplimiento documentados.
- Intento previo en Cencosur: no prosperó por falta de disciplina del cliente en sostener presupuestos granulares, no por limitaciones del modelo. Es una lección aplicada en el diseño de la PoC (acotación a un local + una categoría, reduciendo carga de mantención).
- Constitución MyAllSupport SpA, marzo 2026.

---

*Fin del documento.*
