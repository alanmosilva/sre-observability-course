# Módulo 16 — Troubleshooting real do laboratório

Este capítulo registra problemas que realmente aconteceram durante a construção do lab.

---

# 1. PrometheusRule existe, mas não aparece no Prometheus

Sintoma:

```bash
kubectl get prometheusrule -A
```

mostra o objeto, porém `/api/v1/rules` não mostra a regra.

Verifique selector:

```bash
kubectl get prometheus monitoring-kube-prometheus-prometheus \
  -n monitoring \
  -o jsonpath='{.spec.ruleSelector}{"\n"}{.spec.ruleNamespaceSelector}{"\n"}'
```

No nosso ambiente:

```text
matchLabels: release=monitoring
```

Correção:

```yaml
metadata:
  labels:
    release: monitoring
```

Também centralizamos as PrometheusRules customizadas em `monitoring`.

---

# 2. AlertmanagerConfig: `no matches for kind ... v1beta1`

Descubra a versão realmente servida:

```bash
kubectl get crd alertmanagerconfigs.monitoring.coreos.com \
  -o jsonpath='{range .spec.versions[*]}{.name}{" served="}{.served}{" storage="}{.storage}{"\n"}{end}'
```

No nosso lab:

```text
v1alpha1 served=true
```

Logo:

```yaml
apiVersion: monitoring.coreos.com/v1alpha1
```

---

# 3. Grafana perdeu dashboards/configurações

Causa:

```text
Grafana sem PVC
```

Correção do curso:

```text
Grafana StatefulSet + local-path PVC 10Gi
```

Evite fazer mudanças destrutivas em Helm depois que o ambiente já estiver configurado.

---

# 4. `Datasource was not found`

Causa típica:

```text
Dashboard aponta para UID antigo
```

Padronização do curso:

```text
prometheus
loki
tempo
alertmanager
```

Fixos desde o primeiro install.

---

# 5. Explore funciona, dashboard não

Se Loki/Tempo funcionam no Explore, o backend está saudável.

Edite o painel e confira datasource/UID.

Logs devem usar:

```text
Loki / uid=loki
```

Traces:

```text
Tempo / uid=tempo
```

---

# 6. `curl` retorna HTTP 000 / exit code 7

Isso indica falha de conexão.

Diagnóstico:

```bash
kubectl get svc sre-demo -n sre-lab -o wide
kubectl get endpointslice -n sre-lab \
  -l kubernetes.io/service-name=sre-demo -o wide
kubectl get pods -n sre-lab -l app=sre-demo -o wide
kubectl describe svc sre-demo -n sre-lab
```

Pense no caminho:

```text
loadgen → Service → EndpointSlice → Pod
```

---

# 7. Tempo CrashLoop após config

Erro encontrado:

```text
field compactor not found in type app.Config
```

A configuração antiga não era compatível com Tempo 3.0.2.

O manifesto corrigido está no Módulo 09.

---

# 8. Poucos Exemplars

Não espere um exemplar por request.

Exemplars são amostras que ligam uma observação a um trace.

Várias requests no mesmo bucket podem deixar somente o exemplar mais recente antes do scrape.

---

# 9. SES funciona na conta, mas Alertmanager não envia

Teste primeiro a rede do cluster:

```bash
kubectl run smtp-test \
  -n sre-lab \
  --rm -it \
  --restart=Never \
  --image=nicolaka/netshoot -- \
  nc -vz email-smtp.sa-east-1.amazonaws.com 587
```

Se TCP falha, credenciais não são o primeiro problema.

---

# 10. HPA continua em 5 replicas após o incidente

Pode ser esperado.

O scale-down é conservador para evitar flapping.

Neste curso configuramos:

```yaml
scaleDown:
  stabilizationWindowSeconds: 300
```

---

# Método de troubleshooting

Não pule direto para a hipótese favorita.

```text
1. confirme sintoma
2. isole camada
3. valide com comando direto
4. só então altere configuração
```
