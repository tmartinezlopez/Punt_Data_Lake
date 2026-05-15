"""Benchmark simple de embeddings sobre 10 HUs.

Uso:
  python etl/embedding_benchmark.py --models qwen3-embedding:8b nomic-embed-text-v2-moe:latest

Requisitos:
  - Postgres accesible con variables POSTGRES_* en .env
  - API de embeddings compatible con Ollama en OLLAMA_BASE_URL (default: http://localhost:11434)
  - Tablas de benchmark creadas (ver database/sql/experiments/embedding_benchmark_tables.sql)
"""

from __future__ import annotations

import argparse
import json
import math
import os
import time
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine

REPO_ROOT = Path(__file__).resolve().parents[1]


@dataclass
class Row:
    ordinal: int
    hu_group_id: int
    project_id: int | None
    partner_id: int | None
    embedding_text: str


def load_env() -> None:
    load_dotenv(REPO_ROOT / ".env")


def dsn() -> str:
    user = os.environ["POSTGRES_USER"]
    password = os.environ["POSTGRES_PASSWORD"]
    db = os.environ["POSTGRES_DB"]
    host = os.environ.get("POSTGRES_HOST", "localhost")
    port = os.environ.get("POSTGRES_PORT", "5432")
    return f"postgresql+psycopg://{user}:{password}@{host}:{port}/{db}"


def get_engine() -> Engine:
    return create_engine(dsn(), pool_pre_ping=True, future=True)


def cosine(a: list[float], b: list[float]) -> float:
    dot = 0.0
    na = 0.0
    nb = 0.0
    for x, y in zip(a, b):
        dot += x * y
        na += x * x
        nb += y * y
    if na == 0.0 or nb == 0.0:
        return 0.0
    return dot / (math.sqrt(na) * math.sqrt(nb))


def l2_norm(v: list[float]) -> float:
    return math.sqrt(sum(x * x for x in v))


def embed_once(base_url: str, model: str, text_value: str) -> tuple[list[float], float]:
    payload = {"model": model, "input": text_value}
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        f"{base_url.rstrip('/')}/api/embed",
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    t0 = time.perf_counter()
    with urllib.request.urlopen(req, timeout=120) as resp:
        raw = resp.read().decode("utf-8")
    elapsed_ms = (time.perf_counter() - t0) * 1000.0
    body = json.loads(raw)
    if "embeddings" in body and body["embeddings"]:
        vector = body["embeddings"][0]
    elif "embedding" in body:
        vector = body["embedding"]
    else:
        raise RuntimeError(f"Respuesta inesperada de embeddings para {model}: {body}")
    return [float(x) for x in vector], elapsed_ms


def fetch_sample(engine: Engine, sample_size: int) -> list[Row]:
    sql = text(
        """
        SELECT
            ROW_NUMBER() OVER (ORDER BY e.group_id) AS ordinal,
            e.group_id AS hu_group_id,
            e.project_id,
            e.partner_id,
            e.embedding_text
        FROM analytics.wh_hu_embedding_input e
        WHERE e.embedding_type = 'full'
          AND COALESCE(e.embedding_text, '') <> ''
        ORDER BY e.group_id
        LIMIT :sample_size
        """
    )
    rows: list[Row] = []
    with engine.connect() as conn:
        for r in conn.execute(sql, {"sample_size": sample_size}).mappings():
            rows.append(
                Row(
                    ordinal=int(r["ordinal"]),
                    hu_group_id=int(r["hu_group_id"]),
                    project_id=int(r["project_id"]) if r["project_id"] is not None else None,
                    partner_id=int(r["partner_id"]) if r["partner_id"] is not None else None,
                    embedding_text=str(r["embedding_text"]),
                )
            )
    return rows


def safe_mean(values: list[float]) -> float:
    return sum(values) / len(values) if values else 0.0


def run_benchmark(
    engine: Engine,
    models: list[str],
    rows: list[Row],
    base_url: str,
    notes: str | None,
) -> int:
    with engine.begin() as conn:
        run_id = conn.execute(
            text(
                """
                INSERT INTO analytics.embedding_benchmark_run (
                    source_table, sample_size, text_field, model_ids, notes
                )
                VALUES ('analytics.wh_hu_embedding_input', :sample_size, 'embedding_text', :model_ids, :notes)
                RETURNING run_id
                """
            ),
            {"sample_size": len(rows), "model_ids": models, "notes": notes},
        ).scalar_one()

        for model in models:
            latencies: list[float] = []
            norms: list[float] = []
            consistencies: list[float] = []
            vectors_first: list[list[float]] = []
            project_ids: list[int | None] = []

            for row in rows:
                vec1, ms1 = embed_once(base_url, model, row.embedding_text)
                vec2, ms2 = embed_once(base_url, model, row.embedding_text)
                consistency = cosine(vec1, vec2)
                latency = (ms1 + ms2) / 2.0
                norm = l2_norm(vec1)

                latencies.append(latency)
                norms.append(norm)
                consistencies.append(consistency)
                vectors_first.append(vec1)
                project_ids.append(row.project_id)

                conn.execute(
                    text(
                        """
                        INSERT INTO analytics.embedding_benchmark_item (
                            run_id, model_id, ordinal, hu_group_id, project_id, partner_id,
                            text_char_len, text_word_len, embedding_dim,
                            latency_ms, l2_norm, self_consistency_cosine
                        )
                        VALUES (
                            :run_id, :model_id, :ordinal, :hu_group_id, :project_id, :partner_id,
                            :text_char_len, :text_word_len, :embedding_dim,
                            :latency_ms, :l2_norm, :self_consistency_cosine
                        )
                        """
                    ),
                    {
                        "run_id": run_id,
                        "model_id": model,
                        "ordinal": row.ordinal,
                        "hu_group_id": row.hu_group_id,
                        "project_id": row.project_id,
                        "partner_id": row.partner_id,
                        "text_char_len": len(row.embedding_text),
                        "text_word_len": len(row.embedding_text.split()),
                        "embedding_dim": len(vec1),
                        "latency_ms": latency,
                        "l2_norm": norm,
                        "self_consistency_cosine": consistency,
                    },
                )

            # NN hit@1 por mismo project_id
            hit = 0
            total = 0
            for i, vec in enumerate(vectors_first):
                if project_ids[i] is None:
                    continue
                best_j = -1
                best_sim = -2.0
                for j, vec_j in enumerate(vectors_first):
                    if i == j:
                        continue
                    sim = cosine(vec, vec_j)
                    if sim > best_sim:
                        best_sim = sim
                        best_j = j
                if best_j >= 0 and project_ids[best_j] is not None:
                    total += 1
                    if project_ids[best_j] == project_ids[i]:
                        hit += 1
            nn_hit_at_1 = (hit / total) if total else 0.0

            # Dispersión media de similitudes pares
            pairwise: list[float] = []
            for i in range(len(vectors_first)):
                for j in range(i + 1, len(vectors_first)):
                    pairwise.append(cosine(vectors_first[i], vectors_first[j]))

            metrics = {
                "avg_latency_ms": safe_mean(latencies),
                "p95_latency_ms": sorted(latencies)[max(0, math.ceil(0.95 * len(latencies)) - 1)] if latencies else 0.0,
                "avg_l2_norm": safe_mean(norms),
                "std_l2_norm": math.sqrt(safe_mean([(x - safe_mean(norms)) ** 2 for x in norms])) if norms else 0.0,
                "avg_self_consistency_cosine": safe_mean(consistencies),
                "min_self_consistency_cosine": min(consistencies) if consistencies else 0.0,
                "avg_pairwise_cosine": safe_mean(pairwise),
                "std_pairwise_cosine": math.sqrt(safe_mean([(x - safe_mean(pairwise)) ** 2 for x in pairwise])) if pairwise else 0.0,
                "nn_project_hit_at_1": nn_hit_at_1,
            }

            for metric_name, metric_value in metrics.items():
                conn.execute(
                    text(
                        """
                        INSERT INTO analytics.embedding_benchmark_metric (run_id, model_id, metric_name, metric_value)
                        VALUES (:run_id, :model_id, :metric_name, :metric_value)
                        """
                    ),
                    {
                        "run_id": run_id,
                        "model_id": model,
                        "metric_name": metric_name,
                        "metric_value": metric_value,
                    },
                )
    return int(run_id)


def print_summary(engine: Engine, run_id: int) -> None:
    sql = text(
        """
        SELECT model_id,
               MAX(CASE WHEN metric_name='avg_latency_ms' THEN metric_value END) AS avg_latency_ms,
               MAX(CASE WHEN metric_name='p95_latency_ms' THEN metric_value END) AS p95_latency_ms,
               MAX(CASE WHEN metric_name='avg_self_consistency_cosine' THEN metric_value END) AS consistency,
               MAX(CASE WHEN metric_name='nn_project_hit_at_1' THEN metric_value END) AS hit_at_1
        FROM analytics.embedding_benchmark_metric
        WHERE run_id = :run_id
        GROUP BY model_id
        ORDER BY model_id
        """
    )
    with engine.connect() as conn:
        rows = list(conn.execute(sql, {"run_id": run_id}).mappings())
    print(f"run_id={run_id}")
    for r in rows:
        print(
            f"{r['model_id']}: "
            f"avg_latency_ms={float(r['avg_latency_ms'] or 0):.2f}, "
            f"p95_latency_ms={float(r['p95_latency_ms'] or 0):.2f}, "
            f"consistency={float(r['consistency'] or 0):.6f}, "
            f"nn_project_hit_at_1={float(r['hit_at_1'] or 0):.4f}"
        )


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Benchmark embeddings sobre 10 HUs")
    p.add_argument("--models", nargs="+", required=True, help="Model IDs")
    p.add_argument("--sample-size", type=int, default=10, help="Numero de HUs (default=10)")
    p.add_argument("--base-url", default=os.environ.get("OLLAMA_BASE_URL", "http://localhost:11434"))
    p.add_argument("--notes", default=None)
    return p.parse_args()


def main() -> None:
    load_env()
    args = parse_args()
    engine = get_engine()
    rows = fetch_sample(engine, args.sample_size)
    if len(rows) < args.sample_size:
        raise RuntimeError(
            f"No hay suficientes HUs con embedding_type='full'. Solicitadas={args.sample_size}, encontradas={len(rows)}"
        )
    run_id = run_benchmark(engine, args.models, rows, args.base_url, args.notes)
    print_summary(engine, run_id)


if __name__ == "__main__":
    main()
