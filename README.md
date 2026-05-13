# IRIS111

IRIS111 es una PoC sobre InterSystems IRIS para monitorear el cumplimiento del presupuesto de venta en tiempo casi real y convertir desvíos operativos en acciones concretas para el administrador del local.

La documentación detallada del proyecto vive en [DOCS/README.md](DOCS/README.md).

## Quick links

- [Documentación del proyecto](DOCS/README.md)
- [Arquitectura ajustada](DOCS/ARQUITECTURA_AJUSTADA_DOCKER_IRIS111.md)
- [Arquitectura técnica y plan de sprints](DOCS/Arquitectura_Tecnica_PoC_IRIS_Plan_Sprints.md)
- [Documento conceptual](DOCS/Documento_Conceptual_PoC_Cumplimiento_Presupuesto_Tiempo_Real_Grupo_Exito.md)
- [Requerimientos Copilot](DOCS/REQUERIMIENTOS_COPILOT_PARALELO_PoC.md)
- [Prompts listos para Copilot](DOCS/COPILOT_PROMPTS_LISTOS.md)

## English

IRIS111 is a proof of concept on InterSystems IRIS to monitor sales budget compliance in near real time and turn operational deviations into concrete actions for the store manager.

Detailed project documentation lives in [DOCS/README.md](DOCS/README.md).

## IRIS environment

The local IRIS environment is described in [DOCS/ARQUITECTURA_AJUSTADA_DOCKER_IRIS111.md](DOCS/ARQUITECTURA_AJUSTADA_DOCKER_IRIS111.md) and can be started from this repository with:

This workspace defaults to the locally available image `intersystemsdc/irishealth-ml-community:latest` in [.env.docker](.env.docker) so the container can start without pulling a missing tag.

```bash
./scripts/setup_iris.sh
docker compose --env-file .env.docker up -d
```

Useful local commands:

```bash
./scripts/load_classes.sh
./scripts/run_tests.sh all
python3 ./scripts/mock_data_loader.py
```

## UI

The operational console is available in `frontend/` for local use, and the same screen is exposed from IRIS as the public web app `/csp/store-console/`. When loaded from IRIS CSP, it targets the REST controller at `/csp/store-console`.