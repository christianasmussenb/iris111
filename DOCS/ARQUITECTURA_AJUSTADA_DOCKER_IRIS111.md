# Arquitectura Ajustada: Workspace Local + Docker IRIS para iris111
## Flujo actual de despliegue y desarrollo en IRIS111

**Versión:** 2.0 (Alineada con el runbook actual del repositorio)  
**Fecha:** Mayo 2026  
**Cambio:** Flujo actual con workspace local, Docker IRIS reproducible y scripts de bootstrap/runbook

---

## Resumen operativo actual

El repositorio se opera hoy desde el workspace local con estos puntos de entrada:

- Imagen base: `intersystemsdc/irishealth-ml-community:latest`
- Bootstrap del entorno: `./scripts/setup_iris.sh`
- Arranque del contenedor principal: `docker compose --env-file .env.docker up -d`
- Arranque del contenedor alterno: `./scripts/start_iris_alt.sh`
- Puerto alterno por defecto: `52774`
- Carga de clases: `./scripts/load_classes.sh`
- Carga de maestros: `./scripts/load_mock_master_data.sh`
- Carga del mes mock de mayo: `./scripts/load_may_2026_mock_data.sh`
- Consola operativa: `/csp/store-console/`

```mermaid
flowchart LR
  VSCode[VS Code + Copilot]
  Repo[Workspace /Users/cab/VSCODE/iris111]
  Compose[docker compose --env-file .env.docker up -d]
  Alt[./scripts/start_iris_alt.sh\n(puerto 52774 por defecto)]
  IRIS[IRIS Community ML\nintersystemsdc/irishealth-ml-community:latest]
  Bootstrap[setup_iris.sh\nload_classes.sh\nload_mock_master_data.sh\nload_may_2026_mock_data.sh]
  Console[/csp/store-console/]

  VSCode --> Repo
  Repo --> Compose
  Repo --> Alt
  Repo --> Bootstrap
  Compose --> IRIS
  Alt --> IRIS
  IRIS --> Console
```

> Nota: las secciones siguientes conservan contexto histórico del flujo anterior con Git dentro del contenedor. El runbook vigente es el bloque de arriba y el que se refleja en el README principal.

---

## 1. Estructura Docker: Contenedor iris111 + Volúmenes

### 1.1 Crear el contenedor iris111

**Comando exacto:**

```bash
# En tu laptop/host machine

# Supuesto: Ya tienes la imagen bajada
docker images | grep iris-community
# Debe mostrar: intersystemsdc/iris-community:2024.1-final (o similar)

# Crear contenedor iris111 con volúmenes montados
docker run -d \
  --name iris111 \
  -p 52773:52773 \
  -e IRIS_PASSWORD=Demo123456! \
  -v /home/user/iris-poc/code:/iris/code \
  -v /home/user/iris-poc/data:/iris/data \
  -v /home/user/iris-poc/tests:/iris/tests \
  -v /home/user/iris-poc/frontend:/iris/frontend \
  intersystemsdc/iris-community:2024.1-final

# Verificar que corre
docker ps | grep iris111
# Debe mostrar: iris111, puerto 52773 mapeado

# Verificar acceso a Management Portal
curl http://localhost:52773/csp/system/
# Debe devolver HTML del portal
```

**Explicación de volúmenes:**

| Host Path | Container Path | Propósito | Quién accede |
|---|---|---|---|
| `/home/user/iris-poc/code` | `/iris/code` | ObjectScript classes, BPL | IRIS + VS Code |
| `/home/user/iris-poc/data` | `/iris/data` | CSV masters, sample boletas | IRIS + scripts |
| `/home/user/iris-poc/tests` | `/iris/tests` | Test scripts | IRIS + Copilot |
| `/home/user/iris-poc/frontend` | `/iris/frontend` | React code | Node.js (S4) |

**Ventaja:** Código en volumen compartido = visible para Git, VS Code, Copilot todo a la vez.

---

## 2. Workflow: Donde vive el código

### 2.1 Estructura de directorios (AJUSTADA)

```
Host Machine (laptop/VM)
└── /home/user/iris-poc/
    ├── code/                          ← VOLUMEN compartido con /iris/code en contenedor
    │   ├── objectscript/
    │   │   ├── Bronze/
    │   │   ├── Silver/
    │   │   ├── Gold/
    │   │   ├── MD/
    │   │   ├── Inbound/
    │   │   ├── Pipeline/
    │   │   ├── Decision/
    │   │   ├── API/
    │   │   └── Config/
    │   ├── scripts/
    │   │   ├── load_classes.sh
    │   │   ├── run_tests.sh
    │   │   ├── setup_iris.sh
    │   │   └── mock_data_loader.py
    │   └── .git/                      ← Git repo en HOST (no en contenedor)
    ├── data/                          ← VOLUMEN compartido con /iris/data
    │   ├── skus.csv
    │   ├── stores.csv
    │   ├── budgets.csv
    │   └── pos_feed/
    ├── tests/                         ← VOLUMEN compartido con /iris/tests
    │   └── objectscript/
    │       ├── test_bronze.script
    │       ├── test_silver.script
    │       └── ...
    ├── frontend/                      ← VOLUMEN compartido (S4)
    │   └── src/
    ├── docs/
    ├── config.yml
    ├── .gitignore
    ├── README.md
    └── .env.docker                    ← New: vars para contenedor
```

### 2.2 ¿Dónde está Git?

**Opción A (RECOMENDADA para Copilot):** Git en HOST

```bash
# En host (/home/user/iris-poc)
git init
git remote add origin https://github.com/username/iris-poc.git

# Copilot trabaja dentro del contenedor
# Código se escribe en /iris/code (volumen compartido)
# Desde host, ves los cambios en /home/user/iris-poc/code
# Haces commit/push desde host

# Ventaja: Git está fuera, volumen es limpio
# Desventaja: Copilot no puede hacer git commits directamente
```

**Opción B:** Git en CONTENEDOR (si quieres que Copilot pueda hacer commits)

```bash
# Dentro del contenedor
docker exec iris111 bash
cd /iris/code
git init
git remote add origin https://github.com/username/iris-poc.git

# Copilot dentro del contenedor puede hacer git commits
# Pero requiere montar .git en volumen
# Más complejo

# Ventaja: Copilot full autonomy
# Desventaja: Más overhead, posibles conflictos de permisos
```

**ELEGIR OPCIÓN A (Git en Host).**

---

## 3. Cómo Copilot Trabaja Dentro del Contenedor

### 3.1 Flujo de Desarrollo (Copilot-A, ejemplo Bronze)

```bash
# Lunes 10:00, Copilot-A comienza

# PASO 1: Conectar VS Code al contenedor iris111
# En VS Code en HOST:
#   Instalar extensión: "Dev Containers" (Microsoft)
#   Instalar extensión: "GitHub Copilot"
#   Command Palette (Ctrl+Shift+P) → "Dev Containers: Attach to Running Container"
#   Seleccionar: iris111
#   ✓ VS Code se conecta al contenedor

# PASO 2: Abrir Terminal dentro del contenedor (desde VS Code)
# Terminal → New Terminal (automáticamente abre una shell dentro del contenedor)

# PASO 3: Dentro del contenedor, crear rama feature
cd /iris/code
git status
# ✗ Error: git not installed in container? (posible)

# SOLUCIÓN: Git en HOST, no en contenedor
# En LUGAR de: git checkout -b feature/s1-bronze-model
# HACER: (desde HOST)
cd /home/user/iris-poc
git checkout -b feature/s1-bronze-model
# Ahora la rama está activa en HOST
# El volumen /iris/code ve el mismo contenido
```

### 3.2 Copilot Trabaja Dentro, Git Opera en Host

**Workflow Exacto:**

```bash
# SEMANA ANTERIOR (Host)
cd /home/user/iris-poc
git init
git remote add origin https://github.com/username/iris-poc.git
git checkout -b main
git commit --allow-empty -m "Initial commit"
git push -u origin main

# LUNES 09:30 (Host)
git checkout -b feature/s1-bronze-model
# Ahora existe la rama en host

# LUNES 10:00 (Copilot-A en Contenedor)
# Abre VS Code → "Attach to iris111" container
# Terminal → new terminal (automáticamente dentro del contenedor)

# Dentro del contenedor, crea archivo ObjectScript
cd /iris/code/objectscript/Bronze/
# Usa Copilot: Ctrl+Shift+A → pega prompt
# Copilot genera: POSEvent.cls
# Copia el código al archivo

cat > POSEvent.cls << 'EOF'
Class Bronze.POSEvent Extends %Persistent {
  Property sourceId As %String;
  Property receivedAt As %TimeStamp;
  ...
}
EOF

# Guarda el archivo (Ctrl+S en VS Code)
# El archivo está en /iris/code/objectscript/Bronze/POSEvent.cls
# También visible en host: /home/user/iris-poc/code/objectscript/Bronze/POSEvent.cls

# Compila en IRIS (via Management Portal o script dentro del contenedor)
docker exec iris111 bash -c "cd /iris/code && ./scripts/load_classes.sh"
# ✓ POSEvent.cls compila en IRIS

# LUNES EOD (Host)
cd /home/user/iris-poc
git add code/objectscript/Bronze/POSEvent.cls
git commit -m "Sprint 1: Bronze.POSEvent class"
git push origin feature/s1-bronze-model

# FRIDAY (Host)
git checkout develop
git pull origin develop
git merge --squash feature/s1-bronze-model
git commit -m "Sprint 1: Bronze layer ..."
git push origin develop
```

---

## 4. Ajustes al Workflow de Copilot Agents

### 4.1 Cambios en el proceso (vs. documento anterior)

**ANTES (código en host VM):**
```
Copilot genera código 
→ Guarda en objectscript/*.cls en VM
→ Copilot hace git commit desde VM
→ Push desde VM
```

**AHORA (código dentro de contenedor):**
```
Copilot genera código 
→ Guarda en /iris/code/objectscript/*.cls dentro del contenedor
→ Volumen compartido hace visible el código en HOST
→ HUMANO hace git commit/push desde HOST
→ Copilot NO toca Git (no instalado en contenedor)
```

### 4.2 Roles ajustados

| Rol | Antes | Ahora |
|---|---|---|
| **Copilot-A/B/C** | Genera código + git commit | Genera código (en /iris/code) |
| **Human (Code Reviewer)** | Revisa + merge | Revisa + git commit + merge |
| **Human (DevOps)** | N/A | Maneja contenedor (docker exec, logs, restart) |

**Implicación:** Human hace MÁS trabajo con Git, pero Copilot focaliza en código (más eficiente).

### 4.3 Daily Workflow Ajustado (Copilot-A, Lunes-Friday)

```
LUNES 10:00
Copilot-A abre VS Code
→ "Attach to Container iris111"
→ Terminal abre dentro del contenedor
→ Navega a /iris/code/objectscript/Bronze/
→ Copilot genera POSEvent.cls (prompt de COPILOT_PROMPTS_LISTOS.md)
→ Código guardado en /iris/code/objectscript/Bronze/POSEvent.cls
→ Compila: docker exec iris111 bash -c "cd /iris/code && ./scripts/load_classes.sh"
→ ✓ Compilado

LUNES EOD
Human (en HOST) hace:
git add code/objectscript/Bronze/POSEvent.cls
git commit -m "Sprint 1: Bronze.POSEvent class"
git push origin feature/s1-bronze-model

WEDNESDAY-THURSDAY
Copilot-A continúa generando (POSService.cls, test script)
Human hace git add/commit cada EOD

FRIDAY 14:00
Human hace merge (como antes):
git checkout develop
git merge --squash feature/s1-bronze-model
git commit -m "Sprint 1: ..."
git push origin develop
```

---

## 5. Comando setup.sh Ajustado (Para Contenedor)

### 5.1 Script que corre DENTRO del contenedor

**Archivo: `/home/user/iris-poc/code/scripts/setup_iris.sh`**

```bash
#!/bin/bash
# Corre DENTRO del contenedor iris111

set -e

echo "=== Setup IRIS dentro del contenedor ==="

# 1. Verificar que IRIS corre
echo "Verificando IRIS..."
curl -s http://localhost:52773/csp/system/ > /dev/null && echo "✓ IRIS accesible" || echo "✗ IRIS NO accesible"

# 2. Crear carpetas necesarias
echo "Creando carpetas..."
mkdir -p /iris/data/pos_feed
mkdir -p /iris/code/{objectscript,tests,scripts}

# 3. Cargar todas las clases ObjectScript
echo "Cargando clases ObjectScript..."
cd /iris/code
# (Script que compile todas las clases desde objectscript/)
# Pseudocódigo:
for file in objectscript/**/*.cls; do
    echo "Compilando $file..."
    # Llamar a IRIS compile API
done

# 4. Cargar maestros (CSVs)
echo "Cargando maestros..."
python3 scripts/mock_data_loader.py
# Genera CSVs en /iris/data/

# 5. Importar CSVs a IRIS
echo "Importando CSVs a IRIS..."
# (SQL INSERT o script IRIS)

# 6. Verificar
echo "Verificando..."
docker exec iris111 bash -c "irissession IRISPRODUCTION -U _SYSTEM -P Demo123456! -c 'do ##class(Bronze.POSEvent).Extent()'"

echo "=== Setup completo ==="
```

**Cómo ejecutar (desde HOST):**

```bash
cd /home/user/iris-poc
docker exec iris111 bash /iris/code/scripts/setup_iris.sh
# ✓ Corre dentro del contenedor
```

---

## 6. Estructura Actualizada en el Contenedor

### 6.1 Layout dentro de iris111 (IMPORTANTE)

```
Dentro del contenedor iris111:

/iris/
├── code/                       ← VOLUMEN /iris/code ↔ HOST /home/user/iris-poc/code
│   ├── objectscript/
│   │   ├── Bronze/
│   │   │   ├── POSEvent.cls
│   │   │   ├── _MODULE_INFO.md
│   │   │   └── .git  ← NO (git en host)
│   │   ├── Silver/
│   │   ├── Gold/
│   │   ├── MD/
│   │   ├── API/
│   │   └── Config/
│   ├── scripts/
│   │   ├── load_classes.sh
│   │   ├── run_tests.sh
│   │   ├── setup_iris.sh
│   │   └── mock_data_loader.py
│   └── .gitignore             ← Visible aquí pero versionado en HOST
├── data/                       ← VOLUMEN /iris/data ↔ HOST /home/user/iris-poc/data
│   ├── skus.csv
│   ├── stores.csv
│   ├── categories.csv
│   ├── budgets.csv
│   └── pos_feed/
├── tests/                      ← VOLUMEN /iris/tests ↔ HOST /home/user/iris-poc/tests
│   └── objectscript/
│       ├── test_bronze.script
│       ├── test_silver.script
│       └── ...
└── ... (otros directorios IRIS)

Fuera del contenedor (HOST):

/home/user/iris-poc/
├── code/                       ← Volumen compartido (mismo contenido que /iris/code en contenedor)
├── data/                       ← Volumen compartido
├── tests/                      ← Volumen compartido
├── frontend/                   ← Volumen compartido
├── docs/                       ← Solo en HOST (no necesita estar en contenedor)
├── config.yml                  ← Copyado al contenedor en setup
├── .git/                       ← SOLO EN HOST (Git aquí)
├── .gitignore
└── README.md
```

---

## 7. Commands Cheat Sheet (Docker + Contenedor iris111)

### 7.1 Gestión del contenedor

```bash
# Crear contenedor (one-time)
docker run -d \
  --name iris111 \
  -p 52773:52773 \
  -e IRIS_PASSWORD=Demo123456! \
  -v /home/user/iris-poc/code:/iris/code \
  -v /home/user/iris-poc/data:/iris/data \
  -v /home/user/iris-poc/tests:/iris/tests \
  intersystemsdc/iris-community:2024.1-final

# Ver estado
docker ps | grep iris111

# Ver logs (troubleshooting)
docker logs iris111
docker logs -f iris111  # Follow (Ctrl+C para salir)

# Entrar en terminal interactiva
docker exec -it iris111 bash

# Reiniciar contenedor
docker restart iris111

# Detener contenedor
docker stop iris111

# Iniciar contenedor (si estaba stopped)
docker start iris111

# Eliminar contenedor (¡cuidado! Pierde todo excepto volúmenes)
docker rm iris111
```

### 7.2 Desarrollo (dentro del contenedor, desde VS Code)

```bash
# Abierto VS Code → Attach to iris111

# Terminal dentro del contenedor:
cd /iris/code

# Compilar clases
./scripts/load_classes.sh

# Correr tests
./scripts/run_tests.sh bronze

# Cargar mock data
python3 scripts/mock_data_loader.py

# Acceder a IRIS session
irissession IRISPRODUCTION -U _SYSTEM -P Demo123456!
# Dentro de IRIS:
do ##class(Bronze.POSEvent).Extent()  # Ver # registros
SELECT * FROM Bronze.POSEvent LIMIT 5; # Query
```

### 7.3 Git (en HOST, no en contenedor)

```bash
# Todos estos comandos en HOST (/home/user/iris-poc)

# Crear rama
git checkout -b feature/s1-bronze-model

# Ver cambios (archivos en /iris/code están visibles via volumen)
git status
# Mostrará: modified: code/objectscript/Bronze/POSEvent.cls

# Commit
git add code/objectscript/Bronze/POSEvent.cls
git commit -m "Sprint 1: Bronze.POSEvent class"

# Push
git push origin feature/s1-bronze-model

# Merge (Friday)
git checkout develop
git merge --squash feature/s1-bronze-model
git commit -m "Sprint 1: ..."
git push origin develop

# Tag release
git tag -a v0.1.0-s1 -m "Sprint 1 complete"
git push origin v0.1.0-s1
```

---

## 8. Impacto en GitHub Copilot: Resumen

### 8.1 ¿Cómo Copilot ve el entorno?

**VS Code Attached to iris111:**
- Abre terminal: está dentro del contenedor (/iris path visible)
- Abre archivo: /iris/code/objectscript/Bronze/POSEvent.cls
- Genera código: se guarda en /iris/code/...
- No accede a Git (no está en contenedor)
- Sí accede a IRIS (vía localhost:52773, puerto mapeado desde host)

### 8.2 Ventajas

✅ Entorno limpio (contenedor aislado)  
✅ Reproducible (mismo entorno para todo el equipo)  
✅ Código compilado y testeado inmediatamente dentro del contenedor  
✅ Copilot focalizado en código (no en git management)  
✅ Escalable (agregar más contenedores si necesario)

### 8.3 Desventajas

❌ Human hace más trabajo con Git (pero es trivial)  
❌ Git commands se corren en HOST, no en contenedor  
❌ Requiere VS Code con extensión "Dev Containers" (muy estándar hoy)

---

## 9. Ajustes a Documentos Anteriores

### 9.1 PASO_A_PASO_ECHAR_A_ANDAR.md → Sección NEW

**Reemplazar "Tarea 1: Preparar Infraestructura GCP" con:**

```markdown
### Tarea 1: Crear Contenedor iris111

#### 1.1 Prerequisitos
- Docker instalado en host (docker version)
- Imagen IRIS Community ya bajada (docker images | grep iris-community)

#### 1.2 Crear contenedor
docker run -d \
  --name iris111 \
  -p 52773:52773 \
  -e IRIS_PASSWORD=Demo123456! \
  -v /home/user/iris-poc/code:/iris/code \
  -v /home/user/iris-poc/data:/iris/data \
  -v /home/user/iris-poc/tests:/iris/tests \
  intersystemsdc/iris-community:2024.1-final

#### 1.3 Verificar
docker ps | grep iris111  # ✓ Debe estar RUNNING
curl http://localhost:52773/csp/system/  # ✓ Debe devolver HTML
```

### 9.2 ARQUITECTURA_TECNICA_PoC_IRIS_Plan_Sprints.md → Nueva Sección 1.3

**Agregar: "1.3 — Despliegue en Contenedor Docker"**

```markdown
## 1.3 Despliegue en Contenedor Docker

La solución corre completamente dentro de un contenedor Docker llamado `iris111`.

Volúmenes mapeados (HOST ↔ Contenedor):
- /home/user/iris-poc/code ↔ /iris/code (ObjectScript classes)
- /home/user/iris-poc/data ↔ /iris/data (CSV masters, sample data)
- /home/user/iris-poc/tests ↔ /iris/tests (test scripts)

Implicación para desarrollo con Copilot:
- Copilot genera código en /iris/code (visible en host via volumen)
- Git está en HOST (no en contenedor)
- Human maneja git commit/push desde host
- IRIS Management Portal en http://localhost:52773/csp/system/

Ventaja: Entorno reproducible, escalable, aislado.
```

### 9.3 REQUERIMIENTOS_COPILOT_PARALELO_PoC.md → Sección 2.2 (Git)

**Actualizar: "2.2 Reglas de branching"**

```markdown
## 2.2 Reglas de Branching

Git está en HOST (/home/user/iris-poc/.git), NO en contenedor.

Copilot genera código en /iris/code (dentro del contenedor).
Human hace git commit/push desde HOST.

Flujo:
1. Human crea rama: git checkout -b feature/s1-bronze-model (en HOST)
2. Copilot genera código en /iris/code (dentro contenedor via VS Code attach)
3. Volumen compartido hace visible cambios en HOST /home/user/iris-poc/code
4. Human commit/push: git add + commit + push (en HOST)
5. (Copilot NO ejecuta comandos git)
```

---

## 10. Paso a Paso: Primer Desarrollo (Copilot-A, Lunes)

### 10.1 Setup (Humano, Viernes EOD)

```bash
# Host
mkdir -p /home/user/iris-poc/{code,data,tests,frontend}
cd /home/user/iris-poc

# Crear git repo
git init
git config user.name "Development Team"
git config user.email "dev@example.com"

# Crear contenedor iris111
docker run -d \
  --name iris111 \
  -p 52773:52773 \
  -e IRIS_PASSWORD=Demo123456! \
  -v /home/user/iris-poc/code:/iris/code \
  -v /home/user/iris-poc/data:/iris/data \
  -v /home/user/iris-poc/tests:/iris/tests \
  intersystemsdc/iris-community:2024.1-final

# Verificar
docker ps | grep iris111
curl http://localhost:52773/csp/system/

# Primer commit
git add .
git commit --allow-empty -m "Initial: iris111 setup"
git remote add origin https://github.com/username/iris-poc.git
git push -u origin main
```

### 10.2 Lunes 09:30 (Setup Local, Copilot-A)

```bash
# Humano (Host)
cd /home/user/iris-poc
git checkout -b feature/s1-bronze-model
# Rama creada en host

# Copilot-A (VS Code)
1. Instalar extensión "Dev Containers"
2. Instalar extensión "GitHub Copilot"
3. Command Palette → "Dev Containers: Attach to Running Container"
4. Seleccionar iris111
5. ✓ VS Code conectado al contenedor

# Copilot-A (Terminal dentro del contenedor)
Terminal → New Terminal (automáticamente abre bash dentro de iris111)
cd /iris/code
pwd  # /iris/code ✓

# Crear estructura
mkdir -p objectscript/Bronze tests/objectscript

# Verificar volumen
ls -la  # Debe ser visible desde HOST también
```

### 10.3 Lunes 10:00 (Dev Time, Copilot-A)

```bash
# Copilot-A (dentro contenedor, en VS Code)

# Crear archivo
cd /iris/code/objectscript/Bronze
cat > POSEvent.cls << 'EOF'
Class Bronze.POSEvent Extends %Persistent {
  ... (Copilot genera via prompt)
}
EOF

# Guarda (Ctrl+S)

# Compilar
cd /iris/code
docker exec iris111 bash -c "cd /iris/code && ./scripts/load_classes.sh"
# O si está en el shell del contenedor:
./scripts/load_classes.sh

# ✓ Compilado sin errores

# Ver desde HOST que el archivo está ahí
# (En otra terminal en HOST)
ls -la /home/user/iris-poc/code/objectscript/Bronze/
# POSEvent.cls ✓ visible
```

### 10.4 Lunes EOD (Commit, Humano en Host)

```bash
# Humano (Host)
cd /home/user/iris-poc
git status
# modified: code/objectscript/Bronze/POSEvent.cls ✓

git add code/objectscript/Bronze/
git commit -m "Sprint 1: Bronze.POSEvent class generated by Copilot"
git push origin feature/s1-bronze-model

# ✓ Commit en feature branch
```

---

## 11. FAQ: Docker + Copilot

**P: ¿Dónde escribe Copilot el código?**  
R: En /iris/code (dentro del contenedor). El volumen lo hace visible en /home/user/iris-poc/code en el host.

**P: ¿Copilot puede hacer git commit?**  
R: No. Git está en host, no en contenedor. Human hace commit desde host.

**P: ¿Se pierde código si detengo el contenedor?**  
R: No. Código está en volumen (/home/user/iris-poc/code), persiste aunque detengas el contenedor.

**P: ¿Qué pasa si elimino el contenedor?**  
R: `docker rm iris111` elimina el contenedor pero NO los volúmenes. Código sigue ahí. Puedes recrear el contenedor con el mismo docker run command y verá el código anterior.

**P: ¿Puedo tener múltiples contenedores (iris111, iris222)?**  
R: Sí, pero complica las cosas. Para esta PoC: 1 contenedor iris111 suficiente.

**P: ¿Cómo accedo a IRIS desde fuera del contenedor?**  
R: Management Portal en http://localhost:52773/csp/system/ (puerto mapeado a host).

**P: ¿Puedo usar Docker Compose en lugar de docker run?**  
R: Sí, sería más limpio (docker-compose.yml). Pero para PoC, docker run + script bash suficiente.

---

## 12. Docker Compose (Alternativa, Opcional)

**Si quieres gestionar iris111 más fácilmente, crea:**

**Archivo: `/home/user/iris-poc/docker-compose.yml`**

```yaml
version: '3.8'

services:
  iris:
    image: intersystemsdc/iris-community:2024.1-final
    container_name: iris111
    ports:
      - "52773:52773"
    environment:
      - IRIS_PASSWORD=Demo123456!
    volumes:
      - ./code:/iris/code
      - ./data:/iris/data
      - ./tests:/iris/tests
```

**Usar:**

```bash
# En /home/user/iris-poc
docker-compose up -d  # Crea iris111
docker-compose down   # Detiene
docker-compose logs -f  # Ver logs
```

---

## Conclusión

**Resumen del cambio arquitectónico:**

```
ANTES:                          AHORA:
Code en VM                      Code en Docker contenedor (iris111)
Git en VM                       Git en HOST
Copilot en VS Code local        Copilot en VS Code attached to iris111
Development ad-hoc              Development reproducible + escalable
```

**Para los 3 agentes Copilot:**
- Todos trabajan dentro del mismo contenedor iris111
- Código en volumen compartido (visible en host para Git)
- Human maneja Git desde host
- Compile/test rápido (todo en el mismo docker)

**El PASO_A_PASO se simplifica:**
- No necesitas VM en GCP (o lo haces en una VM mucho más pequeña, solo para host)
- Docker + volúmenes hacen todo portable
- Mismo entorno para todos (3 agentes ven exactamente lo mismo)

¿Preguntas sobre la arquitectura ajustada?

