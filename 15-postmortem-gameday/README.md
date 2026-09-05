# Módulo 15 — MTTD, MTTA, MTTR, Postmortem e GameDay

## MTTD

Mean Time To Detect.

```text
problema começou → problema detectado
```

## MTTA

Mean Time To Acknowledge.

```text
alerta → alguém assume o incidente
```

## MTTR

Mean Time To Restore.

```text
problema começou → serviço restaurado
```

---

## Exemplo real do nosso laboratório

```text
Incident Start     18:49:53 UTC
Detected           18:50:27 UTC
Acknowledged       18:51:00 UTC
Mitigation Start   19:21:55 UTC
Service Restored   19:27:56 UTC
```

Resultados:

```text
MTTD = 34s
MTTA = 33s
MTTR = 38m03s
Mitigation → Restore = 6m01s
```

O maior gap foi:

```text
Acknowledged → Mitigation Start = 30m55s
```

No laboratório isso ocorreu porque paramos para aprender e analisar. Em produção seria um ponto prioritário de melhoria.

---

## O que é Postmortem?

É o processo de análise pós-incidente.

Normalmente existe:

```text
incidente resolvido
 ↓
documento de postmortem
 ↓
reunião de revisão
 ↓
ações corretivas
 ↓
acompanhamento
```

O objetivo não é procurar culpados.

É descobrir como tornar o sistema e o processo melhores.

---

## Arquivos

```text
postmortem-template.md
postmortem-exemplo.md
```

---

## GameDay final

Repita o incidente sem olhar previamente qual foi a causa.

Uma segunda pessoa pode escolher um dos cenários:

```text
1. Gerar /error
2. Saturar /cpu
3. Gerar /slow
4. Escalar Deployment para 0 por alguns minutos
5. Alterar selector do Service propositalmente
```

O aluno deve:

```text
detectar
classificar
seguir runbook
mitigar
medir tempos
escrever postmortem
```
