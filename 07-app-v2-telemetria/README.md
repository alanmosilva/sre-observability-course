# Módulo 07 — Construindo a App v2 com telemetria

## Objetivo

Evoluir a aplicação para:

```text
alanmosilva/sre-demo:v2
```

A v2 adiciona:

- `/healthz`;
- `/cpu`;
- `/exception`;
- logs JSON estruturados;
- `request_id`;
- `trace_id`;
- `span_id`;
- OpenTelemetry SDK;
- spans customizados;
- OpenMetrics;
- Prometheus Exemplars.

---

## 1. O que muda conceitualmente?

A v1 respondia principalmente:

> Existe problema?

A v2 permite também responder:

> Qual request representa o problema?

> Onde ela ficou lenta?

> Qual log pertence exatamente àquele trace?

---

## 2. Logs estruturados

Exemplo produzido pela aplicação:

```json
{
  "timestamp":"2026-09-05T...",
  "level":"ERROR",
  "event":"http_request",
  "service":"sre-demo",
  "route":"/error",
  "status":500,
  "duration_ms":12.3,
  "trace_id":"...",
  "span_id":"..."
}
```

O `trace_id` permanece dentro do JSON.

**Não transforme `trace_id` em label do Loki**, pois cada request tem um valor diferente e isso gera alta cardinalidade.

---

## 3. OpenTelemetry

A aplicação exporta traces por OTLP/HTTP para:

```text
http://otel-collector.otel.svc.cluster.local:4318/v1/traces
```

---

## 4. Spans customizados

`/slow`:

```text
GET /slow
└── simulated.wait
```

`/cpu`:

```text
GET /cpu
└── simulated.cpu_work
```

---

## 5. Exemplars

A observação do Histogram recebe:

```python
exemplar={"trace_id": trace_id}
```

Isso cria a ponte:

```text
Prometheus metric
   ↓ exemplar
Tempo trace
```

---

## 6. Build

```bash
cd app

docker build -t alanmosilva/sre-demo:v2 .
```

---

## 7. Testar imagem localmente

Sem OTel Collector disponível localmente, a aplicação ainda sobe; o exporter pode registrar falhas de envio.

```bash
docker run --rm -p 8080:8080 alanmosilva/sre-demo:v2
```

Teste:

```bash
curl http://localhost:8080/
curl http://localhost:8080/healthz
curl http://localhost:8080/slow
curl http://localhost:8080/cpu
curl -i http://localhost:8080/error
curl -i http://localhost:8080/exception
```

---

## 8. Push

```bash
docker push alanmosilva/sre-demo:v2
```

No Docker Hub agora teremos:

```text
alanmosilva/sre-demo:v1
alanmosilva/sre-demo:v2
```

Ainda não faremos deploy da v2. Primeiro instalaremos Loki, Alloy, Tempo e OTel Collector.
