# Asistente de resolución de tickets y desarrollo para Odoo

**Cliente:** [CLIENTE]
**Presenta:** Punt Sistemes — Departamento de Innovación y BI
**Fecha:** [FECHA]
**Versión:** 2.0

---

## 1. Contexto y necesidad

[CLIENTE] gestiona su servicio de soporte sobre **Odoo Helpdesk** y mantiene un histórico de **45.000 tickets** resueltos en español. Además, dispone de **Historias de Usuario** (tareas dentro de proyectos, con subtareas y descripciones funcionales/técnicas) y de **repositorios GitHub** enlazados a proyectos, tareas o tickets.

Las tres fuentes de datos principales del sistema son:

- Tickets de Odoo Helpdesk (descripción inicial + chatter + resolución final)
- Historias de Usuario de Odoo Project (proyecto/tarea/subtarea, estados, descripciones, criterios)
- GitHub (repositorios, commits, pull requests y código relacionado)

El conocimiento operativo del equipo de soporte y desarrollo está disperso entre esas tres fuentes. Cuando un agente abre un ticket nuevo, **no tiene una forma sistemática de saber si el problema ya se resolvió antes y cómo**, ni qué historia o cambio de código lo explica. La búsqueda nativa de Odoo es léxica: encuentra coincidencias literales pero no equivalencias semánticas. Un ticket que describe el mismo problema con palabras distintas no aparece.

Las consecuencias prácticas:

- Tiempo de resolución más alto del necesario en problemas recurrentes
- Resolución dependiente de la experiencia individual del técnico que coge el ticket
- Conocimiento que se pierde cuando un técnico cambia de equipo o deja la empresa
- Escalados a segundo nivel que podrían evitarse si el primer nivel encontrara el caso resuelto previamente

**Lo que [CLIENTE] quiere:** que cuando un agente abra un ticket nuevo, vea automáticamente los casos históricos más relevantes (tickets, historias y cambios de código relacionados) y la solución aplicada en cada uno, sin tener que buscar manualmente.

---

## 2. Solución propuesta

Se construye un **asistente de retrieval semántico integrado en Odoo Helpdesk** que, ante un ticket nuevo, devuelve al agente los 5 casos históricos más relevantes combinando las tres fuentes (tickets, historias de usuario y GitHub), con un resumen del problema y de la solución. El sistema se entrega en dos formas: una **extensión de navegador** para el piloto (despliegue rápido sin tocar Odoo) y un **módulo Odoo nativo** para producción consolidada.

El proyecto se ejecuta como **un único bloque** con un punto de validación temprana (go/no-go) tras los primeros 1.500 €, antes de procesar en volumen las tres fuentes. Esto protege a [CLIENTE] del escenario de riesgo real: que la calidad estructurable de los datos (chatter, descripciones de historias y enlaces/cambios de código) no sea suficiente.

### Decisiones técnicas clave

**Embeddings semánticos en español: `text-embedding-3-large` de OpenAI**

**Por qué:** [CLIENTE] necesita calidad en español sin invertir en infraestructura GPU propia. Este modelo es multilingüe, está entre los líderes de benchmarks de retrieval para español, y el coste operativo es despreciable a esta escala (embedar 45.000 tickets cuesta una sola vez bajo 15 €; las consultas posteriores son céntimos al mes).

**Alternativa descartada:** modelos open-source self-hosted (`multilingual-e5-large`, `bge-m3`). Calidad similar pero requieren GPU dedicada para inferencia, mantenimiento de infraestructura propia y monitorización. No compensa para 45.000 tickets.

**Almacenamiento vectorial: PostgreSQL con `pgvector`**

**Por qué:** Odoo ya corre sobre PostgreSQL. Añadir `pgvector` es una extensión, no una pieza de infraestructura nueva. A 45.000 vectores con índice HNSW las consultas responden en milisegundos. No hay que mantener ni pagar Pinecone, Qdrant, Weaviate ni similares.

**Alternativa descartada:** vector stores dedicados. Justificados a partir de millones de vectores. Aquí serían infraestructura innecesaria.

**Búsqueda híbrida: densa (embeddings) + léxica (BM25 vía `tsvector`) con fusión RRF**

**Por qué:** En soporte técnico aparecen códigos de error, referencias de producto, nombres de módulos y SKUs donde la coincidencia exacta de palabra gana al embedding. Combinar las dos estrategias mejora el recall entre 10 y 20% sobre solo búsqueda semántica. La fusión por Reciprocal Rank Fusion (RRF) es trivial y se ejecuta en la propia base de datos.

**Alternativa descartada:** solo embeddings. Pierde precisión cuando el ticket contiene identificadores técnicos exactos.

**Reranking: `rerank-multilingual-v3.0` de Cohere**

**Por qué:** Después del retrieval inicial (top-50 candidatos) se reordenan con un cross-encoder que evalúa cada par consulta-candidato con más profundidad. Es el paso que hace que los 5 que ve el agente sean los 5 buenos, no 5 falsos positivos semánticos. Cohere tiene rendimiento de referencia en español y coste por consulta despreciable.

**Alternativa descartada:** rerankers open-source (`bge-reranker-v2-m3`). Calidad equiparable pero requieren GPU dedicada. Para volumen de [CLIENTE] no compensa.

**Estructuración del corpus: extracción LLM multifuente**

**Por qué:** El valor del sistema está en combinar tres fuentes con naturaleza distinta: tickets de Helpdesk (ruido operativo en chatter), historias de usuario (descripción funcional/técnica, frecuentemente en Gherkin y con subtareas) y GitHub (PRs/commits/issues con contexto de implementación). Indexar **resúmenes estructurados por fuente** mejora la precisión porque compara problema con problema, solución con solución y contexto técnico con contexto técnico.

Se aplica una extracción específica por cada fuente:
- Tickets: síntoma, diagnóstico, solución, módulo y señales del chatter.
- Historias de usuario: objetivo, criterios (incluyendo Gherkin), subtareas, dependencias y resultado.
- GitHub: componente afectado, tipo de cambio, justificación técnica y evidencia de resolución.

Se hace una vez con un LLM económico (Claude Haiku). Coste único estimado entre 60 y 120 €. **Antes de procesar en volumen las tres fuentes**, se valida el extractor sobre una muestra representativa multifuente para confirmar calidad (Hito 2, go/no-go).

**Alternativa descartada:** indexar cada elemento completo concatenado sin estructurar. Funciona, pero diluye señal en textos largos y aumenta falsos positivos, especialmente al mezclar fuentes heterogéneas.

**Entrega en dos formas: extensión de navegador (piloto) + módulo Odoo nativo (producción)**

**Por qué:** la extensión de navegador permite poner el sistema en manos de los agentes en semana 6 sin tocar el Odoo de producción ni siquiera el de pruebas. Inyecta el panel de sugerencias en la vista de ticket cuando el agente está navegando en Odoo. Esto da 2-3 semanas de uso real antes de construir el módulo Odoo, que se entrega al final con los ajustes que hayan salido del piloto. El módulo Odoo nativo queda como entrega definitiva, integrado en el flujo y compatible con cualquier cliente Odoo (web, móvil, futuras versiones).

**Alternativa descartada:** módulo Odoo desde el primer día. Más caro y más lento de iterar; el feedback del piloto llegaría demasiado tarde para ajustar.

### Arquitectura

```text
+--------------------------------------------------------------------------------+
|                               Odoo + GitHub                                    |
|  +------------------+  +----------------------+  +--------------------------+  |
|  | Helpdesk Tickets |  | Historias de Usuario |  | Repositorios GitHub      |  |
|  | (desc/chatter/   |  | (proyecto/tarea/     |  | (PR/commit/issues/código)|  |
|  | resolución)      |  | subtarea/gherkin)    |  |                          |  |
|  +--------+---------+  +----------+-----------+  +------------+-------------+  |
+-----------+-----------------------+----------------------------+----------------+
            | lectura (SQL/RPC)     | lectura (SQL/RPC)         | lectura (API)
            +-----------------------+----------------------------+
                                    |
                                    v
+--------------------------------------------------------------------------------+
|                   Pipeline de indexación (Python, programado)                 |
| - Limpieza/normalización por fuente                                           |
| - Extracción estructurada LLM (ticket/historia/código)                        |
| - Enlazado entre fuentes (ticket <-> historia <-> PR/commit)                  |
| - Embeddings por campo + índices léxicos                                      |
+-----------------------------------+--------------------------------------------+
                                    |
                                    v
+--------------------------------------------------------------------------------+
|             PostgreSQL + pgvector (infra de [CLIENTE])                        |
| Tabla: case_index (multifuente)                                                |
| - source_type, source_id, project_id, repo, links_relacionados                |
| - sintoma, diagnostico, solucion, modulo, contexto_tecnico                    |
| - embeddings vector(3072) + tsvector español + índice HNSW                    |
+-----------------------------------+--------------------------------------------+
                                    |
                                    v
+--------------------------------------------------------------------------------+
|                    Servicio de búsqueda (FastAPI)                              |
| 1. Embedding consulta                                                          |
| 2. Búsqueda híbrida en PG (densa + léxica)                                    |
| 3. Fusión RRF                                                                  |
| 4. Rerank top-50 con Cohere                                                    |
| 5. Devuelve top-5 casos con síntoma + solución + trazabilidad de fuente       |
+-----------------------------------+--------------------------------------------+
                                    |
                                    v
+--------------------------------------------------------------------------------+
|               Módulo Odoo (final) o Extensión navegador (piloto)              |
+--------------------------------------------------------------------------------+

APIs externas: OpenAI (embeddings), Cohere (rerank), Anthropic (extracción)
```

### Decisiones pendientes de validación

**[Pendiente de validación]** Calidad de la extracción estructurada multifuente

**Validación necesaria:** procesar una muestra representativa de tickets, historias de usuario y elementos de GitHub con el extractor LLM y revisar manualmente que los campos clave (síntoma/diagnóstico/solución/contexto técnico) salen consistentes. Es el hito de go/no-go del proyecto (Hito 2).

**Plan B:** si una fuente no alcanza calidad suficiente, se aplica refinado específico por fuente (filtrado de chatter, normalización de descripciones/gherkin, limpieza de texto técnico en PR/commits) y se reintenta. Si después de eso sigue sin funcionar, se ofrece al cliente parar el proyecto pagando solo lo ejecutado (Hitos 1 y 2 = 3.000 €) o continuar con alcance reducido. Decisión del cliente, sin penalización.

**[Pendiente de validación]** Acceso y trazabilidad entre las tres fuentes

**Validación necesaria:** confirmar acceso de lectura a Odoo Helpdesk/Project (vía PostgreSQL o XML-RPC) y a GitHub (API/tokens con permisos de lectura), además de validar que existe enlazado suficiente entre ticket, historia y código para explotar trazabilidad.

**Plan B:** si una vía de acceso no está disponible, se usa la alternativa (XML-RPC en Odoo, exportación/API en GitHub). Si el enlazado entre fuentes es bajo, se aplica vinculación heurística por IDs, referencias textuales y metadatos de proyecto. Sin impacto en el precio.

---

## 3. Entregables y precio

| # | Entregable | Descripción | Precio |
|---|------------|-------------|--------|
| 1 | Auditoría del corpus multifuente (discovery) | Análisis de las tres fuentes existentes: tickets de Helpdesk, historias de usuario (proyectos/tareas/subtareas) y repositorios GitHub enlazados. Incluye distribución, calidad de texto, ratio señal/ruido, estructura de subtareas y trazabilidad entre fuentes. Documento entregado con muestras concretas y plan de extracción afinado. | 1.500 € |
| 2 | Validación del extractor (go/no-go) | Procesado de una muestra representativa multifuente (tickets + historias + elementos de GitHub) con el extractor LLM. Revisión manual de calidad de campos extraídos. Decisión conjunta con [CLIENTE] de continuar o parar el proyecto. Si se para, lo entregado hasta aquí queda como auditoría útil. | 1.500 € |
| 3 | Pipeline de indexación con extracción estructurada | Procesamiento completo de las tres fuentes con LLM (campos síntoma / diagnóstico / solución / módulo, y campos técnicos de historia/código cuando aplique). Embeddings generados con OpenAI por campo. Almacenamiento en PostgreSQL con `pgvector` y `tsvector` para búsqueda léxica. Reejecutable bajo demanda. | 5.500 € |
| 4 | Servicio de búsqueda híbrida + reranking | Endpoint FastAPI desplegado en infraestructura de [CLIENTE]. Recibe el texto de un ticket nuevo, ejecuta búsqueda híbrida (densa + léxica con RRF), reordena con Cohere y devuelve los 5 tickets más relevantes con score, síntoma original y solución aplicada. | 3.500 € |
| 5 | Extensión de navegador (piloto) | Extensión que inyecta el panel de sugerencias en la vista de ticket de Helpdesk cuando el agente está navegando en Odoo. Despliegue inmediato sin tocar Odoo. Permite arrancar el piloto en semana 6 con agentes reales. | 2.500 € |
| 6 | Detección de patrones recurrentes | Clustering one-shot sobre los embeddings (HDBSCAN) para identificar los 20-50 patrones de problema más frecuentes. Cuando un ticket nuevo encaja en un patrón conocido, el panel lo indica explícitamente: "patrón recurrente, X casos previos, solución estandarizada". | 2.000 € |
| 7 | Módulo Odoo nativo (producción) | Módulo custom de Odoo que añade en el formulario del ticket el panel de sugerencias integrado de forma nativa. Sustituye a la extensión tras el piloto. Compatible con la versión de Odoo de [CLIENTE]. Registra interacción con sugerencias para métricas. | 3.500 € |
| 8 | Indexación incremental + panel de métricas | Job programado que mantiene el índice actualizado al cerrarse nuevos tickets resueltos. Dashboard interno con uso del sistema por agente, tasa de clic en sugerencias, distribución de scores y gaps de conocimiento (tickets sin sugerencias relevantes). | 2.000 € |
| | | **Total** | **22.000 €** |

### Extensiones opcionales

| # | Extensión | Descripción | Precio |
|---|-----------|-------------|--------|
| A | Generación de respuesta sugerida (RAG) | El sistema redacta una propuesta de respuesta para el agente basada en los tickets relevantes, con citación explícita de qué ticket aporta cada parte. Para uso interno del agente, no para cliente final automático. | 6.500 € |
| B | Soporte y mantenimiento evolutivo (12 meses) | Monitorización del servicio, ajuste de umbrales de relevancia, corrección de defectos, actualización de modelos cuando salgan versiones mejores. | 3.600 € (300 €/mes) |
| C | Formación al equipo de soporte | Sesión de 2 horas con el equipo de agentes explicando cómo usar el sistema, qué significa cada score, cómo dar feedback. Material entregado. | 600 € |

### Costes operativos recurrentes (no incluidos, los paga [CLIENTE] directamente)

| Concepto | Coste estimado |
|----------|----------------|
| OpenAI embeddings (consultas + reindexado incremental) | < 10 € / mes |
| Cohere rerank | < 15 € / mes |
| Anthropic (extracción inicial one-shot + incrementales) | < 30 € / mes |

Estos costes están en cuentas directas de [CLIENTE], no se facturan a través de Punt. Las cifras son `[estimación]` basada en volumen actual; se afinan tras el primer mes de uso real.

---

## 4. Timeline e hitos

Duración total: **10 semanas**.

| Semana | Hito | Entregable | Verificación por [CLIENTE] |
|--------|------|------------|----------------------------|
| 1-2 | Auditoría del corpus | Documento de auditoría multifuente con muestras y recomendaciones | El cliente recibe el documento, revisa los hallazgos y los confirma con su equipo de soporte |
| 3 | **Go / no-go** | Muestra multifuente procesada con extracción estructurada. Reunión de revisión conjunta. | El cliente revisa una muestra de casos estructurados y valida que la extracción captura correctamente síntoma y solución, además de contexto de historia/código cuando aplica. Decisión de continuar o parar. |
| 4-5 | Indexación completa operativa | Fuentes principales indexadas con embeddings y campos estructurados. Script reejecutable. | Punt enseña una consulta que devuelve los top-5 casos para una descripción de prueba escrita por el cliente |
| 6 | Servicio de búsqueda en producción | Endpoint FastAPI accesible desde la red interna de [CLIENTE] | El cliente prueba 20 descripciones de tickets reales contra el endpoint y evalúa subjetivamente la calidad de las sugerencias (ejercicio guiado) |
| 7 | **Piloto con extensión de navegador** | Extensión instalada en los navegadores del equipo de soporte. Sistema en uso real. | Un grupo de agentes usa el sistema en tickets reales durante 2 semanas. Se recoge feedback. |
| 8 | Detección de patrones recurrentes | Sistema mejorado en producción. Patrones recurrentes identificados y marcados en el panel. | Comparativa A/B sobre 30 tickets de prueba: el cliente compara calidad de sugerencias con y sin agrupación por patrón |
| 9 | Módulo Odoo nativo | Módulo custom instalado en producción. Sustituye a la extensión. | Validación funcional en formulario de ticket real |
| 10 | Indexación incremental + métricas + cierre | Job programado funcionando. Dashboard accesible. Documentación final entregada. | Reunión de cierre con métricas reales del piloto |

**Dependencias del cliente:**
- Semana 1: acceso de lectura a la BD de Odoo o a XML-RPC, acceso a proyectos/historias y repositorios GitHub relacionados
- Semana 3: disponibilidad para reunión de go/no-go (1-2 horas)
- Semana 7: equipo de agentes disponible para el piloto
- Semana 9: ventana de despliegue del módulo en producción

---

## 5. Criterios de éxito

| Criterio | Métrica | Umbral de éxito | Cómo se mide |
|----------|---------|-----------------|--------------|
| Calidad de la extracción estructurada | % de elementos de la muestra multifuente con campos clave correctamente extraídos | ≥ 80% | Revisión manual conjunta en Hito 2 |
| Cobertura de indexación | % de elementos relevantes de las tres fuentes correctamente indexados | ≥ 95% | Conteo SQL en BD vs total de elementos objetivo en el periodo |
| Latencia de respuesta | Tiempo desde apertura del ticket hasta sugerencias mostradas en el panel | < 2 segundos en p95 | Logs del endpoint durante 1 semana de uso real |
| Relevancia subjetiva | % de sugerencias valoradas como "útiles" o "muy útiles" por el agente sobre 50 tickets de evaluación | ≥ 65% | Encuesta integrada en el panel durante el piloto (semana 6-7) |
| Adopción | % de tickets nuevos en los que el agente clica al menos una sugerencia | ≥ 30% al cabo de 3 semanas de uso | Métrica del dashboard de calidad |

Los umbrales de relevancia subjetiva y adopción son `[estimación]` basada en proyectos similares. Se afinan con baseline real durante el piloto.

---

## 6. Supuestos y dependencias

**Supuestos técnicos:**
- La versión de Odoo de [CLIENTE] es Odoo 16, 17 o 18 con los módulos Helpdesk y Project. Si fuera una versión anterior o un entorno custom no estándar, el módulo Odoo del Hito 7 requiere ajustes adicionales no contemplados.
- PostgreSQL de Odoo permite instalar la extensión pgvector, o existe la posibilidad de usar una BD PostgreSQL separada para el índice (en infraestructura de [CLIENTE]).
- El servidor donde corre Odoo o uno accesible desde él tiene Python 3.10+ y permite ejecutar el servicio FastAPI.
- Se dispone de acceso de lectura a GitHub (repositorios objetivo, PRs, commits e issues) mediante token de servicio.

**Supuestos de negocio:**
- El equipo de soporte tiene disposición a usar el sistema. Si la adopción depende de un cambio cultural fuerte, hay que planificarlo aparte (no incluido).
- El histórico multifuente (tickets, historias y repositorios) contiene mayoritariamente casos útiles y bien trazados. Si una fracción significativa carece de solución real o trazabilidad, el corpus es de menor calidad de la esperada y los criterios de relevancia subjetiva se ajustan a la baja.

**Dependencias del cliente:**
- Acceso a Odoo Helpdesk y Odoo Project (lectura BD o XML-RPC) en semana 1
- Acceso de lectura a repositorios GitHub y token/API en semana 1
- Cuentas activas en OpenAI, Cohere y Anthropic (Punt ayuda a darlas de alta si no existen)
- Disponibilidad para reunión de go/no-go en semana 3
- Equipo de agentes disponible para piloto en semana 7

**Si algún supuesto falla:** se comunica a [CLIENTE] en cuanto se detecte y se acuerda ajuste de alcance o presupuesto antes de continuar.

---

## 7. Exclusiones

- **No incluye traducción de contenidos a otros idiomas.** El sistema funciona en español. Contenidos en otros idiomas se procesan pero la calidad de retrieval baja.
- **No incluye respuesta automática al cliente final.** El sistema asiste al agente, no responde directamente al cliente. Esto se descarta deliberadamente por riesgo de alucinaciones del LLM en soporte técnico. Si en el futuro [CLIENTE] quiere ese paso, se evalúa como proyecto separado tras validar calidad (extensión opcional A).
- **No incluye fine-tuning de modelos.** Se usan modelos generalistas con RAG. Para 45.000 tickets, fine-tuning no aporta calidad suficiente para justificar el coste y la complejidad operativa.
- **No incluye limpieza retroactiva de datos de origen mal documentados.** Si hay tickets, historias o referencias de código sin solución real o con metadata incorrecta, el sistema los indexa tal cual están.
- **La extensión de navegador del piloto** es funcional para el periodo de prueba pero no es la entrega definitiva. La entrega definitiva es el módulo Odoo nativo (Hito 7). El navegador soportado por la extensión se decide al inicio del proyecto en función del entorno de [CLIENTE].
- **No incluye soporte ni evolutivo después de la entrega final.** Disponible como extensión opcional B.

---

## 8. Condiciones

- **Forma de pago:** 30% al inicio (firma de la propuesta), 30% al cierre del piloto (Hito 6), 40% al cierre del proyecto (Hito 9).
- **Punto de salida sin penalización:** si en el Hito 2 (go/no-go) la validación de extracción falla y [CLIENTE] decide parar el proyecto, solo se factura el trabajo ejecutado hasta ese punto (3.000 €). El 30% inicial se aplica contra esa factura.
- **Validez de la oferta:** 60 días desde la fecha de emisión.
- **Propiedad:** todo el código entregado (pipelines, servicio FastAPI, extensión, módulo Odoo) pasa a propiedad de [CLIENTE]. Punt mantiene el derecho a reutilizar componentes genéricos en otros proyectos.
- **Confidencialidad:** los datos de [CLIENTE] (tickets, historias y referencias de código) solo se usan para entrenar el índice del propio [CLIENTE]. No se comparten con terceros más allá de las APIs de OpenAI, Cohere y Anthropic, que operan bajo sus propias políticas de no entrenamiento sobre datos de API.
- **Costes operativos de APIs:** corren por cuenta directa de [CLIENTE] en sus propias cuentas. Punt no factura por consumo de APIs externas.






