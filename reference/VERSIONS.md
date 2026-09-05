# Versões utilizadas no laboratório

Estas versões refletem o ambiente em que o curso foi construído.

```text
Kubernetes               v1.35
Calico                   v3.32.1
MetalLB                  v0.16.1
local-path-provisioner   v0.0.37
Gateway API CRDs         v1.4.0
kube-prometheus-stack    88.6.1
Grafana                  13.2.0 (app version observada no stack)
Tempo                    3.0.2
OTel Collector Contrib   0.159.0
OpenTelemetry Python     1.44.0
Flask instrumentation    0.65b0
AWS Region               sa-east-1
```

O Loki/Alloy são instalados pelo chart Grafana usando os values fornecidos no curso.

Se você reproduzir o curso muito tempo depois, charts e schemas podem evoluir. Prefira as versões aqui documentadas quando quiser reproduzir exatamente o comportamento do laboratório.
