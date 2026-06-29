#!/usr/bin/env python3
"""Load Farmer Registry score-compute queue rows after SQL sample data.

Reads:
- /seed/seed-data/household_score_compute_queue.json (shipped in the db-seed image)
"""

import json
import os
import sys
from pathlib import Path

import psycopg2
import psycopg2.extras
from psycopg2.extras import Json


SEED_DATA_DIR = Path(os.environ.get("FARMER_SEED_DATA_DIR", "/seed/seed-data"))


def env(name: str) -> str:
    value = os.environ.get(name, "")
    if not value:
        print(f"[load-sample-data] Missing env var: {name}", file=sys.stderr)
        sys.exit(1)
    return value


def load_json(path: Path) -> list[dict]:
    if not path.is_file():
        print(f"[load-sample-data] Missing file: {path}", file=sys.stderr)
        sys.exit(1)
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise ValueError(f"{path} must contain a JSON array")
    return data


def insert_score_compute_queue(cur, queue_rows: list[dict]) -> None:
    if not queue_rows:
        return

    columns = [
        "queue_id",
        "register_id",
        "link_internal_record_id",
        "score_definition_id",
        "score_type",
        "change_request_id",
        "submission_id",
        "contributing_attribute_values",
        "compute_status",
        "compute_no_of_attempts",
        "compute_latest_timestamp",
        "compute_latest_error_code",
    ]
    rows = []
    for row in queue_rows:
        rows.append(
            (
                row["queue_id"],
                row["register_id"],
                row["link_internal_record_id"],
                row["score_definition_id"],
                row["score_type"],
                row.get("change_request_id"),
                row.get("submission_id"),
                Json(row.get("contributing_attribute_values") or {}),
                row.get("compute_status", "PENDING"),
                row.get("compute_no_of_attempts", 0),
                row.get("compute_latest_timestamp"),
                row.get("compute_latest_error_code"),
            )
        )

    sql = (
        'INSERT INTO "public"."g2p_score_compute_queue" ('
        + ", ".join(f'"{c}"' for c in columns)
        + ") VALUES %s"
    )
    psycopg2.extras.execute_values(cur, sql, rows, template=None, page_size=200)
    print(f"[load-sample-data]   -> g2p_score_compute_queue: {len(rows)}")


def main() -> None:
    print("[load-sample-data] Loading Farmer Registry score compute queue …")
    print(f"[load-sample-data] FARMER_SEED_DATA_DIR = {SEED_DATA_DIR}")

    queue_path = SEED_DATA_DIR / "household_score_compute_queue.json"
    queue_rows = load_json(queue_path)

    conn = psycopg2.connect(
        host=env("PGHOST"),
        port=os.environ.get("PGPORT", "5432"),
        dbname=env("PGDATABASE"),
        user=env("PGUSER"),
        password=env("PGPASSWORD"),
    )
    conn.autocommit = False
    cur = conn.cursor()

    try:
        insert_score_compute_queue(cur, queue_rows)
        conn.commit()
        print("[load-sample-data] Done.")
    except Exception as exc:
        conn.rollback()
        print(f"[load-sample-data] FAILED: {exc}", file=sys.stderr)
        raise
    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    main()
