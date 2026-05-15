# Capa Base HU (v1) - Resumen rápido

## Qué es
La **capa base HU** es la primera capa de datos para Historias de Usuario.  
Su objetivo es dejar HU **listas y consistentes** para búsqueda posterior, sin embeddings todavía.

## Para qué sirve
- Centraliza HU en formato warehouse.
- Mantiene jerarquía padre/subtarea.
- Permite cargas **full** e **incrementales** con watermark.
- Deja datos preparados para conectar con tickets y (más adelante) código.

## Diseño (simple)
```text
Vistas fuente (Odoo)
  ├─ analytics.v_hu_raw
  └─ analytics.mv_hu_estructura
          │
          ▼
ETL v1 (Python + SQL)
  ├─ mode=full
  └─ mode=incremental (wh_etl_watermark)
          │
          ▼
Warehouse HU
  ├─ analytics.wh_hu_group   (1 fila por grupo funcional)
  └─ analytics.wh_hu_node    (1 fila por HU/subHU)
```

## Qué tablas deja
- `wh_hu_group`: agregado por `group_id` (`anchor_task_id`), con horas, estados y trazabilidad básica.
- `wh_hu_node`: detalle por nodo HU con estado, horas, fechas y descripción limpia.
- `wh_etl_watermark`: control de última fecha procesada para incremental.

## Cómo conecta con las otras fuentes
- **Con Tickets**: por `helpdesk_ticket_id` (en group y node).
- **Con negocio/proyecto**: `project_id`, `partner_id`.
- **Con código (futuro)**: se enlazará en la siguiente capa por referencias de ticket/hu y metadatos.

## Qué falta (siguiente capa)
1. Generar `wh_hu_embedding_input` (`full`, `solution`, `hu_description`).
2. Vectorizar embeddings.
3. Construir búsqueda híbrida + reranking con HU.

## Estado actual
✅ Base estable y validada (full + incremental).  
⏳ Embeddings y búsqueda aún no activados.

