# embedding_benchmark_tables.sql

## Objetivo
Crear tablas externas de benchmark para comparar modelos de embeddings sobre muestras HU sin mezclar resultados con tablas productivas.

## Alcance
- Esquema `analytics`
- Persistencia de ejecuciones, detalle por item y metricas agregadas por modelo
- Sin modificar tablas warehouse existentes

## Objetos creados
- `analytics.embedding_benchmark_run`
- `analytics.embedding_benchmark_item`
- `analytics.embedding_benchmark_metric`

## Columnas/Salida
- `embedding_benchmark_run`: metadatos de corrida (`run_id`, fecha, modelos, tamano de muestra)
- `embedding_benchmark_item`: detalle por HU/modelo (latencia, dimension, norma, consistencia)
- `embedding_benchmark_metric`: metricas agregadas por modelo (latencia media, p95, hit@1, etc.)

## Operacion
Aplicar el SQL:

```sql
\i database/sql/experiments/embedding_benchmark_tables.sql
```

Consultar resumen:

```sql
SELECT run_id, created_at, model_ids, sample_size
FROM analytics.embedding_benchmark_run
ORDER BY run_id DESC;
```

## Notas
- Esta capa es de experimentacion y no reemplaza `wh_hu_embedding_input`.
- Conviene purgar corridas antiguas periodicamente si crece mucho el volumen.
