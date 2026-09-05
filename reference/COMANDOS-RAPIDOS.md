# Comandos rápidos

## Kubernetes

```bash
kubectl get pods -A
kubectl get nodes -o wide
kubectl top nodes
kubectl top pods -n sre-lab
kubectl get hpa -n sre-lab
```

## App

```bash
kubectl exec -n sre-lab loadgen -- curl -s http://sre-demo.sre-lab.svc.cluster.local/
```

## Prometheus Rules

```bash
kubectl get prometheusrule -n monitoring
```

## Logs

```logql
{namespace="sre-lab", app="sre-demo"} | json
```

## Traces

```traceql
{ resource.service.name = "sre-demo" }
```
