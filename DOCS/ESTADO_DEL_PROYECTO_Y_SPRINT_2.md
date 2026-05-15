# Estado actual del proyecto

## Resumen ejecutivo

IRIS111 ya pasó de una PoC de scaffold a una consola operativa sobre InterSystems IRIS con datos persistidos, trazabilidad y consumo web real.

Hoy el proyecto cubre el circuito principal de punta a punta:
- importación de presupuesto,
- ingesta POS,
- persistencia Bronze, Silver y Gold,
- panel operativo,
- vista de trx crudas,
- gráfica horaria con presupuesto,
- recomendaciones y feedback,
- y un batch reutilizable para corregir timestamps y reinyectar eventos cuando hace falta.

La prioridad actual dejó de ser “hacer funcionar la ruta básica” y pasó a ser consolidar la experiencia operativa, endurecer contratos, mantener la trazabilidad y cerrar los pendientes de validación de negocio.

## Avance a la fecha

### Infraestructura y entorno
- El entorno Docker de IRIS quedó operativo con el contenedor `iris111`.
- La carga de clases ObjectScript quedó automatizada con `scripts/load_classes.sh`.
- Existe un runner de pruebas en `scripts/run_tests.sh`.
- La documentación del proyecto está centralizada en `DOCS/` y la consola pública vive en `/csp/store-console/`.

### Modelo e implementación
- El presupuesto se importa y queda disponible para el recorrido POS.
- POS ingresa a Bronze y se procesa hacia Silver y Gold.
- `Silver.Sale` conserva el timestamp del payload normalizado desde la ingesta.
- `Gold.SalesCadence` trabaja con cadencia por local, categoría, SKU, fecha y hora.
- La categoría agregada sigue disponible con `__CATEGORY__` para mantener el consolidado operativo.
- La consola incluye:
  - panel principal,
  - vista de trx POS crudas,
  - gráfica horaria,
  - y feedback de recomendaciones.

### Correcciones recientes
- Se corrigió el timestamp del payload Bronze para que coincida con `ReceivedAt` cuando se ejecuta el batch de reparación.
- Se implementó `Service.POSReplayBatch` como servicio reutilizable para corregir Bronze y reinyectar Silver/Gold.
- Se agregó `scripts/replay_pos_batch.sh` como wrapper de ejecución.
- Se corrigió la sincronización entre la fecha del panel y la fecha usada por la vista de cadencia.
- Se añadió la vista `Grafico` con filtros de local, fecha, categoría y SKU.
- La gráfica incluye unidades, valor y presupuesto esperado por hora.
- Se corrigió el error HTTP del gráfico al alinear la lectura de parámetros de la consola CSP.

### Validación realizada
- Compilación de clases validada con `./scripts/load_classes.sh`.
- Se verificó la respuesta del endpoint de ventas horarias desde la consola CSP.
- Se verificó la respuesta del endpoint de presupuestos con filtros de fecha, local y categoría.
- Se validó que la consola pública responde en `/csp/store-console/`.
- Se comprobó que la vista de gráfica ya recibe categoría y SKU correctamente.

## Aprendizajes del sprint

### 1. La capa de consumo debe validarse en la ruta real del navegador
La consola funcionaba en código, pero el error real apareció cuando el navegador llamó la ruta CSP con sus propios parámetros. La lección es directa: no alcanza con probar helpers aislados; hay que validar el contrato HTTP que ve la UI.

### 2. Los filtros de operación no pueden depender de supuestos implícitos
La gráfica y la consulta de presupuesto mostraron que un filtro vacío o un nombre de parámetro distinto alcanza para romper la experiencia. Conviene centralizar la lectura de parámetros y definir fallback explícito.

### 3. La cadencia operativa necesita dos niveles de contexto
La operación diaria no se resuelve sólo con la categoría agregada. Hace falta distinguir entre el consolidado de categoría y el detalle por SKU para que el panel, la gráfica y el traceo de POS no se contaminen entre sí.

### 4. El timestamp de negocio y el timestamp de recepción no son intercambiables
Cuando Bronze guardaba un timestamp distinto al recibido, el replay y la auditoría quedaban desalineados. Alinear el payload con `ReceivedAt` simplifica la trazabilidad y hace que la reinyectación sea reproducible.

### 5. El presupuesto sirve como referencia visual, no como sustituto del dato real
La gráfica mejoró cuando el presupuesto se usó como línea esperada por hora y no como una fuente que mezcla contexto operativo con cálculo visual.

### 6. Los smoke tests deben cubrir datos reales y rutas reales
El proyecto avanzó cuando las validaciones empezaron a leer el estado persistido y los endpoints reales, no sólo a verificar mensajes visuales o helpers internos.

### 7. Un batch de reparación debe ser reusable
La corrección del Bronze no podía quedar como un parche manual. Convertirla en servicio batch y script de ejecución dejó una herramienta mantenible para futuras correcciones masivas.

## Pendientes

### Pendientes funcionales
- Revisar si la lógica de sostenido necesita una ventana consecutiva más estricta, según criterio de negocio.
- Definir si el negocio quiere múltiples recomendaciones por evento o una sola por prioridad dominante.
- Confirmar si la gráfica debe ofrecer más métricas derivadas además de unidades, valor y presupuesto.

### Pendientes técnicos
- Ampliar smoke tests para cubrir la consola pública completa, incluyendo la vista de gráfica y la vista de trx crudas.
- Consolidar pruebas de contrato para endpoints críticos de la API.
- Revisar si conviene normalizar más nombres de parámetros entre frontend y backend para reducir riesgo de regresiones.
- Documentar mejor el flujo de reparación masiva de Bronze en el manual operativo.

### Pendientes de documentación
- Actualizar la arquitectura ajustada si se agregan nuevas rutas o nuevas vistas operativas.
- Mantener sincronizado el README principal con la consola pública y los comandos reales de ejecución.
- Registrar en la documentación operativa el flujo de replay batch y el criterio para usarlo.

## Estado resumido

- Ingesta de presupuesto: lista.
- Ingesta POS: lista.
- Persistencia Bronze/Silver/Gold: lista.
- Recomendaciones y feedback: lista.
- Consola pública: lista.
- Vista de trx crudas: lista.
- Gráfica horaria con presupuesto: lista.
- Replay batch de corrección: lista.
- Pendientes de endurecimiento y validación adicional: en curso.

## Cierre

La PoC ya demuestra el circuito operativo central. Lo que sigue no es rearmar la base, sino consolidar calidad: validar más contratos, afinar reglas de negocio y mantener la trazabilidad clara para operación y soporte.
