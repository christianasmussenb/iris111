#!/usr/bin/env python3

from __future__ import annotations

import csv
from datetime import date
from pathlib import Path


WORKSPACE = Path(__file__).resolve().parent.parent
DATA_DIR = WORKSPACE / "data"


def ensure_dirs() -> None:
    (DATA_DIR / "pos_feed").mkdir(parents=True, exist_ok=True)


def write_csv(path: Path, header: list[str], rows: list[list[object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(header)
        writer.writerows(rows)


def main() -> None:
    ensure_dirs()

    today = date.today().isoformat()

    write_csv(
        DATA_DIR / "skus.csv",
        ["internal_sku", "vendor_sku", "category_code", "uom"],
        [
            ["SKU-1001", "VSKU-1001", "BEBIDAS", "EA"],
            ["SKU-2001", "VSKU-2001", "ACEITES", "EA"],
        ],
    )

    write_csv(
        DATA_DIR / "stores.csv",
        ["store_code", "store_name", "region", "district", "timezone"],
        [["GT-0145", "Local Piloto", "Centro", "Zona 1", "America/Bogota"]],
    )

    write_csv(
        DATA_DIR / "budgets.csv",
        ["budget_date", "store_code", "category_code", "target_units", "target_revenue"],
        [
            [today, "GT-0145", "BEBIDAS", 50, 175000],
            [today, "GT-0145", "ACEITES", 25, 222500],
        ],
    )

    pos_feed = DATA_DIR / "pos_feed" / f"sample_pos_events_{today}.json"
    pos_feed.write_text(
        "[\n"
        '  {"source_id": "pos-evt-001", "store_code": "GT-0145", "timestamp": "2026-05-13T08:10:00Z", "category_code": "BEBIDAS", "internal_sku": "SKU-1001", "qty": 2, "price": 3500},\n'
        '  {"source_id": "pos-evt-002", "store_code": "GT-0145", "timestamp": "2026-05-13T08:15:00Z", "category_code": "ACEITES", "internal_sku": "SKU-2001", "qty": 1, "price": 8900}\n'
        "]\n",
        encoding="utf-8",
    )

    print(f"Mock data generated under {DATA_DIR}")


if __name__ == "__main__":
    main()
