<div align="center">

<img src="https://raw.githubusercontent.com/grafana/grafana/main/public/img/grafana_icon.svg" width="90" />

# SRE — Observabilidade

**Curso prático de Site Reliability Engineering e Observability em Kubernetes**

Construa um laboratório do zero, instrumente uma aplicação em duas etapas,<br/>
correlacione Metrics → Traces → Logs e feche o ciclo com alerting e postmortem.

![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.35-326CE5?logo=kubernetes&logoColor=white)
![Prometheus](https://img.shields.io/badge/Prometheus-E6522C?logo=prometheus&logoColor=white)
![Grafana](https://img.shields.io/badge/Grafana-F46800?logo=grafana&logoColor=white)
![Loki](https://img.shields.io/badge/Loki-F46800?logo=grafana&logoColor=white)
![Tempo](https://img.shields.io/badge/Tempo-F46800?logo=grafana&logoColor=white)
![OpenTelemetry](https://img.shields.io/badge/OpenTelemetry-425CC7?logo=opentelemetry&logoColor=white)
![Python](https://img.shields.io/badge/Flask-000000?logo=flask&logoColor=white)
![AWS SES](https://img.shields.io/badge/AWS%20SES-FF9900?logo=amazonaws&logoColor=white)

![Módulos](https://img.shields.io/badge/módulos-16-success)
![Nível](https://img.shields.io/badge/nível-intermediário-blue)
![Idioma](https://img.shields.io/badge/idioma-português-green)

</div>

---

> **Objetivo do curso:** construir um laboratório do zero, instrumentar uma aplicação em duas etapas (`v1` e `v2`), criar dashboards, definir SLI/SLO/Error Budget, correlacionar Metrics → Traces → Logs e finalizar com alerting, Incident Response, Runbook e Postmortem.

---

## Filosofia do curso

Este material não é uma lista de comandos para copiar e colar sem entender.

Em cada módulo você encontrará:

1. **Objetivo** — o que estamos construindo.
2. **Teoria** — por que aquilo existe.
3. **Passo a passo** — todos os comandos utilizados.
4. **Validação** — como confirmar que funcionou.
5. **Troubleshooting** — erros reais encontrados durante a construção do laboratório.
6. **Checkpoint** — o que você deve saber antes de avançar.

---

## Arquitetura final

```mermaid
flowchart TD
    APP["sre-demo v2<br/>Flask / Python"]

    APP -->|"/metrics"| PROM["Prometheus"]
    APP -->|"stdout JSON"| ALLOY["Grafana Alloy"]
    APP -->|"OTLP/HTTP"| OTEL["OTel Collector"]

    ALLOY --> LOKI["Loki"]
    OTEL --> TEMPO["Tempo"]

    PROM --> GRAF["Grafana"]
    LOKI --> GRAF
    TEMPO --> GRAF

    PROM --> AM["Alertmanager"]
    AM --> SES["AWS SES"]
    SES --> MAIL["E-mail"]

    classDef metrics fill:#E6522C,stroke:#B33F22,color:#fff
    classDef logs fill:#F46800,stroke:#C25200,color:#fff
    classDef traces fill:#425CC7,stroke:#2E4191,color:#fff
    classDef viz fill:#F46800,stroke:#C25200,color:#fff
    classDef alert fill:#FF9900,stroke:#CC7A00,color:#fff
    classDef app fill:#306998,stroke:#20456A,color:#fff

    class APP app
    class PROM metrics
    class ALLOY,LOKI logs
    class OTEL,TEMPO traces
    class GRAF viz
    class AM,SES,MAIL alert
```

<div align="center">

**metrics** → Prometheus  ·  **logs** → Alloy → Loki  ·  **traces** → OTel → Tempo  ·  tudo correlacionado no Grafana

</div>

---

## Evolução da aplicação

### App v1 — observabilidade básica

`alanmosilva/sre-demo:v1`

```mermaid
flowchart LR
    A["Aplicação"] -->|"/metrics"| P["Prometheus"] --> G["Grafana"]

    classDef a fill:#306998,stroke:#20456A,color:#fff
    classDef p fill:#E6522C,stroke:#B33F22,color:#fff
    classDef g fill:#F46800,stroke:#C25200,color:#fff
    class A a
    class P p
    class G g
```

Você aprenderá:

- Counter, Gauge e Histogram;
- PromQL;
- RPS;
- Error Rate;
- Availability;
- p95/p99;
- dashboard básico.

### App v2 — telemetria completa

`alanmosilva/sre-demo:v2`

```mermaid
flowchart LR
    A["Aplicação"]
    A -->|"metrics"| P["Prometheus"]
    A -->|"logs"| AL["Alloy"] --> L["Loki"]
    A -->|"traces"| O["OTel Collector"] --> T["Tempo"]

    P --> G["Grafana"]
    L --> G
    T --> G

    classDef a fill:#306998,stroke:#20456A,color:#fff
    classDef p fill:#E6522C,stroke:#B33F22,color:#fff
    classDef l fill:#F46800,stroke:#C25200,color:#fff
    classDef t fill:#425CC7,stroke:#2E4191,color:#fff
    class A a
    class P p
    class AL,L,G l
    class O,T t
```

Além disso:

- logs estruturados JSON;
- `trace_id` e `span_id`;
- OpenTelemetry;
- TraceQL;
- LogQL;
- Exemplars;
- Prometheus → Tempo;
- Loki → Tempo;
- Tempo → Loki;
- dashboard profissional;
- SLO / Error Budget / Burn Rate;
- HPA e saturação;
- alertas via AWS SES;
- Runbook;
- MTTD / MTTA / MTTR;
- Postmortem.

---

## Módulos

| # | Módulo |
|---|---|
| 01 | Fundamentos de SRE, Observability e Telemetria |
| 02 | Preparando o cluster kubeadm |
| 03 | Prometheus e Grafana com persistência |
| 04 | App v1 + Docker Hub |
| 05 | Dashboard básico + PromQL |
| 06 | SLI, SLO, SLA, Error Budget e Burn Rate |
| 07 | Construindo a App v2 |
| 08 | Logs com Loki + Grafana Alloy |
| 09 | Traces com Tempo + OpenTelemetry Collector |
| 10 | Deploy da App v2 e validação da telemetria |
| 11 | Correlação Metrics → Traces → Logs e Exemplars |
| 12 | Dashboard SRE profissional + HPA + saturação |
| 13 | Alerting com PrometheusRule + Alertmanager + AWS SES |
| 14 | Incident Response + Severidade + Runbook |
| 15 | MTTD, MTTA, MTTR + Postmortem + GameDay |
| 16 | Troubleshooting real do laboratório |

---

## Convenções usadas

- Namespace da aplicação: `sre-lab`
- Namespace Prometheus/Grafana: `monitoring`
- Namespace Loki: `loki`
- Namespace Alloy: `alloy`
- Namespace Tempo: `tempo`
- Namespace OTel Collector: `otel`
- Docker Hub: `alanmosilva/sre-demo`
- Kubernetes: `v1.35`
- Pod CIDR: `10.244.0.0/16`
- AWS Region: `sa-east-1`

---

## Ordem recomendada

Execute os módulos em sequência. Não pule diretamente para Loki/Tempo sem antes validar a App v1 e Prometheus.

O objetivo é aprender a evolução da observabilidade, não apenas chegar ao resultado final.
