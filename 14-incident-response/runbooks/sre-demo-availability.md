# Runbook — SREDemoAvailabilityFastBurn

## 1. Objetivo

Este runbook orienta a resposta ao alerta:

```text
SREDemoAvailabilityFastBurn
```

O alerta indica que o serviço `sre-demo` está consumindo rapidamente o **Error Budget de Availability** e pode violar o SLO de disponibilidade.

Este documento deve ser usado durante incidentes para reduzir tempo de diagnóstico, evitar investigação aleatória e padronizar a resposta do time SRE.

---

## 2. Escopo

**Serviço:** `sre-demo`  
**Namespace da aplicação:** `sre-lab`  
**Namespace de observabilidade:** `monitoring`  
**SLO de Availability:** `99.9%`  
**Error Budget:** `0.1%`  
**Alerta:** `SREDemoAvailabilityFastBurn`  
**Severidade inicial:** `SEV2`  
**Time responsável:** `SRE`

---

## 3. O que este alerta significa

O alerta dispara quando a taxa de erros HTTP `5xx` está consumindo o Error Budget de Availability rápido demais.

```text
Error Ratio
    ÷
Error Budget permitido
    =
Burn Rate
```

Para um SLO de `99.9%`, o Error Budget é `0.1%` (`0.001`).

O alerta atual considera um **Fast Burn** quando o Burn Rate fica acima de `14.4x` nas janelas configuradas.

---

## 4. Classificação de severidade

### SEV1
- indisponibilidade total ou quase total;
- impacto amplo e crítico;
- falha de serviço essencial;
- ausência de workaround;
- resposta imediata.

### SEV2
- degradação relevante;
- aumento importante de erros;
- SLO em risco;
- Burn Rate elevado;
- serviço ainda parcialmente disponível.

O `SREDemoAvailabilityFastBurn` deve iniciar como `SEV2` e pode ser promovido para `SEV1`.

### SEV3
- degradação menor;
- impacto limitado;
- sem risco imediato significativo ao SLO.

---

# 5. Primeiros 5 minutos

## Passo 1 — Confirmar que o alerta está firing

```bash
kubectl exec -n sre-lab loadgen -- curl -sG 'http://monitoring-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090/api/v1/query' --data-urlencode 'query=ALERTS{alertname="SREDemoAvailabilityFastBurn"}'
```

Procure:

```text
alertstate="firing"
```

## Passo 2 — Confirmar impacto no Grafana

Abra o dashboard SRE e verifique primeiro:

```text
Availability
Error Rate
Latency p95
Latency p99
Availability Burn Rate
Latency Burn Rate
Traffic / RPS
```

A primeira pergunta deve ser:

> Existe impacto real para o usuário?

## Passo 3 — Avaliar Availability e Error Rate

Exemplo:

```text
Availability = 96.1%
Error Rate   = 3.9%
```

Para nosso SLO de `99.9%`, isso representa forte degradação.

---

# 6. Verificar saturação e capacidade

## HPA

```bash
kubectl get hpa sre-demo -n sre-lab
```

Exemplo:

```text
cpu: 234%/70%
REPLICAS: 5
MAXPODS: 5
```

Interpretação:

```text
HPA reagiu
+
atingiu maxReplicas
+
CPU continua alta
=
serviço saturado
```

## CPU e memória dos Pods

```bash
kubectl top pods -n sre-lab -l app=sre-demo
```

## Estado dos Pods

```bash
kubectl get pods -n sre-lab -l app=sre-demo -o wide
```

Verifique `READY`, `STATUS`, `RESTARTS` e `NODE`.

## Eventos recentes

```bash
kubectl get events -n sre-lab   --sort-by=.lastTimestamp   | tail -30
```

Procure por `OOMKilled`, `FailedScheduling`, `Unhealthy`, `BackOff`, `Evicted` e `FailedMount`.

---

# 7. Investigar métricas — Prometheus

## RPS

```promql
sum(rate(sre_demo_http_requests_total[5m]))
```

## Erros 5xx

```promql
sum(rate(sre_demo_http_requests_total{status=~"5.."}[5m]))
```

## Error Ratio

```promql
sum(rate(sre_demo_http_requests_total{status=~"5.."}[5m]))
/
clamp_min(sum(rate(sre_demo_http_requests_total[5m])), 0.000001)
```

## Availability

```promql
1 -
(
  sum(rate(sre_demo_http_requests_total{status=~"5.."}[5m]))
  /
  clamp_min(sum(rate(sre_demo_http_requests_total[5m])), 0.000001)
)
```

## p95

```promql
histogram_quantile(
  0.95,
  sum by (le) (
    rate(sre_demo_http_request_duration_seconds_bucket[5m])
  )
)
```

## p99

```promql
histogram_quantile(
  0.99,
  sum by (le) (
    rate(sre_demo_http_request_duration_seconds_bucket[5m])
  )
)
```

---

# 8. Exemplar → Tempo

Quando houver exemplar no gráfico de latência:

```text
Prometheus
   ↓
Exemplar
   ↓
View Trace
   ↓
Tempo
```

Procure por traces como:

```text
GET /slow
GET /cpu
GET /error
GET /exception
```

## TraceQL útil

### Traces do serviço

```traceql
{ resource.service.name = "sre-demo" }
```

### Traces lentos

```traceql
{ resource.service.name = "sre-demo" && trace:duration > 500ms }
```

### Trace de /slow

```traceql
{
  resource.service.name = "sre-demo"
  &&
  span."http.route" = "/slow"
}
```

---

# 9. Tempo → Loki

Pegue o `trace_id` do trace investigado.

```logql
{namespace="sre-lab", app="sre-demo"}
| json
| trace_id="COLE_O_TRACE_ID"
```

## Logs 5xx

```logql
{namespace="sre-lab", app="sre-demo"}
| json
| status >= 500
```

## Requests lentas

```logql
{namespace="sre-lab", app="sre-demo"}
| json
| duration_ms > 500
```

---

# 10. Hipóteses comuns

## CPU saturada

Sinais:

```text
CPU alta
HPA escalando
HPA no maxReplicas
p95/p99 altos
throughput degradado
```

Ação:
- confirmar se HPA atingiu o teto;
- verificar capacidade do cluster;
- avaliar aumento temporário de replicas;
- identificar endpoint de maior custo.

## Aplicação retornando 5xx

Sinais:

```text
Error Rate alto
Availability baixa
logs com status 500
traces com status error
```

Ação:
- identificar rota;
- localizar trace;
- correlacionar com logs;
- determinar se problema é aplicação ou dependência.

## Memória / OOMKilled

```bash
kubectl describe pod -n sre-lab POD
```

Ação:
- verificar `requests/limits`;
- analisar consumo;
- investigar vazamento ou sizing inadequado.

## Problema de readiness

```bash
kubectl get pods -n sre-lab
kubectl get endpointslice -n sre-lab   -l kubernetes.io/service-name=sre-demo
```

---

# 11. Mitigação

A prioridade durante incidente é:

> Restaurar o serviço primeiro. Investigar profundamente depois.

## Aumentar temporariamente o HPA

```bash
kubectl patch hpa sre-demo -n sre-lab   --type=merge   -p '{"spec":{"maxReplicas":10}}'
```

Use somente se houver capacidade no cluster.

## Escalar manualmente

```bash
kubectl scale deployment sre-demo   -n sre-lab   --replicas=5
```

Lembre que o HPA pode alterar novamente a quantidade de réplicas.

## Rollback

```bash
kubectl rollout history deployment/sre-demo -n sre-lab
```

```bash
kubectl rollout undo deployment/sre-demo -n sre-lab
```

## Reiniciar aplicação

Não use restart como primeira solução sem diagnóstico.

```bash
kubectl rollout restart deployment/sre-demo -n sre-lab
kubectl rollout status deployment/sre-demo -n sre-lab
```

---

# 12. Confirmar recuperação

Não considere o incidente resolvido apenas porque uma ação foi executada.

Confirme:

```text
Availability recuperou
Error Rate caiu
p95/p99 normalizaram
Burn Rate caiu
Pods saudáveis
HPA estabilizou
alerta saiu de firing
```

## Verificar alerta

```bash
kubectl exec -n sre-lab loadgen -- curl -sG 'http://monitoring-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090/api/v1/query' --data-urlencode 'query=ALERTS{alertname="SREDemoAvailabilityFastBurn"}'
```

Quando normalizado:

```text
result: []
```

---

# 13. E-mail RESOLVED

O Alertmanager está configurado com:

```yaml
sendResolved: true
```

Após recuperação:

```text
Prometheus
   ↓
Alertmanager
   ↓
AWS SES
   ↓
RESOLVED
```

---

# 14. Métricas do incidente

## MTTD — Mean Time To Detect

```text
hora em que o problema começou
→
hora em que o alerta disparou
```

## MTTA — Mean Time To Acknowledge

```text
hora do alerta
→
hora em que o SRE assumiu
```

## MTTR — Mean Time To Restore

```text
hora em que o problema começou
→
hora em que o serviço voltou ao normal
```

---

# 15. Registro mínimo do incidente

```text
Incident ID:
Data:
Serviço:
Severity:
Início:
Detecção:
Acknowledged:
Mitigação:
Recuperação:
MTTD:
MTTA:
MTTR:

Impacto:

Sintomas:

Causa provável:

Mitigação aplicada:

Evidências:
- Grafana:
- Prometheus:
- Tempo:
- Loki:
- kubectl:

Próximas ações:
```

---

# 16. Quando escalar

Escalar quando:
- causa estiver fora do domínio do SRE;
- banco de dados apresentar falha;
- dependência externa estiver indisponível;
- houver suspeita de problema de rede;
- capacidade do cluster estiver esgotada;
- rollback não resolver;
- impacto evoluir para SEV1.

---

# 17. O que NÃO fazer

Evite:

```text
reiniciar tudo sem diagnóstico
deletar Pods aleatoriamente
aumentar recursos sem confirmar saturação
desabilitar probes para "resolver"
silenciar alerta sem entender impacto
alterar produção sem registrar
```

---

# 18. Fluxo resumido

```text
ALERTA
  ↓
Confirmar FIRING
  ↓
Availability / Error Rate / Burn Rate
  ↓
SEV
  ↓
CPU / Memory / HPA / Pods
  ↓
Prometheus
  ↓
Exemplar
  ↓
Tempo
  ↓
trace_id
  ↓
Loki
  ↓
Causa provável
  ↓
Mitigação
  ↓
Validar recuperação
  ↓
RESOLVED
  ↓
MTTD / MTTA / MTTR
  ↓
Postmortem
```

---

# 19. Regra de ouro

```text
Primeiro determine o IMPACTO.

Depois encontre a CAUSA.

Em seguida MITIGUE.

Por último investigue profundamente e PREVINA recorrência.
```

O objetivo inicial do Incident Response é reduzir impacto e restaurar confiabilidade.
