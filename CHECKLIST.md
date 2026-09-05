# Checklist de conclusão — SRE Observabilidade

## Cluster
- [ ] kubeadm cluster Ready
- [ ] Calico
- [ ] MetalLB
- [ ] ingress-nginx
- [ ] local-path
- [ ] metrics-server

## Monitoring
- [ ] Prometheus
- [ ] Grafana persistente
- [ ] Alertmanager
- [ ] UIDs fixos

## App v1
- [ ] Docker Hub repository `alanmosilva/sre-demo`
- [ ] tag `v1`
- [ ] ServiceMonitor
- [ ] Prometheus metrics
- [ ] dashboard básico

## SRE
- [ ] SLI
- [ ] SLO
- [ ] Error Budget
- [ ] Burn Rate

## App v2
- [ ] tag `v2`
- [ ] structured logs
- [ ] OpenTelemetry
- [ ] trace_id / span_id
- [ ] Exemplars

## Backends
- [ ] Loki
- [ ] Alloy
- [ ] Tempo
- [ ] OTel Collector

## Correlation
- [ ] Loki → Tempo
- [ ] Tempo → Loki
- [ ] Prometheus Exemplar → Tempo

## Operations
- [ ] HPA
- [ ] Fast Burn alert
- [ ] AWS SES email
- [ ] Runbook
- [ ] SEV classification
- [ ] MTTD
- [ ] MTTA
- [ ] MTTR
- [ ] Postmortem
