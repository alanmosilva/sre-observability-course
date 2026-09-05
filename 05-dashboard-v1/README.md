# Módulo 05 — Dashboard básico da App v1

## Objetivo

Transformar as métricas da v1 em um dashboard operacional simples.

Arquivo:

```text
dashboard-v1-basic.json
```

---

## 1. Importar dashboard

No Grafana:

```text
Dashboards → New → Import
```

Faça upload de:

```text
dashboard-v1-basic.json
```

---

## 2. Queries principais

### Traffic / RPS

```promql
sum(rate(sre_demo_http_requests_total[5m]))
```

### Error Rate

```promql
100 *
sum(rate(sre_demo_http_requests_total{status=~"5.."}[5m]))
/
clamp_min(sum(rate(sre_demo_http_requests_total[5m])), 0.000001)
```

### Availability

```promql
100 *
(
  1 -
  sum(rate(sre_demo_http_requests_total{status=~"5.."}[5m]))
  /
  clamp_min(sum(rate(sre_demo_http_requests_total[5m])), 0.000001)
)
```

### p95

```promql
histogram_quantile(
  0.95,
  sum by (le) (
    rate(sre_demo_http_request_duration_seconds_bucket[5m])
  )
)
```

### p99

```promql
histogram_quantile(
  0.99,
  sum by (le) (
    rate(sre_demo_http_request_duration_seconds_bucket[5m])
  )
)
```

---

## 3. Como interpretar p95/p99

Se:

```text
p95 = 400ms
```

significa que aproximadamente 95% das requests ficaram abaixo desse tempo.

Se:

```text
p99 = 2s
```

1% das requests foi ainda mais lenta.

Não confunda percentil com média.

---

## Checkpoint

Você deve conseguir provocar `/error` e `/slow` e enxergar:

```text
/error → Error Rate sobe / Availability cai
/slow  → p95/p99 sobem
```
