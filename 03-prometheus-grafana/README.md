# Módulo 03 — Instalando Prometheus e Grafana corretamente

## Objetivo

Instalar `kube-prometheus-stack` com:

- Prometheus;
- Grafana;
- Alertmanager;
- kube-state-metrics;
- node-exporter;
- Grafana persistente;
- UIDs fixos para datasources;
- suporte a Exemplars no Prometheus.

---

## 1. Criar namespace

```bash
kubectl create namespace monitoring \
  --dry-run=client -o yaml | kubectl apply -f -
```

---

## 2. Criar senha do Grafana em Secret

Não grave a senha no Git.

```bash
read -s -p "Grafana admin password: " GRAFANA_ADMIN_PASSWORD
echo
```

Crie o Secret:

```bash
kubectl create secret generic grafana-admin \
  -n monitoring \
  --from-literal=admin-user=admin \
  --from-literal=admin-password="$GRAFANA_ADMIN_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -
```

Limpe a variável:

```bash
unset GRAFANA_ADMIN_PASSWORD
```

---

## 3. Adicionar repositório Helm

```bash
helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts

helm repo update
```

---

## 4. Entender `monitoring-values.yaml`

O arquivo deste módulo configura:

```text
Grafana PVC: 10Gi / local-path
Prometheus UID: prometheus
Loki UID: loki
Tempo UID: tempo
Alertmanager UID: alertmanager
Prometheus exemplar-storage: enabled
```

Mesmo que Loki e Tempo ainda não existam, deixamos os datasources provisionados com UIDs fixos para evitar que o dashboard quebre no futuro.

---

## 5. Instalar kube-prometheus-stack

```bash
helm upgrade --install monitoring \
  prometheus-community/kube-prometheus-stack \
  --version 88.6.1 \
  -n monitoring \
  -f monitoring-values.yaml
```

---

## 6. Acompanhar Pods

```bash
kubectl get pods -n monitoring -w
```

Saia com `Ctrl+C` quando estiverem saudáveis.

---

## 7. Validar PVC do Grafana

```bash
kubectl get pvc -n monitoring
```

Você deve encontrar um PVC do Grafana em `Bound`.

Esse é o ponto que protege dashboards/configurações contra recriação do Pod.

---

## 8. Criar Ingress

```bash
kubectl apply -f monitoring-ingress.yaml
```

Descubra o IP do ingress-nginx:

```bash
kubectl get svc ingress-nginx-controller -n ingress-nginx
```

Exemplo:

```text
EXTERNAL-IP 192.168.30.230
```

No computador que acessará o lab adicione ao arquivo hosts:

```text
192.168.30.230 grafana.lab.local prometheus.lab.local
```

Windows:

```text
C:\Windows\System32\drivers\etc\hosts
```

Linux/macOS:

```text
/etc/hosts
```

---

## 9. Validar Grafana

Abra:

```text
http://grafana.lab.local
```

Usuário:

```text
admin
```

---

## 10. Validar Prometheus

Abra:

```text
http://prometheus.lab.local
```

Query de teste:

```promql
up
```

---

## 11. Conferir datasources provisionados

No Grafana:

```text
Connections → Data sources
```

Você verá:

```text
Prometheus   uid=prometheus
Loki         uid=loki
Tempo        uid=tempo
Alertmanager uid=alertmanager
```

Loki e Tempo ainda podem falhar no `Save & test`, porque serão instalados depois. Isso é esperado.

---

## Checkpoint

```text
[ ] Grafana abre
[ ] Prometheus abre
[ ] PVC do Grafana está Bound
[ ] Prometheus datasource uid=prometheus
[ ] Loki datasource uid=loki
[ ] Tempo datasource uid=tempo
[ ] Alertmanager datasource uid=alertmanager
```
