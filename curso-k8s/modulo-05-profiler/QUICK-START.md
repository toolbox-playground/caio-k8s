# 🚀 Módulo 05 — Escolha sua Abordagem

Este módulo oferece **três formas** de fazer profiling contínuo com Grafana Pyroscope.  
Cada uma tem seu próprio guia completo. Escolha abaixo:

---

## Abordagem 1 — Pyroscope SDK

📁 **Pasta:** [pyroscope-sdk/](pyroscope-sdk/)  
📄 **Guia:** [pyroscope-sdk/QUICK-START.md](pyroscope-sdk/QUICK-START.md)

**O que faz:** adiciona o SDK `pyroscope-io` dentro do código Python da `ranking-api`.  
A aplicação amostra o próprio call stack e envia os profiles para o Pyroscope.

**Melhor quando:**
- Você controla o código-fonte
- Precisa de `tag_wrapper` (perfil separado por endpoint, feature, usuário)
- Quer correlação precisa Trace → Profile no Grafana

```sh
cd curso-k8s/modulo-05-profiler/pyroscope-sdk
# siga o QUICK-START.md dentro desta pasta
```

---

## Abordagem 2 — Grafana Alloy (eBPF)

📁 **Pasta:** [grafana-alloy/](grafana-alloy/)  
📄 **Guia:** [grafana-alloy/QUICK-START.md](grafana-alloy/QUICK-START.md)

**O que faz:** instala o Grafana Alloy como DaemonSet. Ele usa eBPF para perfilar  
**todos os processos do cluster sem modificar nenhuma aplicação**.

**Melhor quando:**
- App de terceiro, legado ou sem acesso ao código
- Quer profiling de toda a infra (Redis, Postgres, qualquer pod) de uma vez
- Deseja zero mudanças nas aplicações

```sh
cd curso-k8s/modulo-05-profiler/grafana-alloy
# siga o QUICK-START.md dentro desta pasta
```

---

## Comparação rápida

| | SDK | Alloy (eBPF) | **Híbrido** |
|---|---|---|---|
| Muda o código? | Sim | **Não** | Sim (só sua app) |
| Perfil por endpoint? | **Sim** (tag_wrapper) | Não | **Sim** |
| Qualquer linguagem/processo? | Não | **Sim** | **Sim** |
| Trace → Profile precisa? | **Sim** | Parcial | **Sim** |
| `privileged: true` no K8s? | Não | Sim | Sim |
| Syscalls/kernel visíveis? | Não | **Sim** | **Sim** |
| Recomendado para produção? | Ambientes simples | Infra sem acesso ao código | **Sim** |

---

## Abordagem 3 — Híbrido (SDK + Alloy)

📁 **Pasta:** [hybrid/](hybrid/)  
📄 **Guia:** [hybrid/QUICK-START.md](hybrid/QUICK-START.md)

**O que faz:** combina o SDK na `ranking-api` (granularidade Python + tag_wrapper)  
com o Alloy eBPF perfilando toda a infra do cluster (syscalls, runtime C, outros pods).

**Por que usar:**
- O SDK mostra "qual função Python gastou CPU"
- O eBPF mostra "qual syscall essa função disparou no kernel" — ex: `futex_wait`
- Você pode ver p99=380ms no trace, 40ms no flame graph Python, e 340ms em `futex_wait` no eBPF
- No Grafana: filtre por `profiler=sdk` (frames Python) ou `profiler=ebpf` (kernel)

```sh
cd curso-k8s/modulo-05-profiler/hybrid
# siga o QUICK-START.md dentro desta pasta
```

---

> 📚 **Teoria** (o que é profiler, flame graph, eBPF, casos de uso):  
> consulte o [README.md do módulo](README.md).

---

## Pré-condição: Módulos 03 e 04 concluídos

O Módulo 05 se apoia no stack completo dos módulos anteriores:
- Grafana (módulo 03) — para visualizar os flame graphs
- Tempo (módulo 04) — para correlação Trace → Profile
- OTel Collector (módulo 04) — para os traces da ranking-api

Se já estiver tudo `Running`, pule para a **Etapa 1**.  
Se precisar recriar do zero, siga a seção "Subindo tudo do zero" abaixo.

---

## Subindo tudo do zero (cluster + stack completo)

> 🎯 Faça isso apenas se deletou o cluster ou está começando um ambiente novo.

### Passo 1 — Criar cluster Kind com as portas de todos os módulos

**PowerShell e bash:**

```sh
# Deletar cluster anterior se existir
kind delete cluster --name k8s-essentials

# Recriar com o config do Módulo 05 (inclui todas as portas anteriores + Pyroscope :4040)
kind create cluster --config manifests/cluster-config.yaml
```

### Passo 2 — Instalar Metrics Server

**PowerShell e bash:**

```sh
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

**PowerShell:**

```powershell
kubectl patch deployment metrics-server -n kube-system `
  --type=json `
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```

**bash / zsh:**

```bash
kubectl patch deployment metrics-server -n kube-system \
  --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```

### Passo 3 — Instalar stack de monitoramento (Módulo 03)

**PowerShell e bash:**

```sh
kubectl create namespace games --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f ../modulo-02-deploy-app/manifests/01-deployment-mario.yaml
kubectl apply -f ../modulo-02-deploy-app/manifests/02-service-mario.yaml
kubectl apply -f ../modulo-02-deploy-app/manifests/03-hpa.yaml
```

```sh
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kind-prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  -f ../modulo-03-monitoring/helm-values/values-prometheus-stack.yaml
```

```sh
helm repo add grafana https://grafana.github.io/helm-charts

helm install loki grafana/loki \
  --namespace monitoring \
  -f ../modulo-03-monitoring/helm-values/values-loki.yaml

helm install fluent-bit grafana/fluent-bit \
  --namespace monitoring \
  -f ../modulo-03-monitoring/helm-values/values-fluent-bit.yaml
```

### Passo 4 — Instalar Tempo e OTel Collector (Módulo 04)

**PowerShell e bash:**

```sh
helm install tempo grafana/tempo \
  --namespace monitoring \
  -f ../modulo-04-opentelemetry/helm-values/values-tempo.yaml

kubectl apply -f ../modulo-04-opentelemetry/manifests/03-otel-collector.yaml
kubectl apply -f ../modulo-04-opentelemetry/manifests/04-podmonitor-otel-collector.yaml
```

---

## Etapa 1 — Instalar o Grafana Pyroscope

### Adicionar o Helm repo da Grafana (se ainda não adicionou)

**PowerShell e bash:**

```sh
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

### Instalar o Pyroscope

**PowerShell e bash:**

```sh
helm install pyroscope grafana/pyroscope `
  --namespace monitoring `
  --create-namespace `
  -f helm-values/values-pyroscope.yaml
```

**Bash:**

```sh
helm install pyroscope grafana/pyroscope \
  --namespace monitoring \
  --create-namespace \
  -f helm-values/values-pyroscope.yaml
```

### Verificar se o Pyroscope subiu

**PowerShell e bash:**

```sh
kubectl get pods -n monitoring -l app.kubernetes.io/name=pyroscope
# Aguarde: STATUS = Running
```

```sh
kubectl get svc -n monitoring | grep pyroscope
# Deve mostrar: pyroscope   NodePort   <IP>   <none>   4040:34040/TCP
```

> 🌐 Pyroscope UI disponível em: **http://localhost:4040**

---

## Etapa 2 — Adicionar Pyroscope como Datasource no Grafana

O Grafana já está rodando do Módulo 03. Agora adicionamos o Pyroscope como datasource.

### Via Grafana UI

1. Acesse **http://localhost:3000** (admin / prom-operator)
2. Menu lateral → **Connections** → **Data sources**
3. Botão **"Add new data source"**
4. Busque por **"Grafana Pyroscope"** e clique nele
5. Configure:
   - **URL:** `http://pyroscope.monitoring.svc.cluster.local:4040`
6. Clique em **"Save & test"** — deve aparecer "Data source connected"

---

## Etapa 3 — Build da ranking-api v2 (com Pyroscope SDK)

Esta versão adiciona o SDK `pyroscope-io` à aplicação do Módulo 04.

### Build da imagem

**PowerShell e bash:**

```sh
# Build da nova versão com o SDK pyroscope-io
docker build -t ranking-api:v2-profiler ./app
```

> ⏳ O primeiro build pode demorar alguns minutos — o pacote `pyroscope-io` compila extensões C.

### Carregar a imagem no cluster Kind

**PowerShell e bash:**

```sh
kind load docker-image ranking-api:v2-profiler --name k8s-essentials
```

### Verificar que a imagem está disponível

**PowerShell e bash:**

```sh
docker exec k8s-essentials-control-plane crictl images | grep ranking-api
# Deve listar:  ranking-api   v2-profiler   <hash>   <tamanho>
```

---

## Etapa 4 — Deploy da ranking-api v2

**PowerShell e bash:**

```sh
kubectl apply -f manifests/01-deployment-ranking-api-v2.yaml
```

### Verificar o deploy

**PowerShell e bash:**

```sh
kubectl get pods -n games -l app=ranking-api
# Aguarde todos os pods: STATUS = Running, READY = 1/1
```

```sh
# O SDK pyroscope-io roda em background silenciosamente — não loga ao iniciar.
# Se houver erro de conexão com o Pyroscope, você verá algo como:
#   "Failed to push profile" ou "connection refused"
# Se o log estiver limpo (sem erros), o SDK está funcionando.
kubectl logs -n games -l app=ranking-api --tail=20
```

```powershell
# Confirmação alternativa: verificar se o serviço já aparece no Pyroscope
# Aguarde ~30s e acesse http://localhost:4040 — "ranking-api" deve aparecer na lista
# Ou consulte via API (PowerShell):
kubectl run -it --rm pyroscope-check --image=curlimages/curl --restart=Never -- `
  curl -s "http://pyroscope.monitoring.svc.cluster.local:4040/api/apps" | Select-String "ranking"
```

```bash
# bash / zsh:
kubectl run -it --rm pyroscope-check --image=curlimages/curl --restart=Never -- \
  curl -s "http://pyroscope.monitoring.svc.cluster.local:4040/api/apps" | grep ranking
```

```sh
# Verificar que os traces ainda chegam ao Tempo
kubectl logs -n otel deployment/otel-collector --tail=30
```

---

## Etapa 5 — Gerar carga para criar profiles

Profiles ficam interessantes com dados reais. Use o Fortio para simular tráfego:

**PowerShell e bash:**

```sh
# Stress test na ranking-api (endpoints /rankings e /score)
kubectl apply -f pyroscope-sdk/manifests/02-stress-test-fortio.yaml
```

Ou dispare manualmente via port-forward:

**PowerShell e bash:**

```sh
# Em um terminal separado — manter aberto
kubectl port-forward -n games svc/ranking-api 8000:80
```

```sh
# Em outro terminal — gerar carga
# Instalar fortio localmente se não tiver
# fortio load -qps 10 -t 60s http://localhost:8000/rankings
# fortio load -qps 10 -t 60s http://localhost:8000/score

# Alternativa: curl em loop
for i in 1..50; do curl -s http://localhost:8000/rankings > $null; Start-Sleep -Milliseconds 200; done
```

---

## Etapa 6 — Visualizar os Flame Graphs no Grafana

### Explorar profiles no Grafana Explore

1. Acesse **http://localhost:3000**
2. Menu lateral → **Explore**
3. Selecione datasource: **Grafana Pyroscope**
4. Em **Profile type**, selecione `process_cpu:cpu:nanoseconds:cpu:nanoseconds`
5. Em **Labels**, digite: `{service_name="ranking-api"}`
6. Ajuste o intervalo de tempo para os últimos 15 minutos
7. Clique em **"Run query"**

### O que você verá

```
Flame graph da ranking-api nos últimos 15 minutos:

┌─────────────────────────────────────────────────────────────────┐
│  ranking_api.get_rankings                        [████████ 45%] │
│  ranking_api.submit_score                        [██████   35%] │
│  uvicorn._bootstrap                              [███      15%] │
│  outros                                          [█         5%] │
└─────────────────────────────────────────────────────────────────┘
```

Clique em qualquer bloco para expandir o call stack.

---

## Etapa 7 — Configurar Trace to Profile (correlação com Tempo)

Esta etapa conecta os traces do Tempo aos profiles do Pyroscope, permitindo navegar de um span diretamente para o flame graph correspondente.

1. Acesse **http://localhost:3000**
2. Menu → **Connections → Data sources → Tempo**
3. Role até a seção **"Trace to profiles"**
4. Ative a opção
5. Configure:
   - **Data source:** `Grafana Pyroscope`
   - **Profile type:** `process_cpu:cpu:nanoseconds:cpu:nanoseconds`
   - **Custom query:** ative e use:
     ```
     {service_name="${__tags.service_name}"}
     ```
6. Clique em **"Save & test"**

### Testando a correlação

1. Gere algum tráfego na ranking-api (passo anterior)
2. Grafana → **Explore** → Datasource: **Tempo**
3. Busque traces: `{ resource.service.name = "ranking-api" && duration > 50ms }`
4. Clique em um trace → expanda o waterfall → clique em um span
5. No painel de detalhes do span, procure o link **"View in Pyroscope"** ou botão de profile

---

## Resumo dos endpoints de acesso

| Serviço        | URL                    | Credenciais         |
|----------------|------------------------|---------------------|
| Grafana        | http://localhost:3000  | admin / prom-operator |
| Pyroscope UI   | http://localhost:4040  | sem autenticação    |
| Prometheus     | http://localhost:9090  | sem autenticação    |
| ranking-api    | http://localhost:8081/rankings | —           |

---

## Troubleshooting

### Pyroscope pod em CrashLoopBackOff

```sh
kubectl describe pod -n monitoring -l app.kubernetes.io/name=pyroscope
kubectl logs -n monitoring -l app.kubernetes.io/name=pyroscope --previous
```

Verifique se o cluster foi criado com o `cluster-config.yaml` do Módulo 05 (precisa ter a porta 34040).

### ranking-api não aparece no Pyroscope

```sh
# Verificar variável de ambiente do deployment
kubectl get deployment ranking-api -n games -o jsonpath='{.spec.template.spec.containers[0].env}'
```

A variável `PYROSCOPE_SERVER_ADDRESS` deve apontar para `http://pyroscope.monitoring.svc.cluster.local:4040`.

```sh
# Verificar DNS interno
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup pyroscope.monitoring.svc.cluster.local
```

### "Data source connected" mas sem dados no Grafana

Aguarde pelo menos **30 segundos** após o deploy — o SDK faz push a cada 15s. Se ainda não aparecer, verifique os logs do pod da ranking-api por erros de conexão com o Pyroscope.
