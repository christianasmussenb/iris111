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

To run a second IRIS instance beside an existing one, use the alternate launcher. It defaults to host port `52774`, container name `iris111-alt`, and the same workspace mount:

```bash
./scripts/start_iris_alt.sh
```

If you need to override the host port or the container name, pass environment variables or flags:

```bash
IRIS_PORT=52775 IRIS_CONTAINER_NAME=iris111-lab ./scripts/start_iris_alt.sh
```

## Run on another Docker with IRIS

Use this flow when you already have another IRIS container running in the same Docker host and want to bring IRIS111 up beside it.

1. Verify that Docker is running and that the target host port is free. The alternate launcher defaults to port `52774`, which avoids the standard IRIS port mapping.
2. If needed, edit `docker-compose.yml` or pass environment variables so the container uses the image `intersystemsdc/irishealth-ml-community:latest`.
3. Run `./scripts/setup_iris.sh` once to create or refresh `.env.docker` with the current workspace defaults.
4. Start the secondary container with `./scripts/start_iris_alt.sh`.
5. If you need a different name or port, override them with `IRIS_CONTAINER_NAME` and `IRIS_PORT`.
6. Load the classes with `./scripts/load_classes.sh`.
7. Load the master data with `./scripts/load_mock_master_data.sh`.
8. Load the May 2026 mock month with `./scripts/load_may_2026_mock_data.sh`.
9. Open the console at `/csp/store-console/` and verify the chart, the POS trace view, the loaded-data tab, and the SKU-by-category tab.

Operational notes:

- The alternate launcher keeps the workspace mount and the IRIS app layout aligned with the local repo.
- The May mock loader is repeatable and regenerates the data before importing, so it can be used again after a reset or replay.
- The chart now follows the active sales window and the budget projection, so the documentation and the data generator must stay aligned.

Useful local commands:

```bash
./scripts/load_classes.sh
./scripts/load_mock_master_data.sh
./scripts/load_may_2026_mock_data.sh
./scripts/run_tests.sh all
python3 ./scripts/mock_data_loader.py
```

## UI

The operational console is available in `frontend/` for local use, and the same screen is exposed from IRIS as the public web app `/csp/store-console/`. When loaded from IRIS CSP, it targets the REST controller at `/csp/store-console`.

The current console includes the main operational panel, raw POS trace view, hourly chart with budget overlay, and recommendation feedback flow.

## Repair batch

If Bronze payload timestamps need to be corrected and replayed into Silver/Gold, use the reusable batch service via:

```bash
./scripts/replay_pos_batch.sh dry-run
./scripts/replay_pos_batch.sh apply
```