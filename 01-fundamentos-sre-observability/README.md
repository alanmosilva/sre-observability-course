# Módulo 01 — Fundamentos de SRE, Observability e Telemetria

## Objetivo

Antes de instalar qualquer ferramenta, precisamos entender o problema que estamos tentando resolver.

Neste módulo você aprenderá a diferença entre Monitoring e Observability, o papel da telemetria e como Metrics, Logs e Traces trabalham juntos.

---

## Introdução prática a métricas, logs, traces, telemetria e operação de sistemas modernos

> Este material foi escrito como o primeiro capítulo de um futuro curso prático de SRE e Observability.
> O objetivo não é apenas ensinar ferramentas, mas ensinar **como pensar como um SRE durante um incidente**.

---

# 1. Por que estudar SRE e Observability?

Sistemas modernos são distribuídos, dinâmicos e possuem várias camadas:

- aplicação;
- containers;
- Kubernetes;
- rede;
- banco de dados;
- cache;
- filas;
- APIs externas;
- cloud;
- usuários acessando tudo isso ao mesmo tempo.

Quando algo fica lento ou indisponível, raramente a pergunta correta é apenas:

> "A CPU está alta?"

A pergunta correta é:

> **"O usuário está sendo impactado? Onde está o problema? Por que ele está acontecendo? E qual é a ação mais rápida e segura para restaurar o serviço?"**

É exatamente nesse ponto que entram **SRE** e **Observability**.

---

# 2. O que é SRE?

**SRE (Site Reliability Engineering)** é uma disciplina de engenharia focada em manter sistemas confiáveis, disponíveis, rápidos e operáveis em escala.

Um SRE não trabalha apenas para "manter servidores no ar".

Ele trabalha para garantir que o serviço entregue a experiência esperada para o usuário e para o negócio.

Na prática, um SRE se preocupa com perguntas como:

- O serviço está disponível?
- Está respondendo rápido?
- Está retornando erros?
- Existe capacidade suficiente?
- O sistema está perto de saturar?
- O autoscaling está funcionando?
- O erro está em qual componente?
- O problema está consumindo nosso Error Budget?
- Devemos acordar alguém agora?
- Quanto tempo levamos para detectar e restaurar o serviço?
- Esse problema pode acontecer novamente?

SRE transforma confiabilidade em algo **mensurável**.

---

# 3. O que é Observability?

**Observability (Observabilidade)** é a capacidade de entender o estado interno de um sistema a partir dos sinais que ele produz.

Em outras palavras:

> Observabilidade é conseguir olhar para os dados do sistema e responder **o que está acontecendo e por quê**.

Ter um dashboard bonito não significa necessariamente ter observabilidade.

Um ambiente pode possuir centenas de gráficos e ainda assim ninguém conseguir responder rapidamente:

> "Por que o login está levando 8 segundos?"

Um ambiente observável permite seguir um caminho semelhante a este:

```text
Usuários reclamam de lentidão
        ↓
Prometheus mostra p95 alto
        ↓
Exemplar aponta uma request real
        ↓
Tempo mostra o trace
        ↓
Span mostra que uma chamada demorou 6s
        ↓
Loki mostra o erro/log daquele mesmo trace_id
        ↓
SRE encontra a causa
```

Esse fluxo é muito mais importante do que simplesmente "instalar Grafana".

---

# 4. Monitoring x Observability

Os termos são relacionados, mas não são exatamente iguais.

## Monitoring

Monitoring normalmente responde perguntas que já conhecemos.

Exemplos:

```text
CPU está acima de 80%?
O Pod está Running?
A memória passou de 1 GiB?
O endpoint responde?
```

São perguntas previamente definidas.

## Observability

Observability ajuda a investigar perguntas que talvez nem soubéssemos que precisaríamos fazer.

Exemplo:

```text
Por que somente algumas requisições de /checkout ficaram lentas
entre 14:02 e 14:07?
```

Para responder isso, podemos precisar correlacionar:

```text
métrica
+
trace
+
log
+
infraestrutura
```

Por isso, observabilidade é mais ampla que monitoring.

---

# 5. O que é Telemetria?

**Telemetria** é o conjunto de dados que um sistema produz e envia para que possamos observar seu comportamento.

Uma aplicação pode gerar telemetria como:

```text
Métricas
Logs
Traces
Eventos
Perfis
```

Podemos pensar assim:

```text
Aplicação
   ↓
gera telemetria
   ↓
coletor
   ↓
backend de observabilidade
   ↓
Grafana / plataforma de observabilidade
```

Exemplo:

```text
sre-demo
   ├── métricas ─────────────→ Prometheus
   ├── logs ─────→ Alloy ────→ Loki
   └── traces ───→ OTel ─────→ Tempo
                              ↓
                           Grafana
```

A telemetria é, portanto, a **matéria-prima da observabilidade**.

---

# 6. Os três sinais clássicos da observabilidade

Historicamente, a observabilidade é explicada usando três pilares principais:

```text
Metrics
Logs
Traces
```

Hoje existem outros sinais importantes, como profiles e events, mas esses três continuam sendo a base mais comum.

---

## 6.1 Metrics

Métricas são **números medidos ao longo do tempo**.

Exemplos:

```text
CPU = 620m
Memory = 180 MiB
Requests = 20 req/s
Error Rate = 1.2%
Availability = 99.95%
Latency p95 = 450 ms
```

As métricas são excelentes para responder:

> **"Existe um problema?"**

No nosso laboratório usamos:

```text
Prometheus
```

e consultamos usando:

```text
PromQL
```

Exemplo:

```promql
sum(rate(sre_demo_http_requests_total[5m]))
```

---

## 6.2 Logs

Logs são registros de eventos que aconteceram dentro do sistema.

Exemplo:

```json
{
  "level": "ERROR",
  "route": "/checkout",
  "status": 500,
  "duration_ms": 831,
  "trace_id": "b2fe643bc4d341a1f7076f265910e649"
}
```

Logs ajudam a responder:

> **"O que aconteceu?"**

No laboratório usamos:

```text
Alloy
   ↓
Loki
```

e consultamos usando:

```text
LogQL
```

Exemplo:

```logql
{namespace="sre-lab", app="sre-demo"}
| json
| status >= 500
```

---

## 6.3 Traces

Um trace representa o caminho completo de uma requisição.

Imagine:

```text
Usuário
  ↓
API Gateway
  ↓
Aplicação
  ↓
Redis
  ↓
Banco
  ↓
API externa
```

Cada etapa pode ser representada por um **span**.

Exemplo:

```text
GET /checkout              2.4s
├── validate_user          40ms
├── redis_lookup           15ms
├── mysql_query           180ms
└── payment_api           2.1s
```

Agora fica muito mais fácil perceber:

> "A aplicação não está lenta. A API de pagamento está consumindo 2.1 segundos."

No laboratório usamos:

```text
OpenTelemetry
      ↓
Tempo
```

e pesquisamos usando:

```text
TraceQL
```

Exemplo:

```traceql
{ resource.service.name = "sre-demo" && trace:duration > 500ms }
```

---

# 7. Metrics, Logs e Traces juntos

O grande objetivo não é escolher apenas um deles.

O objetivo é **correlacioná-los**.

A regra mental mais importante deste curso é:

```text
Métrica mostra QUE existe problema.
Trace mostra ONDE o problema está.
Log ajuda a explicar POR QUÊ.
```

Exemplo real:

```text
Prometheus:
Latency p95 = 12.2s
        ↓
Exemplar:
trace_id = abc123
        ↓
Tempo:
GET /cpu
└── simulated.cpu_work = 11.8s
        ↓
Loki:
trace_id=abc123
route=/cpu
duration_ms=11872
```

Isso é observabilidade funcionando de verdade.

---

# 8. Ferramentas utilizadas neste curso

A tabela abaixo apresenta as principais ferramentas do ecossistema que usamos ou discutimos. Não utilizamos Jaeger e nem Datadog

| Ferramenta | O que é de forma simples | Tipo de dado | Linguagem / consulta | Exemplo de uso |
|---|---|---|---|---|
| **Prometheus** | O termômetro do sistema. Mede indicadores continuamente. | Métricas | PromQL | CPU, RPS, Availability, Error Rate, p95 |
| **Loki** | O diário de bordo do sistema. Armazena e pesquisa logs. | Logs | LogQL | Procurar erros 500 ou um `trace_id` |
| **Tempo** | O GPS das requisições. Mostra por onde uma request passou. | Traces | TraceQL | Descobrir onde uma request lenta gastou tempo |
| **Jaeger** | Plataforma tradicional para distributed tracing. | Traces | UI/filtros | Investigar traces distribuídos |
| **OpenTelemetry** | Padrão aberto para gerar, coletar e exportar telemetria. | Métricas, Logs, Traces | APIs/SDKs/OTLP | Instrumentar aplicações e enviar traces |
| **OpenTelemetry Collector** | Hub que recebe, processa e encaminha telemetria. | Métricas, Logs, Traces | YAML/config | Aplicação → Collector → Tempo |
| **Grafana Alloy** | Agente/collector da Grafana para telemetria. | Logs, Métricas, Traces | Alloy config | Coletar logs dos Pods e enviar ao Loki |
| **Grafana** | Interface de visualização e correlação dos dados. | Visualização | Usa a linguagem de cada datasource | Dashboard com Prometheus + Loki + Tempo |
| **Alertmanager** | Gerencia roteamento e entrega de alertas do Prometheus. | Alertas | Config YAML | Enviar alerta para email, webhook, Teams etc. |
| **Datadog** | Plataforma SaaS completa de observabilidade e monitoring. | Métricas, Logs, Traces, Profiles, RUM etc. | Consultas próprias/UI | APM, dashboards, logs e infraestrutura em uma plataforma |

---

# 9. Uma correção conceitual importante sobre Grafana

Grafana **não possui uma única linguagem de consulta para tudo**.

Grafana funciona como uma camada de visualização sobre vários datasources.

Exemplo:

```text
Grafana
├── Prometheus → PromQL
├── Loki       → LogQL
├── Tempo      → TraceQL
├── Elasticsearch → Lucene / query DSL
├── PostgreSQL → SQL
└── Cloud providers → consultas específicas
```

Por isso não é correto dizer simplesmente:

```text
Grafana usa KQL/Lucene
```

Essas linguagens pertencem a outros mecanismos/datasources.

---

# 10. Onde o Datadog entra?

Neste curso utilizamos principalmente a stack open source:

```text
Prometheus
Grafana
Loki
Tempo
OpenTelemetry
Alloy
Alertmanager
```

Mas em muitas empresas você encontrará plataformas SaaS como:

```text
Datadog
New Relic
Dynatrace
Splunk Observability
Grafana Cloud
```

O **Datadog** oferece em uma única plataforma:

- infraestrutura;
- métricas;
- logs;
- APM;
- distributed tracing;
- profiling;
- synthetics;
- Real User Monitoring;
- dashboards;
- alertas;
- service catalog;
- incident management;
- segurança.

Conceitualmente, muitos conceitos que aprendemos continuam os mesmos.

Exemplo:

```text
Nosso lab                     Datadog

Prometheus metrics        →   Metrics
Loki logs                 →   Logs
Tempo traces              →   APM / Traces
Grafana dashboards        →   Datadog Dashboards
Alertmanager              →   Datadog Monitors
OpenTelemetry             →   Também pode enviar dados para Datadog
```

A maior diferença está na arquitetura e no modelo operacional.

Nossa stack é altamente modular:

```text
Prometheus + Loki + Tempo + Grafana
```

Datadog oferece grande parte disso de forma integrada como serviço gerenciado.

O objetivo do curso não é ensinar uma marca específica.

O objetivo é ensinar os **conceitos que continuam válidos independentemente da ferramenta**.

---

# 11. Golden Signals

Um dos modelos mais conhecidos de SRE utiliza quatro sinais principais:

```text
Latency
Traffic
Errors
Saturation
```

Esses sinais ajudam a responder rapidamente se o serviço está saudável.

---

## Latency

Quanto tempo as requisições levam.

Exemplo:

```text
p95 = 450ms
p99 = 1.2s
```

---

## Traffic

Quanto trabalho o sistema está recebendo/processando.

Exemplo:

```text
25 req/s
```

---

## Errors

Quantas requisições estão falhando.

Exemplo:

```text
Error Rate = 0.4%
```

---

## Saturation

Quanto o sistema está perto do limite.

Exemplo:

```text
CPU = 95%
HPA = 5/5
fila crescendo
workers ocupados
```

---

# 12. RED Method

O método RED é muito utilizado para observar serviços e APIs.

```text
R = Rate
E = Errors
D = Duration
```

Exemplo:

```text
Rate     → 30 req/s
Errors   → 1.2%
Duration → p95 = 800ms
```

É uma maneira excelente de começar um dashboard de aplicação.

---

# 13. USE Method

O método USE é bastante utilizado para infraestrutura e recursos.

```text
U = Utilization
S = Saturation
E = Errors
```

Exemplo para CPU:

```text
Utilization → CPU utilizada
Saturation  → throttling / fila
Errors      → falhas relacionadas
```

RED olha mais para o **serviço**.

USE olha mais para o **recurso**.

Um bom SRE utiliza os dois.

---

# 14. Availability

Availability representa o percentual de requisições consideradas bem-sucedidas.

Exemplo:

```text
10.000 requests
20 retornaram 5xx

Availability ≈ 99.8%
```

Uma forma simplificada:

```text
Availability = requests boas / requests totais
```

No laboratório consideramos principalmente HTTP `5xx` como falha de disponibilidade.

---

# 15. Error Rate

Error Rate mede o percentual de requisições que falham.

Exemplo:

```text
Error Rate = 0.2%
Availability = 99.8%
```

Quando o critério de falha é exatamente o mesmo, os dois são praticamente complementares.

---

# 16. Latency e percentis

Média pode esconder problemas.

Imagine:

```text
99 requests = 100ms
1 request   = 10s
```

A média pode parecer aceitável, mas um usuário teve uma experiência péssima.

Por isso usamos percentis.

---

## p50

```text
50% das requests ficaram abaixo desse tempo.
```

Representa aproximadamente a experiência típica.

---

## p95

```text
95% das requests ficaram abaixo desse tempo.
5% foram mais lentas.
```

É muito utilizado para acompanhar experiência de usuários.

---

## p99

```text
99% ficaram abaixo desse tempo.
1% foi ainda mais lento.
```

Mostra a chamada **tail latency**.

Em sistemas distribuídos, essa cauda pode ser muito importante.

---

# 17. SLI

**SLI (Service Level Indicator)** é aquilo que realmente medimos.

Exemplos:

```text
Availability = 99.92%
Latency <500ms = 99.4%
```

SLI é o número observado.

---

# 18. SLO

**SLO (Service Level Objective)** é a meta que queremos atingir.

Exemplo:

```text
Availability >= 99.9% em 30 dias
```

ou:

```text
99% das requests abaixo de 500ms
```

---

# 19. SLA

**SLA (Service Level Agreement)** é um compromisso formal.

Pode envolver:

```text
contrato
cliente
penalidade
crédito financeiro
obrigações
```

Nem todo serviço precisa ter SLA externo.

Mas praticamente todo serviço importante deveria possuir algum SLO interno.

---

# 20. Error Budget

Se o SLO é:

```text
99.9%
```

então podemos falhar:

```text
0.1%
```

Esse `0.1%` é o **Error Budget**.

Podemos pensar nele como:

> "Quanto de falha ainda podemos tolerar sem violar nosso objetivo?"

---

# 21. Burn Rate

Burn Rate mede **quão rápido o Error Budget está sendo consumido**.

Exemplo:

```text
Burn Rate = 1x
```

Estamos consumindo o orçamento exatamente no ritmo permitido.

```text
Burn Rate = 10x
```

Estamos consumindo dez vezes mais rápido.

No laboratório chegamos a valores como:

```text
Availability Burn Rate = 38x
Latency Burn Rate      = 57x
```

Isso representa uma degradação grave.

---

# 22. Fast Burn e Slow Burn

Nem todo problema consome Error Budget na mesma velocidade.

## Fast Burn

```text
Burn Rate muito alto
```

Pode exigir resposta imediata.

## Slow Burn

```text
Burn Rate moderado durante muitas horas
```

Talvez não seja emergência agora, mas pode destruir o SLO ao longo do tempo.

Por isso sistemas maduros utilizam **multi-window burn-rate alerts**.

---

# 23. MTTD, MTTA, MTTR e MTBF

Essas métricas ajudam a entender a eficiência operacional.

---

## MTTD — Mean Time To Detect

Tempo médio para detectar o incidente.

```text
Problema começou: 10:00
Alerta disparou:  10:03

MTTD = 3 minutos
```

---

## MTTA — Mean Time To Acknowledge

Tempo médio até alguém assumir o incidente.

```text
Alerta:          10:03
SRE assumiu:     10:06

MTTA = 3 minutos
```

---

## MTTR — Mean Time To Restore

Tempo médio para restaurar o serviço.

```text
Problema começou: 10:00
Serviço normal:   10:25

MTTR = 25 minutos
```

---

## MTBF — Mean Time Between Failures

Tempo médio entre falhas.

```text
Incidente
   ↓
20 dias
   ↓
novo incidente
```

Quanto maior o MTBF, melhor tende a ser a confiabilidade.

---

# 24. Alertas

Um dos erros mais comuns em observabilidade é criar alertas demais.

Exemplo ruim:

```text
CPU > 70%
```

CPU alta sozinha talvez não represente impacto.

Um alerta melhor pode estar ligado a:

```text
SLO
Error Budget
Burn Rate
Availability
Latency
```

A pergunta deve ser:

> "Se esse alerta disparar às 03:00 da manhã, alguém precisa realmente acordar?"

Se a resposta for não, provavelmente não deveria ser um Page.

---

# 25. Alertmanager

Prometheus detecta a condição.

Alertmanager decide:

```text
quem recebe
quando recebe
como recebe
se agrupa
se deduplica
quando repete
```

Fluxo:

```text
PrometheusRule
      ↓
Prometheus
      ↓
Alertmanager
      ↓
Email / Teams / Slack / Pager / Webhook
```

---

# 26. OpenTelemetry

OpenTelemetry é um dos componentes mais importantes do ecossistema atual de observabilidade.

Ele fornece:

```text
APIs
SDKs
instrumentações
protocolos
collectors
convenções semânticas
```

Seu objetivo é evitar que uma aplicação fique presa a um fornecedor específico.

A aplicação pode produzir telemetria via:

```text
OTLP
```

e depois enviar para diferentes backends.

Exemplo:

```text
Aplicação
    ↓
OpenTelemetry Collector
    ├── Tempo
    ├── Datadog
    ├── Jaeger
    ├── Grafana Cloud
    └── outros
```

---

# 27. OpenTelemetry Collector

O Collector é um componente intermediário.

Ele pode:

```text
receber
processar
filtrar
enriquecer
agrupar
exportar
```

telemetria.

No nosso laboratório:

```text
Python
  ↓ OTLP/HTTP
OpenTelemetry Collector
  ↓ OTLP/gRPC
Tempo
```

Essa arquitetura desacopla a aplicação do backend.

---

# 28. Grafana Alloy

Alloy é um collector da Grafana para telemetria.

No nosso laboratório ele coleta logs Kubernetes.

```text
Pods
 ↓ stdout/stderr
Alloy
 ↓
Loki
```

Ele também pode trabalhar com:

```text
metrics
logs
traces
profiles
```

dependendo da arquitetura.

---

# 29. Exemplars

Um **Exemplar** conecta uma métrica a uma requisição real.

Exemplo:

```text
Histogram Prometheus
      ↓
trace_id
      ↓
Tempo
```

No Grafana você pode observar um ponto no gráfico:

```text
● exemplar
```

clicar nele e abrir:

```text
GET /slow
└── simulated.wait
```

Essa é uma das pontes mais poderosas entre métricas e tracing.

---

# 30. Correlation

Observabilidade madura depende de correlação.

Exemplo:

```text
Prometheus
  ↓ exemplar
Tempo
  ↓ trace_id
Loki
```

Também podemos fazer:

```text
Loki
  ↓ trace_id
Tempo
```

O `trace_id` funciona como um identificador comum entre diferentes sinais.

---

# 31. Um dashboard SRE profissional

Um dashboard operacional não deveria ser apenas uma coleção de gráficos.

Ele deveria responder perguntas em ordem.

## Camada 1 — Impacto

```text
Availability
Error Rate
Latency
SLO
Error Budget
Burn Rate
```

## Camada 2 — RED

```text
Request Rate
Errors
Duration
```

## Camada 3 — Saturação

```text
CPU
Memory
CPU Throttling
Replicas
Restarts
HPA
```

## Camada 4 — Logs

```text
Errors
Exceptions
Slow Requests
```

## Camada 5 — Traces

```text
Slow Traces
Error Traces
Recent Traces
```

A ordem importa.

O SRE começa pelo impacto.

Só depois procura a causa.

---

# 32. Fluxo mental durante um incidente

Use este raciocínio:

```text
1. Usuário está sendo impactado?
        ↓
Availability / Error Rate / Latency

2. Nosso objetivo está em risco?
        ↓
SLO / Error Budget / Burn Rate

3. O serviço está saturado?
        ↓
CPU / Memory / HPA / Throttling

4. Qual request representa o problema?
        ↓
Exemplar

5. Onde ela ficou lenta?
        ↓
Tempo / Trace / Spans

6. O que aconteceu?
        ↓
Loki / Logs / trace_id

7. A mitigação funcionou?
        ↓
SLIs voltam ao normal
```

---

# 33. Glossário rápido

| Termo | Significado simples |
|---|---|
| Availability | Percentual de requisições bem-sucedidas |
| Error Rate | Percentual de requisições com erro |
| Latency | Tempo de resposta |
| p50 | 50% das requests ficaram abaixo desse tempo |
| p95 | 95% ficaram abaixo desse tempo |
| p99 | 99% ficaram abaixo desse tempo |
| Traffic / RPS | Requisições por segundo |
| Saturation | Proximidade do limite de capacidade |
| SLI | O indicador medido |
| SLO | A meta interna |
| SLA | O compromisso formal |
| Error Budget | Quanto podemos falhar |
| Burn Rate | Quão rápido o budget está sendo consumido |
| MTTD | Tempo para detectar |
| MTTA | Tempo para assumir |
| MTTR | Tempo para restaurar |
| MTBF | Tempo entre falhas |
| Trace | Caminho completo de uma request |
| Span | Uma etapa dentro do trace |
| trace_id | Identificador único do trace |
| Exemplar | Ponte entre uma métrica e um trace |
| Telemetria | Dados produzidos pelo sistema para observação |

---

# 34. Arquitetura construída no laboratório

Durante o curso construímos esta arquitetura:

```text
                       ┌──────────────┐
                       │   sre-demo   │
                       │    Python    │
                       └──────┬───────┘
                              │
              ┌───────────────┼────────────────┐
              │               │                │
              ▼               ▼                ▼
          /metrics          stdout            OTLP
              │               │                │
              ▼               ▼                ▼
         Prometheus          Alloy       OTel Collector
              │               │                │
              │               ▼                ▼
              │              Loki             Tempo
              │               │                │
              └───────────────┼────────────────┘
                              ▼
                           Grafana
                              │
                              ▼
                        Alertmanager
```

---

# 35. O objetivo final

Um bom sistema de observabilidade permite sair desta pergunta:

> "Por que o sistema está estranho?"

para uma resposta técnica objetiva:

> "A disponibilidade caiu para 96%, o p95 chegou a 12 segundos, o HPA atingiu 5/5 réplicas, a CPU ficou saturada, o Burn Rate passou de 30x e os traces mostram que as requests `/cpu` estão gastando a maior parte do tempo em `simulated.cpu_work`."

Isso é o tipo de resposta que um SRE deve ser capaz de produzir.

---

# 36. Roadmap sugerido para transformar este material em curso

## Módulo 1 — Fundamentos

- Introdução a SRE
- Monitoring x Observability
- Telemetria
- Metrics, Logs e Traces
- Golden Signals
- RED e USE

## Módulo 2 — Prometheus

- Instrumentação
- Counters
- Gauges
- Histograms
- PromQL
- p95/p99
- ServiceMonitor

## Módulo 3 — Grafana

- Datasources
- Explore
- Dashboards
- Variáveis
- Organização de dashboards SRE

## Módulo 4 — SLI/SLO

- SLI
- SLO
- SLA
- Error Budget
- Burn Rate
- Multi-window alerts

## Módulo 5 — Alerting

- PrometheusRule
- Alertmanager
- Routing
- Grouping
- Deduplication
- Email/Webhook/Teams

## Módulo 6 — Loki

- Logs Kubernetes
- Alloy
- Structured Logging
- LogQL
- trace_id

## Módulo 7 — OpenTelemetry

- Instrumentação
- OTLP
- Collector
- Semantic Conventions

## Módulo 8 — Tempo

- Distributed tracing
- Trace
- Span
- TraceQL
- Slow traces
- Error traces

## Módulo 9 — Correlation

- Metrics → Trace
- Logs → Trace
- Trace → Logs
- Exemplars

## Módulo 10 — Incident Response

- MTTD
- MTTA
- MTTR
- Runbooks
- Severity
- Incident lifecycle
- Postmortem

---

# 37. Regra de ouro do curso

Se você lembrar apenas de uma coisa deste capítulo, lembre desta:

```text
Metrics mostram QUE existe um problema.

Traces mostram ONDE ele está.

Logs ajudam a explicar POR QUÊ.

SLO e Burn Rate dizem QUÃO URGENTE ele é.
```

Essa é a base para começar a pensar como um SRE.
