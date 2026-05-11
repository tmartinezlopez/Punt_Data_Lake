# HU v1 - Decisiones de Diseño para Desarrollo

Fecha: 2026-05-11
Estado: Aprobado para inicio de desarrollo
Ámbito: Fuente Historias de Usuario (HU) para asistente de soporte

## 1) Objetivo
Diseñar la fuente HU para que, dado un ticket nuevo, el sistema pueda recuperar casos HU relevantes y usarlos en la propuesta de solución.

## 2) Fuentes HU activas (BD)
1. `analytics.v_hu_raw`
2. `analytics.mv_hu_estructura`

### Alcance temporal activo
- Ambas vistas están limitadas a: `create_date::date >= '2024-10-02'`
- Motivo: reducir volumen/coste y centrar el sistema en el periodo útil validado.

## 3) Unidad de indexación
### 3.1 HU_GROUP (principal)
- Clave: `group_id = anchor_task_id`
- Rol: unidad funcional que se rankea primero en búsqueda.

### 3.2 HU_NODE (evidencia)
- Clave: `node_id = hu_id`
- Relación: `group_id`
- Rol: detalle para justificar por qué un grupo fue sugerido.

## 4) Embeddings HU v1 (cerrados)
Se usarán 3 embeddings por HU_GROUP:
1. `emb_full`
2. `emb_solution`
3. `emb_hu_description`

## 5) Meta exacto por embedding

### 5.1 emb_full - Meta
1. `group_id`
2. `project_id`
3. `partner_id`
4. `root_id`
5. `node_count`
6. `max_depth`
7. `min_create_date`
8. `max_write_date`
9. `embedded_at`

### 5.2 emb_solution - Meta
1. `group_id`
2. `project_id`
3. `partner_id`
4. `done_nodes`
5. `in_progress_nodes`
6. `canceled_nodes`
7. `max_write_date`
8. `embedded_at`

### 5.3 emb_hu_description - Meta
1. `group_id`
2. `anchor_task_id`
3. `project_id`
4. `partner_id`
5. `anchor_hu_id`
6. `description_source` (`anchor_only` / `anchor_plus_children`)
7. `max_write_date`
8. `embedded_at`

## 6) Regla de partner_id de grupo
1. Si el anchor tiene `partner_id`, usar ese.
2. Si no, usar el `partner_id` más frecuente del grupo.
3. Si no hay valor, `partner_id = NULL`.

## 7) Principio clave (separación de responsabilidades)
1. Indexación: neutral (sin ranking de negocio).
2. Búsqueda: aplica criterios, pesos y priorización.

## 8) Construcción de texto para embeddings (neutral)

### 8.1 emb_full
- Incluye contexto completo del grupo (meta + contenido de nodos + trazabilidad).
- Sin top-N por relevancia.
- Orden de nodos estable: `depth asc, create_date asc, hu_id asc`.

### 8.2 emb_solution
- Incluye señal de resolución consolidada del grupo.
- Sin top-N por relevancia.
- Permite priorizar nodos `done` en la composición, sin convertirlo en criterio de ranking final.

### 8.3 emb_hu_description
- Incluye descripción anchor.
- Si anchor pobre, añade hijos según `description_source`.
- Objetivo: capturar intención funcional original HU.

## 9) Búsqueda HU (diseño v1)

### 9.1 Entrada
- `ticket_text`
- `project_id` (opcional)
- `partner_id` (opcional)
- `top_k` (inicial: 5)

### 9.2 Fase 1 (recall)
- Vectorial `emb_full`: top 100
- Vectorial `emb_solution`: top 100
- Léxica (BM25/tsvector): top 100
- Fusión RRF -> top 60 grupos candidatos

### 9.3 Fase 2 (precisión)
- Selección de fuentes candidatas: 12 grupos
- Refinado/rerank sobre esas fuentes
- Salida final: top 5

### 9.4 Estado de parámetros
- Estos valores son iniciales (no definitivos).
- Se recalibran con métricas de piloto.

## 10) KPIs base para calibración
1. `Useful@5`
2. `CTR sugerencias`
3. `Apply rate`
4. `No relevant rate`
5. `MRR@5`
6. `Latencia p95 total`
7. `Latencia p95 rerank`
8. `Cobertura partner/project`

## 11) Supuestos abiertos (para siguiente iteración)
1. Umbrales finales de confianza.
2. Límites exactos de longitud por texto de embedding.
3. Política de fallback cuando no hay resultados de alta confianza.

## 12) Criterio de avance a desarrollo
Aprobado. Se puede iniciar implementación con esta base v1.
