# Data folder

This folder stores the input files used by the IRIS111 PoC environment.

The local mock data loader writes seed files here:

- `skus.csv`
- `categories.csv`
- `stores.csv`
- `prices.csv`
- `budgets.csv`
- `pos_feed/`

The POS feed now includes a month of sales for a single store, with prices validated against the SKU/store date ranges generated in `prices.csv`.
