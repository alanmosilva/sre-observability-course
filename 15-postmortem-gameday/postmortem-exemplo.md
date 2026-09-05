# Postmortem — SREDemo Availability Incident

## Incident ID
`INC-SRE-DEMO-2026-09-03-001`

## Status
**Resolved**

## Severity
**SEV1**

## Service
`sre-demo`

## Namespace
`sre-lab`

## Date
2026-09-03

---

# 1. Executive Summary

Em 03/09/2026 foi executado um exercício controlado de Incident Response no serviço `sre-demo`.

O incidente foi provocado por um gerador sintético de falhas (`incident-generator`) enviando requisições continuamente para o endpoint `/error`.

Durante o incidente, o serviço apresentou degradação severa:

```text
Availability:              16.357%
Error Rate:                83.531%
Latency p95:               21.744s
Latency p99:               29.311s
Availability Burn Rate:    836.4x
Latency Burn Rate:         16.4x
Availability Budget Left:  0%
Latency Budget Left:       0%
Traffic:                   7.73 req/s
```

O alerta `SREDemoAvailabilityFastBurn` foi detectado pelo Prometheus, roteado pelo Alertmanager e entregue por e-mail via AWS SES.

A fonte de falha foi removida e o serviço foi restaurado.

---

# 2. Impact

Durante o incidente:

- aproximadamente 83.5% das requisições observadas estavam falhando;
- Availability caiu para aproximadamente 16.4%;
- p95 ultrapassou 21 segundos;
- p99 ultrapassou 29 segundos;
- o Error Budget de Availability foi completamente consumido;
- o Availability Burn Rate chegou a 836.4x;
- o Latency Burn Rate chegou a 16.4x.

Em um ambiente de produção, esse nível de degradação seria considerado impacto crítico aos usuários.

---

# 3. Detection

O incidente foi detectado automaticamente pelo alerta:

```text
SREDemoAvailabilityFastBurn
```

Pipeline:

```text
PrometheusRule
      ↓
Prometheus
      ↓
Alertmanager
      ↓
AWS SES
      ↓
E-mail
```

Labels principais:

```text
service  = sre-demo
severity = critical
team     = sre
slo      = availability
```

---

# 4. Timeline

Todos os horários abaixo estão em UTC.

| Evento | Horário | Tempo desde T0 |
|---|---:|---:|
| Incident Start | 18:49:53 | 00:00 |
| Detected | 18:50:27 | 00:34 |
| Acknowledged | 18:51:00 | 01:07 |
| Mitigation Start | 19:21:55 | 32:02 |
| Service Restored | 19:27:56 | 38:03 |

---

# 5. Incident Metrics

## MTTD — Mean Time To Detect
`34 segundos`

## MTTA — Mean Time To Acknowledge
`33 segundos`

## MTTR — Mean Time To Restore
`38 minutos e 3 segundos`

## Mitigation → Restore
`6 minutos e 1 segundo`

---

# 6. Root Cause

A causa raiz neste exercício foi deliberada e controlada.

O Pod:

```text
incident-generator
```

foi criado para enviar continuamente requisições ao endpoint:

```text
/error
```

do serviço:

```text
sre-demo.sre-lab.svc.cluster.local
```

Esse endpoint retorna HTTP `500`.

A carga contínua elevou significativamente a proporção de respostas `5xx`, reduzindo a Availability e consumindo rapidamente o Error Budget definido pelo SLO.

---

# 7. Contributing Factors

## 7.1 Fault injection contínua

O gerador continuou enviando erros até a ação de mitigação.

## 7.2 Alta proporção de requisições de erro

A carga sintética foi propositalmente agressiva:

```text
Error Rate > 80%
```

## 7.3 Tempo elevado entre acknowledgement e mitigação

O incidente foi reconhecido às `18:51:00`, mas a mitigação começou às `19:21:55`.

Diferença:

```text
30m55s
```

Neste laboratório esse atraso foi deliberado para permitir análise, treinamento e validação do fluxo de observabilidade.

Em produção, esse intervalo seria excessivo para um SEV1.

---

# 8. What Worked Well

- O alerta baseado em Burn Rate detectou corretamente o impacto.
- O pipeline `Prometheus → Alertmanager → AWS SES → E-mail` funcionou.
- O dashboard mostrou Availability, Error Rate, p95, p99, Burn Rate, Error Budget e Traffic.
- A severidade foi corretamente elevada para `SEV1`.
- O runbook forneceu um fluxo consistente de investigação.

---

# 9. What Could Be Improved

## 9.1 Reduzir tempo até mitigação

Principal ponto de melhoria:

```text
Acknowledged → Mitigation Start = 30m55s
```

Em um incidente real, depois de confirmar impacto extremo, a prioridade deveria ser restaurar o serviço rapidamente.

## 9.2 Definir objetivos operacionais

Sugestão inicial para exercícios futuros:

```text
SEV1

MTTD  < 2 min
MTTA  < 5 min
Mitigation Start < 10 min
```

## 9.3 Corrigir painel Available Replicas

Durante o incidente o painel apresentou:

```text
No data
```

A query deve ser revisada.

## 9.4 Automatizar links operacionais

O alerta deve apontar para um `runbook_url` real e acessível.

---

# 10. Corrective Actions

| Prioridade | Ação | Tipo | Status |
|---|---|---|---|
| P1 | Corrigir painel `Available Replicas` | Observability | TODO |
| P1 | Versionar runbook em Git | Process | TODO |
| P1 | Adicionar `runbook_url` real ao alerta | Alerting | TODO |
| P2 | Criar alerta de Latency Fast Burn | Alerting | TODO |
| P2 | Criar regra de Slow Burn | Alerting | TODO |
| P2 | Definir objetivos internos de MTTD/MTTA/MTTR | Process | TODO |
| P3 | Criar template padrão de postmortem | Process | TODO |
| P3 | Realizar GameDay periódico | Reliability | TODO |

---

# 11. Lessons Learned

## Alertar por impacto é melhor do que alertar apenas por recurso

```text
CPU > 80%
```

não necessariamente representa impacto ao usuário.

Burn Rate elevado, por outro lado, demonstra risco ao SLO.

## Detection não é restoration

```text
MTTD = 34s
MTTR = 38m03s
```

Boa observabilidade reduz o tempo de detecção, mas processo e tomada de decisão determinam o tempo de recuperação.

## Mitigação vem antes da investigação perfeita

```text
Restaurar serviço
        ↓
Estabilizar
        ↓
Investigar profundamente
        ↓
Corrigir definitivamente
```

## Métricas, logs e traces possuem papéis diferentes

```text
Metrics → mostram QUE existe impacto.
Traces  → mostram ONDE ele ocorre.
Logs    → ajudam a explicar POR QUÊ.
```

## Postmortem não serve para procurar culpados

O objetivo é encontrar falhas técnicas, falhas de processo, lacunas de observabilidade, oportunidades de automação e formas de evitar recorrência.

---

# 12. Final Assessment

O exercício validou:

```text
Telemetry
   ↓
Prometheus
   ↓
SLO / Burn Rate
   ↓
PrometheusRule
   ↓
Alertmanager
   ↓
AWS SES
   ↓
Incident Detection
   ↓
SEV Classification
   ↓
Runbook
   ↓
Mitigation
   ↓
Recovery
   ↓
MTTD / MTTA / MTTR
   ↓
Postmortem
```

---

# 13. Status Final

```text
Incident: RESOLVED
Service: HEALTHY
Root Cause: CONTROLLED FAULT INJECTION
Follow-up Actions: OPEN
Postmortem: COMPLETED
```
