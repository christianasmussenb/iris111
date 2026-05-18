#!/usr/bin/env python3

from __future__ import annotations

import csv
import json
from calendar import monthrange
from datetime import date, datetime, timedelta
from pathlib import Path


WORKSPACE = Path(__file__).resolve().parent.parent
DATA_DIR = WORKSPACE / "data"
POS_DIR = DATA_DIR / "pos_feed"

STORE_CODE = "GT-0145"
MONTH_YEAR = 2026
MONTH_MONTH = 5

CATEGORIES = [
    ("BEBIDAS", "Bebidas"),
    ("ACEITES", "Aceites"),
    ("LACTEOS", "Lacteos"),
    ("CARNES", "Carnes"),
    ("PANADERIA", "Panaderia"),
]

HOURS = list(range(8, 22))
SKUS_PER_CATEGORY = 20


def ensure_dirs() -> None:
    POS_DIR.mkdir(parents=True, exist_ok=True)


def write_csv(path: Path, header: list[str], rows: list[list[object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(header)
        writer.writerows(rows)


def build_month_window() -> tuple[date, date]:
    month_start = date(MONTH_YEAR, MONTH_MONTH, 1)
    month_end = date(MONTH_YEAR, MONTH_MONTH, monthrange(MONTH_YEAR, MONTH_MONTH)[1])
    return month_start, month_end


def build_skus() -> list[dict[str, object]]:
    skus: list[dict[str, object]] = []
    sequence = 1
    for category_index, (category_code, category_name) in enumerate(CATEGORIES):
        for slot in range(SKUS_PER_CATEGORY):
            base_price = 1250 + (category_index * 235) + (slot * 41)
            skus.append(
                {
                    "internal_sku": f"SKU-{sequence:04d}",
                    "vendor_sku": f"VSKU-{sequence:04d}",
                    "category_code": category_code,
                    "category_name": category_name,
                    "base_price": base_price,
                }
            )
            sequence += 1
    return skus


def projected_budget_at_hour(daily_value: int | float, hour: int) -> int:
    start_hour = HOURS[0]
    end_hour = HOURS[-1]
    active_hours = end_hour - start_hour + 1

    if hour < start_hour:
        return 0
    if hour >= end_hour:
        return int(daily_value)

    projected = round(float(daily_value) * ((hour - start_hour + 1) / active_hours))
    return max(int(projected), 0)


def build_data() -> tuple[list[dict[str, object]], list[list[object]], list[list[object]], list[dict[str, object]]]:
    month_start, month_end = build_month_window()
    skus = build_skus()

    daily_budget_rows: list[list[object]] = []
    hourly_budget_rows: list[list[object]] = []
    pos_events: list[dict[str, object]] = []

    current_day = month_start
    while current_day <= month_end:
        sku_daily_values: list[dict[str, object]] = []
        category_totals: dict[str, dict[str, int]] = {
            category_code: {"units": 0, "revenue": 0} for category_code, _ in CATEGORIES
        }

        for sku_index, sku in enumerate(skus):
            units = 2 + ((current_day.day + sku_index) % 6)
            unit_price = int(sku["base_price"]) + ((current_day.day + sku_index) % 5) * 19
            revenue = units * unit_price

            sku_daily_values.append(
                {
                    "internal_sku": sku["internal_sku"],
                    "category_code": sku["category_code"],
                    "units": units,
                    "unit_price": unit_price,
                    "revenue": revenue,
                }
            )

            totals = category_totals[str(sku["category_code"])]
            totals["units"] += units
            totals["revenue"] += revenue

            daily_budget_rows.append(
                [
                    current_day.isoformat(),
                    STORE_CODE,
                    sku["category_code"],
                    units,
                    revenue,
                    sku["internal_sku"],
                ]
            )

        for category_code, totals in category_totals.items():
            daily_budget_rows.append(
                [
                    current_day.isoformat(),
                    STORE_CODE,
                    category_code,
                    totals["units"],
                    totals["revenue"],
                    "",
                ]
            )

        for hour in HOURS:
            for category_code, totals in category_totals.items():
                hourly_budget_rows.append(
                    [
                        current_day.isoformat(),
                        f"{hour:02d}",
                        STORE_CODE,
                        category_code,
                        "",
                        totals["units"],
                        totals["revenue"],
                        projected_budget_at_hour(totals["units"], hour),
                        projected_budget_at_hour(totals["revenue"], hour),
                    ]
                )

            for sku_value in sku_daily_values:
                hourly_budget_rows.append(
                    [
                        current_day.isoformat(),
                        f"{hour:02d}",
                        STORE_CODE,
                        sku_value["category_code"],
                        sku_value["internal_sku"],
                        sku_value["units"],
                        sku_value["revenue"],
                        projected_budget_at_hour(sku_value["units"], hour),
                        projected_budget_at_hour(sku_value["revenue"], hour),
                    ]
                )

            event_index = (current_day.day - 1) * len(HOURS) + (hour - HOURS[0])
            sku_value = sku_daily_values[event_index % len(sku_daily_values)]
            minute = (current_day.day * 3 + hour * 7) % 60
            pos_events.append(
                {
                    "source_id": f"pos-{current_day:%Y%m%d}-{hour:02d}",
                    "store_code": STORE_CODE,
                    "timestamp": f"{current_day:%Y-%m-%d}T{hour:02d}:{minute:02d}:00Z",
                    "category_code": sku_value["category_code"],
                    "internal_sku": sku_value["internal_sku"],
                    "qty": sku_value["units"],
                    "price": sku_value["unit_price"],
                }
            )

        current_day += timedelta(days=1)

    daily_budget_rows.sort(key=lambda row: (row[0], row[2], row[5]))
    hourly_budget_rows.sort(key=lambda row: (row[0], row[1], row[3], row[4]))
    pos_events.sort(key=lambda row: (row["timestamp"], row["source_id"]))

    return skus, daily_budget_rows, hourly_budget_rows, pos_events


def main() -> None:
    ensure_dirs()
    skus, daily_budget_rows, hourly_budget_rows, pos_events = build_data()

    write_csv(
        DATA_DIR / "budgets.csv",
        ["budget_date", "store_code", "category_code", "target_units", "target_revenue", "internal_sku"],
        daily_budget_rows,
    )

    write_csv(
        DATA_DIR / "budgets_hourly.csv",
        [
            "budget_date",
            "budget_hour",
            "store_code",
            "category_code",
            "internal_sku",
            "daily_target_units",
            "daily_target_revenue",
            "expected_units_to_hour",
            "expected_revenue_to_hour",
        ],
        hourly_budget_rows,
    )

    (POS_DIR / "sample_pos_events_2026-05.json").write_text(
        json.dumps(pos_events, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print(f"Generated {len(skus)} SKUs across {len(CATEGORIES)} categories")
    print(f"Generated {len(pos_events)} POS events for May 2026")
    print(f"Generated {len(daily_budget_rows)} daily budget rows")
    print(f"Generated {len(hourly_budget_rows)} hourly budget rows")


if __name__ == "__main__":
    main()