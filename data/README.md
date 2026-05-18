# Data folder

This folder stores the input files used by the IRIS111 PoC environment.

The local mock data loader writes seed files here:

- `skus.csv`
- `categories.csv`
- `stores.csv`
- `prices.csv`
- `budgets.csv`
- `budgets_hourly.csv` (auxiliary projection for hourly comparison)
- `pos_feed/`

The POS feed now includes a month of sales for a single store, with prices validated against the SKU/store date ranges generated in `prices.csv`.
The hourly budget file is a companion view that expands the daily target to each hour so the operational chart can be read more easily.

To load the May 2026 mock month into IRIS repeatedly, use `./scripts/load_may_2026_mock_data.sh`.
