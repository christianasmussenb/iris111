#!/usr/bin/env python3

from __future__ import annotations

import csv
import json
from calendar import monthrange
from datetime import date
from datetime import datetime
from datetime import timedelta
from pathlib import Path
from random import Random


WORKSPACE = Path(__file__).resolve().parent.parent
DATA_DIR = WORKSPACE / "data"
STORE_CODE = "GT-0145"
STORE_NAME = "Local Piloto"
REGION = "Centro"
DISTRICT = "Zona 1"
TIMEZONE = "America/Bogota"
MONTH_SEED_YEAR = 2026
MONTH_SEED_MONTH = 5
RNG = Random(111)

CATEGORIES = [
    ("BEBIDAS", "Bebidas"),
    ("ACEITES", "Aceites"),
    ("LACTEOS", "Lacteos"),
    ("CARNES", "Carnes"),
    ("PANADERIA", "Panaderia"),
    ("LIMPIEZA", "Limpieza"),
    ("CONFITERIA", "Confiteria"),
    ("CONGELADOS", "Congelados"),
    ("HIGIENE", "Higiene"),
    ("FRUTAS", "Frutas"),
]

UOMS = ["EA", "EA", "EA", "KG", "L"]


def ensure_dirs() -> None:
    (DATA_DIR / "pos_feed").mkdir(parents=True, exist_ok=True)


def write_csv(path: Path, header: list[str], rows: list[list[object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(header)
        writer.writerows(rows)


def build_month_window() -> tuple[date, date]:
    month_start = date(MONTH_SEED_YEAR, MONTH_SEED_MONTH, 1)
    month_end = date(MONTH_SEED_YEAR, MONTH_SEED_MONTH, monthrange(MONTH_SEED_YEAR, MONTH_SEED_MONTH)[1])
    return month_start, month_end


def build_skus() -> list[dict[str, object]]:
    skus: list[dict[str, object]] = []
    for index in range(1, 101):
        category_code, category_name = CATEGORIES[(index - 1) % len(CATEGORIES)]
        skus.append(
            {
                "internal_sku": f"SKU-{index:04d}",
                "vendor_sku": f"VSKU-{index:04d}",
                "category_code": category_code,
                "category_name": category_name,
                "uom": UOMS[(index - 1) % len(UOMS)],
            }
        )
    return skus


def build_price_rows(skus: list[dict[str, object]], month_start: date, month_end: date) -> list[list[object]]:
    mid_month = month_start.replace(day=15)
    second_period_start = month_start.replace(day=16)
    price_rows: list[list[object]] = []

    for index, sku in enumerate(skus, start=1):
        base_price = 1200 + (index * 47) + (CATEGORIES.index((sku["category_code"], sku["category_name"])) * 130)
        first_period_price = base_price
        second_period_price = round(base_price * 1.08)

        price_rows.append([
            month_start.isoformat(),
            mid_month.isoformat(),
            STORE_CODE,
            sku["internal_sku"],
            first_period_price,
            "COP",
        ])
        price_rows.append([
            second_period_start.isoformat(),
            month_end.isoformat(),
            STORE_CODE,
            sku["internal_sku"],
            second_period_price,
            "COP",
        ])

    return price_rows


def build_budget_rows(skus: list[dict[str, object]], month_start: date) -> list[list[object]]:
    budgets: list[list[object]] = []
    category_groups: dict[str, list[dict[str, object]]] = {}
    for sku in skus:
        category_groups.setdefault(str(sku["category_code"]), []).append(sku)

    for offset, (category_code, items) in enumerate(category_groups.items(), start=1):
        target_units = 400 + (offset * 35)
        target_revenue = target_units * (1800 + (offset * 55))
        budgets.append([
            month_start.isoformat(),
            STORE_CODE,
            category_code,
            target_units,
            target_revenue,
        ])

    return budgets


def price_for_day(price_rows: list[list[object]], internal_sku: str, sale_day: date) -> int:
    sale_day_iso = sale_day.isoformat()
    for start_date, end_date, store_code, sku, price, currency in price_rows:
        if sku == internal_sku and start_date <= sale_day_iso <= end_date:
            return int(price)
    raise ValueError(f"No valid price found for {internal_sku} on {sale_day_iso}")


def build_pos_feed(skus: list[dict[str, object]], price_rows: list[list[object]], month_start: date, month_end: date) -> list[dict[str, object]]:
    events: list[dict[str, object]] = []
    current_day = month_start
    sequence = 1

    while current_day <= month_end:
        for sku_index, sku in enumerate(skus, start=1):
            qty = ((current_day.day + sku_index) % 6) + 1
            price = price_for_day(price_rows, str(sku["internal_sku"]), current_day)
            hour = 8 + ((sku_index + current_day.day) % 10)
            minute = (sku_index * 3 + current_day.day) % 60
            timestamp = datetime(
                current_day.year,
                current_day.month,
                current_day.day,
                hour,
                minute,
            ).isoformat(timespec="seconds") + "Z"
            events.append(
                {
                    "source_id": f"pos-{current_day:%Y%m%d}-{sequence:04d}",
                    "store_code": STORE_CODE,
                    "timestamp": timestamp,
                    "category_code": sku["category_code"],
                    "internal_sku": sku["internal_sku"],
                    "qty": qty,
                    "price": price,
                }
            )
            sequence += 1
        current_day += timedelta(days=1)

    return events


def main() -> None:
    ensure_dirs()

    month_start, month_end = build_month_window()
    month_key = f"{month_start:%Y-%m}"
    skus = build_skus()
    price_rows = build_price_rows(skus, month_start, month_end)
    budget_rows = build_budget_rows(skus, month_start)
    pos_events = build_pos_feed(skus, price_rows, month_start, month_end)

    write_csv(
        DATA_DIR / "skus.csv",
        ["internal_sku", "vendor_sku", "category_code", "uom"],
        [[row["internal_sku"], row["vendor_sku"], row["category_code"], row["uom"]] for row in skus],
    )

    write_csv(
        DATA_DIR / "categories.csv",
        ["category_code", "category_name"],
        [[code, name] for code, name in CATEGORIES],
    )

    write_csv(
        DATA_DIR / "stores.csv",
        ["store_code", "store_name", "region", "district", "timezone"],
        [[STORE_CODE, STORE_NAME, REGION, DISTRICT, TIMEZONE]],
    )

    write_csv(
        DATA_DIR / "prices.csv",
        ["effective_start_date", "effective_end_date", "store_code", "internal_sku", "price", "currency"],
        price_rows,
    )

    write_csv(
        DATA_DIR / "budgets.csv",
        ["budget_date", "store_code", "category_code", "target_units", "target_revenue"],
        budget_rows,
    )

    pos_feed = DATA_DIR / "pos_feed" / f"sample_pos_events_{month_key}.json"
    pos_feed.write_text(
        json.dumps(pos_events, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print(f"Mock data generated under {DATA_DIR}")
    print(f"- SKUs: {len(skus)}")
    print(f"- Prices: {len(price_rows)}")
    print(f"- Budgets: {len(budget_rows)}")
    print(f"- POS events: {len(pos_events)}")


if __name__ == "__main__":
    main()
