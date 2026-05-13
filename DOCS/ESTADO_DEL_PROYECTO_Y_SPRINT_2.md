# Estado del proyecto e inicio del siguiente sprint

## Resumen ejecutivo

El proyecto ya pasó de documentación y scaffold a una base funcional sobre IRIS.

Hoy existe un flujo mínimo estable para:
- importar presupuesto diario,
- ingerir un evento POS,
- persistir Bronze, Silver y Gold,
- y validar el recorrido con un smoke test reproducible.

La prioridad inmediata es pasar de ese flujo técnico estable a la lógica de negocio del siguiente sprint: reglas, evaluación de desvíos y generación de recomendaciones.

## Objetivo del proyecto revisado

El objetivo de la PoC no cambió: monitorear el cumplimiento del presupuesto de venta en tiempo casi real y convertir desvíos operativos en acciones concretas para el administrador del local.

Lo que sí cambió es el nivel de madurez alcanzado. Hoy la PoC ya no está solo en una fase de esqueleto técnico; ya demuestra el circuito mínimo de datos, cálculo y decisión sobre IRIS. Por eso el foco siguiente deja de ser la persistencia base y pasa a ser la experiencia operativa completa: reglas más robustas, recomendaciones más ricas y trazabilidad del ciclo de acción.

## Avance logrado

### Infraestructura y entorno
- El repositorio quedó ordenado con toda la documentación en `DOCS/`.
- El entorno Docker de IRIS quedó operativo con el contenedor `iris111`.
- La carga de clases ObjectScript quedó automatizada con `scripts/load_classes.sh`.
- Se creó un runner real de pruebas en `scripts/run_tests.sh`.

### Modelo e implementación
- Se creó el scaffold inicial de clases para Bronze, Silver, Gold, maestros, reglas y operaciones.
- `Service.BudgetImportService` ya importa CSV de presupuesto y deja los valores disponibles para el flujo POS.
- `Process.POSProcessingBPL` ya procesa el evento POS completo y persiste el resultado en Gold.
- `Gold.CategoryPace` ya se valida con un smoke end-to-end sobre datos reales.

### Validación
- El smoke test ahora pasa de punta a punta.
- Se validó este recorrido:
  - presupuesto importado,
  - POS procesado,
  - registro Gold creado,
  - y conteos confirmados en la base.

## Lecciones aprendidas

### 1. En ObjectScript compilado conviene evitar accesores SQL frágiles en la ruta crítica
Durante la implementación apareció un fallo de runtime al leer resultsets SQL desde código compilado. La ruta se estabilizó simplificando la persistencia y evitando esa dependencia en el camino principal.

### 2. Las fechas deben normalizarse de forma consistente
Las clases persistentes y los filtros SQL funcionan mejor cuando las fechas se guardan como fecha lógica de IRIS y no como cadenas ISO mezcladas con lógica de persistencia.

### 3. Los smoke tests deben validar lo que realmente persiste
Las primeras aserciones fallaban porque verificaban identificadores generados o campos que no eran los correctos para la persistencia actual. El runner quedó alineado con los campos efectivamente guardados.

### 4. `iris session` no debe asumirse como fuente confiable de exit code
Para el runner se optó por validar la salida textual del smoke en lugar de confiar en un código de salida del proceso de sesión.

### 5. Conviene destrabar primero el flujo funcional y refinar después
La decisión de simplificar la ruta POS/Gold permitió pasar rápidamente a una base verificable. Eso deja ahora una plataforma estable para endurecer la lógica de negocio sin pelear con el entorno.

### 6. La prioridad de reglas debe quedar explícita
Cuando varias reglas pueden aplicar al mismo evento, la resolución no debe depender de orden accidental ni de supuestos implícitos. Centralizar la prioridad en el selector y validarla con smoke tests evita ambigüedades de negocio.

### 7. La recomendación necesita contexto, no solo un código de acción
Para que la recomendación sea útil en operación real, no basta con registrar la acción. También hace falta guardar severidad, umbral, valor observado, ventana evaluada y estado de ejecución para auditoría y seguimiento.

## Siguiente sprint: prioridad 2

La prioridad 2 es completar la lógica de negocio para que el sistema no solo persista eventos, sino que también detecte desvíos y genere recomendaciones accionables.

### Objetivo del sprint
Transformar el Gold ya persistido en decisiones operativas automáticas.

### Alcance técnico
1. Implementar reglas reales de pace y stockout.
2. Calcular desvíos con criterios consistentes sobre Gold.
3. Generar registros en `Ops.Recommendation` cuando una regla dispare.
4. Mantener auditabilidad del disparo de reglas y sus resultados.
5. Dejar un smoke test específico para la capa de reglas.

### Entregables esperados
- `Rules.PaceRules` con lógica real, no solo helpers triviales.
- `Process.POSProcessingBPL` evaluando reglas con datos persistidos.
- `Ops.Recommendation` poblada cuando el pace salga fuera de umbral.
- Un smoke test reproducible para reglas y recomendaciones.
- Documentación actualizada con el flujo de decisión.

### Orden recomendado de implementación
1. Completar `CountBelowThreshold` y `CountWithoutSales` con consultas reales.
2. Ajustar `EvaluateRules` para usar persistencia Gold y crear recomendaciones.
3. Conectar `ActionSelector` con reglas efectivas y mensajes finales claros.
4. Validar el flujo con un caso negativo y uno positivo.
5. Actualizar `scripts/run_tests.sh` para incluir una verificación de recomendaciones.

### Criterio de salida del sprint
El sprint queda completo cuando un evento POS fuera de pace genera una recomendación persistida y verificable, y el caso sano no dispara acciones.

## Estado resumido actual

- Base de infraestructura: lista.
- Ingesta presupuesto: lista.
- Ingesta POS: lista.
- Persistencia Gold: lista.
- Smoke tests: lista.
- Reglas y recomendaciones: en ejecución inicial.

## Progreso del Sprint 2

Sprint 2 ya arrancó y dejó estas piezas funcionales:

- `Rules.PaceRules` está en uso para identificar desvíos críticos.
- `Process.POSProcessingBPL` ya calcula desviación negativa compatible con el umbral de reglas.
- `CountBelowThreshold` y `CountWithoutSales` ya consultan Gold con umbrales separados para crítico y sostenido.
- `Ops.Recommendation` ya se persiste con metadatos de regla: ventana, umbral, valor observado, prioridad y pace relacionado.
- `Ops.Recommendation` ya se persiste con metadatos de regla y contexto operativo: severidad, mensaje de negocio y estado de ejecución.
- `Rules.ActionSelector` expone prioridad de regla explícita además de la acción que corresponde.
- `scripts/run_tests.sh` ya valida también los casos de recomendaciones críticas, sostenidas y de stockout, incluyendo metadatos, prioridad y un smoke específico de resolución de prioridades, además de budget, POS y Gold.

Siguiente ajuste dentro del sprint:

- refinar la lógica de sostenido para ventanas consecutivas si hace falta acercarla más al negocio,
- y, más adelante, añadir múltiples recomendaciones por evento si el negocio quiere trazabilidad completa de reglas concurrentes.

## Ajuste completado en esta iteración

- La recomendación ahora guarda `RuleWindowType`, `RuleThreshold`, `RuleObservedValue`, `RulePriority` y `RelatedPaceId`.
- La recomendación ahora guarda también `RuleSeverity`, `BusinessMessage` y `ExecutionState`.
- El smoke de reglas confirma tanto el tipo de regla como su prioridad y sus valores de contexto; el smoke de prioridad adicional verifica que la regla sostenida prevalece cuando sostenido y stockout aplican al mismo evento.
- La prioridad de regla quedó centralizada en `Rules.ActionSelector.GetPriority`.

## Cierre de esta iteración

Los dos puntos pedidos quedaron implementados y validados:

- Smoke de prioridad múltiple: listo.
- Recomendación enriquecida con contexto operativo: lista.

## Avance del siguiente sprint

La siguiente etapa ya comenzó con una base mínima de exposición operativa:

- `API.UIController` ya existe como controlador REST.
- Hay endpoints/herramientas para consultar health, pace, dashboard y recomendaciones pendientes.
- El feedback sobre recomendaciones ya puede actualizar estado, aceptación y notas.
- El smoke de API ya valida pace, recomendaciones, feedback y auditoría.
- La carpeta `frontend/` ya dejó de ser un placeholder y contiene una UI estática con consumo real de la API.

Lo que sigue en esta línea es endurecer la experiencia de consumo: separar mejor la lectura por endpoint, definir payloads más explícitos y conectar esta capa con una UI o consumidor real.

## Siguiente sprint propuesto

El siguiente sprint debería salir de la capa de reglas y cerrar el loop operativo con exposición y seguimiento.

### Objetivo del sprint
Exponer el estado de cumplimiento y las recomendaciones operativas para que el administrador del local y la supervisión puedan consumir el resultado del motor de reglas.

### Alcance técnico recomendado
1. Publicar endpoints REST para consultar el pace actual, las recomendaciones pendientes y el resumen por local.
2. Agregar un flujo mínimo de feedback sobre recomendaciones: aceptar, rechazar o marcar como ejecutada.
3. Persistir trazabilidad operacional adicional en `Ops.AuditLog` para cada consulta y cada cambio de estado.
4. Añadir una vista o consulta consolidada que permita ver el estado diario de una categoría sin reconstruirlo desde cero.
5. Crear smoke tests para API y feedback, usando los datos y recomendaciones ya validados.

### Entregables esperados
- API de consulta para pace y recomendaciones.
- Operación de feedback sobre recomendaciones.
- Auditoría de acciones y consultas.
- Smoke de API mínimo y reproducible.
- Documentación operativa de consumo.

### Criterio de salida del siguiente sprint
El sprint queda completo cuando el sistema no solo detecta desvíos y genera recomendaciones, sino que también permite consultarlas, responderlas y auditar su ciclo de vida sin intervención manual en la base.
