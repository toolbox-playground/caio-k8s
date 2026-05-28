# 🚀 Módulo 03 — Guia de Início Rápido

> ⚠️ **Todos os comandos deste guia devem ser executados de dentro da pasta `modulo-03-monitoring/`:**
>
> **PowerShell:**
> ```powershell
> cd curso-k8s/modulo-03-monitoring
> ```
> **bash / zsh:**
> ```bash
> cd curso-k8s/modulo-03-monitoring
> ```

## Pré-condição: Módulo 02 concluído

O Super Mario e o HPA precisam estar rodando. Verifique:

**PowerShell e bash:**

```sh
kubectl get pods -n games
kubectl get hpa -n games
```

---

## Opção A: Cluster novo com todas as portas mapeadas (recomendado)

Use se for recriar o cluster do zero ou se o cluster ainda não existe.

**PowerShell e bash:**

```sh
# 1. Deletar cluster anterior (se existir)
kind delete cluster --name k8s-essentials

# 2. Recriar com port mappings estendidos
kind create cluster --config manifests/cluster-config.yaml

# 3. Reinstalar Metrics Server (necessário após recriar)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# O patch abaixo adiciona --kubelet-insecure-tls ao Metrics Server.
# Por quê? O Metrics Server coleta CPU/memória conectando ao kubelet de cada
# node via HTTPS (porta 10250). No Kind, o kubelet usa um certificado TLS
# autoassinado (não emitido por CA reconhecida), então a validação falha com:
#   x509: cannot validate certificate for <node-ip> because it does not
#   contain any IP SANs
# O flag instrui o Metrics Server a pular essa verificação.
# Resultado sem o patch: kubectl top pods falha e o HPA não consegue escalar.
# ⚠️ Não use em produção — em EKS/GKE/AKS os certificados são válidos.
kubectl patch deployment metrics-server -n kube-system --type=json -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

# 4. Reinstalar o Super Mario (Módulo 02)
kubectl create namespace games
kubectl apply -f ../modulo-02-deploy-app/manifests/01-deployment-mario.yaml
kubectl apply -f ../modulo-02-deploy-app/manifests/02-service-mario.yaml
kubectl apply -f ../modulo-02-deploy-app/manifests/03-hpa.yaml
```

---

## Opção B: Cluster existente via port-forward (sem downtime)

Use se não quiser recriar o cluster e perder o estado atual.

**PowerShell e bash:**

```sh
# Após instalar o Prometheus (passo abaixo), use port-forward para acessar:
kubectl port-forward svc/kind-prometheus-kube-prome-prometheus -n monitoring 9090:9090
kubectl port-forward svc/kind-prometheus-grafana -n monitoring 3000:80
kubectl port-forward svc/kind-prometheus-kube-prome-alertmanager -n monitoring 9093:9093
```

> ⚠️ Cada `port-forward` ocupa um terminal. Abra 3 terminais separados ou use tmux.

---

## Instalação do kube-prometheus-stack via Helm

**PowerShell e bash:**

```sh
# 1. Adicionar repositórios Helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add stable https://charts.helm.sh/stable
helm repo update

# 2. Criar namespace de monitoramento
kubectl create namespace monitoring
```

# 3. Instalar o stack completo

**PowerShell:**

```powershell
helm install kind-prometheus prometheus-community/kube-prometheus-stack `
  --namespace monitoring `
  -f helm-values/values-prometheus-stack.yaml
```

**bash / zsh (Linux, Mac, WSL):**

```bash
helm install kind-prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f helm-values/values-prometheus-stack.yaml
```

> O arquivo `helm-values/values-prometheus-stack.yaml` contém todos os `--set` abaixo já convertidos para YAML versionado. Ele pode ser editado e commitado — o estado do ambiente é reproduzível.

> 💡 **O que cada configuração faz:**
>
> | Chave | O que faz | Sem ela |
> |---|---|---|
> | `prometheus.service.nodePort=30090` + `type=NodePort` | Expõe o Prometheus na porta `30090` de cada node; mapeada para `localhost:9090` pelo Kind | O serviço fica `ClusterIP` — inacessível fora do cluster |
> | `grafana.service.nodePort=31000` + `type=NodePort` | Expõe o Grafana na porta `31000`; mapeada para `localhost:3000` | Idem |
> | `alertmanager.service.nodePort=32000` + `type=NodePort` | Expõe o Alertmanager na porta `32000`; mapeada para `localhost:9093` | Idem |
> | `prometheus-node-exporter.service.nodePort=32001` + `type=NodePort` | Expõe o Node Exporter na porta `32001`; mapeada para `localhost:9100` | Idem |
> | `serviceMonitorSelectorNilUsesHelmValues=false` | Coleta ServiceMonitors de qualquer namespace | Só coleta do namespace do chart |
> | `externalUrl` | URL do link "Source" nas notificações (Discord, e-mail) | Usa DNS interno do cluster |
>
> O NodePort sozinho não é suficiente — o Kind também precisa do mapeamento `hostPort` no `cluster-config.yaml` para repassar a porta do container do Kind para o `localhost` do seu computador.

## Aguardar o stack subir

**PowerShell e bash:**

```sh
# Acompanhar pods subindo (aguarde todos ficarem Running/Ready)
kubectl get pods -n monitoring -w
```

Ou aguardar todos ficarem prontos de uma vez:

**PowerShell:**

```powershell
kubectl wait --for=condition=ready pod `
  --selector=app.kubernetes.io/instance=kind-prometheus `
  --namespace monitoring `
  --timeout=300s
```

**bash / zsh:**

```bash
kubectl wait --for=condition=ready pod \
  --selector=app.kubernetes.io/instance=kind-prometheus \
  --namespace monitoring \
  --timeout=300s
```

Resultado esperado (todos `1/1 Running` ou `2/2 Running`):

```
NAME                                                      READY   STATUS    RESTARTS
alertmanager-kind-prometheus-kube-prome-alertmanager-0   2/2     Running   0
kind-prometheus-grafana-xxxx                             3/3     Running   0
kind-prometheus-kube-prome-operator-xxxx                 1/1     Running   0
kind-prometheus-kube-state-metrics-xxxx                  1/1     Running   0
kind-prometheus-prometheus-node-exporter-xxxx            1/1     Running   0
prometheus-kind-prometheus-kube-prome-prometheus-0       2/2     Running   0
```

---

## Instalação do Loki 3.x (chart oficial) via Helm

> 🎯 **Por que mudamos o chart?** O `grafana/loki-stack` é um chart legado que congela o Loki na versão 2.x e acopla o agente de coleta ao banco de logs num único pacote. O padrão moderno de mercado é separar responsabilidades: **Loki cuida do armazenamento**, **Fluent Bit cuida da coleta**. Isso permite evoluir cada peça independentemente.

**PowerShell e bash:**

```sh
# Adicionar repositório Grafana (se ainda não adicionado)
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

**PowerShell:**

```powershell
helm install loki grafana/loki `
  --namespace monitoring `
  -f helm-values/values-loki.yaml
```

**bash / zsh:**

```bash
helm install loki grafana/loki \
  --namespace monitoring \
  -f helm-values/values-loki.yaml
```

> O arquivo `helm-values/values-loki.yaml` contém todas as configurações abaixo com comentário explicativo em cada chave.

> 💡 **O que cada configuração faz:**
>
> | Flag | O que faz | Sem ele |
> |---|---|---|
> | `deploymentMode=SingleBinary` | Loki roda como um único processo (todos os componentes juntos) | Subiria no modo distribuído, que requer múltiplos pods separados |
> | `loki.auth_enabled=false` | Desabilita multi-tenancy — nenhum tenant precisa ser informado | Grafana e Fluent Bit precisariam enviar `X-Scope-OrgID: <tenant>` em toda requisição |
> | `loki.commonConfig.replication_factor=1` | Uma única réplica de cada chunk de log (sem redundância) | O padrão é 3 — o Loki recusaria writes por não ter quórum com um só pod |
> | `loki.storage.type=filesystem` | Armazena os logs em disco local do pod | O padrão espera S3/GCS/Azure — o pod ficaria em erro sem credenciais de object storage |
> | `loki.useTestSchema=true` | Injeta um `schema_config` padrão (v13, tsdb) | O chart 3.x falha na instalação exigindo schema explícito |
> | `singleBinary.replicas=1` | Sobe 1 pod do processo único | Nenhum pod é criado no modo SingleBinary |
> | `read/write/backend.replicas=0` | Desativa os microserviços do modo distribuído | Subiriam tentando formar cluster e ficariam em erro sem a infraestrutura completa |
> | `chunksCache.enabled=false` | Desativa o Memcached de cache de chunks de log | Sobe um StatefulSet de Memcached que pode ficar Pending por falta de memória no Kind |
> | `resultsCache.enabled=false` | Desativa o Memcached de cache de resultados de queries | Idem — pod extra desnecessário em ambiente local |
> | `lokiCanary.enabled=false` | Desativa o Loki Canary (pod que testa o Loki continuamente) | Sobe um pod extra que consome recursos sem utilidade didática aqui |
> | `test.enabled=false` | Desativa os Helm tests do chart (que dependem do canary) | O `helm upgrade` falha com erro de validação se o canary estiver desabilitado mas os testes não |
> | `minio.enabled=false` | Não sobe um MinIO embutido como object storage | O chart criaria um StatefulSet de MinIO desnecessário aqui |
> | `grafana.enabled=false` | Não instala um segundo Grafana dentro do chart do Loki | Conflitaria com o Grafana já instalado pelo `kube-prometheus-stack` |

Aguardar o Loki subir (pode demorar até 2 min):

**PowerShell e bash:**

```sh
kubectl get pods -n monitoring -w
# Aguarde:
# loki-0                1/1   Running   ← instância do Loki (SingleBinary)
# loki-gateway-xxxx     1/1   Running   ← proxy HTTP que roteia para o Loki
```

---

## Instalação do Fluent Bit (agente de coleta independente)

> 🎯 **Arquitetura desacoplada:** Em vez de embutir o agente dentro do chart do Loki (padrão legado do `loki-stack`), instalamos o Fluent Bit separadamente com o chart oficial `fluent/fluent-bit`. Cada node do cluster roda uma instância (DaemonSet) que lê os arquivos de log dos containers em `/var/log/containers/` e os envia ao gateway do Loki via HTTP. Isso permite trocar o agente por Fluentd, Vector ou outro sem reinstalar o Loki.

**PowerShell e bash:**

```sh
# Adicionar repositório oficial do Fluent Bit
helm repo add fluent https://fluent.github.io/helm-charts/
helm repo update
```

**PowerShell:**

```powershell
helm upgrade --install fluent-bit fluent/fluent-bit `
  --namespace monitoring `
  -f helm-values/values-fluent-bit.yaml
```

**bash / zsh:**

```bash
helm upgrade --install fluent-bit fluent/fluent-bit \
  --namespace monitoring \
  -f helm-values/values-fluent-bit.yaml
```

> **O que o `helm-values/values-fluent-bit.yaml` faz:**
>
> O chart padrão do Fluent Bit usa `stdout` como output — ou seja, não envia logs a lugar nenhum por padrão. O values sobrescreve dois blocos:
>
> - **`[FILTER] kubernetes`** — enriquece cada linha de log com os metadados do pod: namespace, nome do pod, nome do container, labels, etc. Sem esse filtro, os logs chegam ao Loki sem contexto — você não conseguiria filtrar por `namespace` ou `container` no Grafana.
> - **`[OUTPUT] loki`** — usa o plugin nativo do Fluent Bit para enviar os logs ao `loki-gateway.monitoring.svc.cluster.local:80` via HTTP. O campo `label_keys` extrai os metadados do filtro acima e os expõe como labels indexáveis no Loki (`kubernetes_namespace_name`, `kubernetes_container_name`, `kubernetes_pod_name`). Esses labels são exatamente os que você usará nas queries LogQL do Grafana.

Aguardar o Fluent Bit subir (DaemonSet — um pod por node do cluster):

**PowerShell e bash:**

```sh
kubectl get pods -n monitoring -w
# Aguarde: fluent-bit-xxxx   1/1   Running
```

---

### Adicionar Loki como datasource no Grafana

1. Acesse **http://localhost:3000**
2. Vá em **Connections → Data Sources → Add data source → Loki**
3. **URL:** `http://loki-gateway.monitoring.svc.cluster.local`
4. Clique em **Save & Test**

> ✅ Com `loki.auth_enabled=false`, o Grafana conecta direto ao gateway sem nenhum header adicional. O "Save & Test" deve retornar sucesso imediato.

### Verificar logs do Super Mario no Grafana

```
Grafana → Explore → Selecione datasource: Loki
⚠️ Ajuste o intervalo de tempo para "Last 1 hour" (canto superior direito)
Label filter: kubernetes_namespace_name = games
Label filter: kubernetes_container_name = super-mario
Clique em Run query
```

Query LogQL equivalente:
```logql
{kubernetes_namespace_name="games", kubernetes_container_name="super-mario"}
```

> 💡 Os labels `kubernetes_namespace_name` e `kubernetes_container_name` vêm do metadado Kubernetes enriquecido pelo filtro do Fluent Bit (`label_keys` no `[OUTPUT]` do Loki plugin). Se os labels não aparecerem no dropdown, o Fluent Bit pode ter sido instalado antes dessa configuração — rode `helm upgrade --install fluent-bit fluent/fluent-bit --namespace monitoring -f helm-values/values-fluent-bit.yaml` e aguarde o DaemonSet reiniciar.

> ⚠️ Se o dropdown aparecer vazio, verifique o intervalo de tempo. O Loki expira queries sem range de tempo explícito — use sempre "Last 1 hour" ou mais no Grafana Explore.

---

## Instalar o Blackbox Exporter (latência sintética)

> 🎯 **O que é?** O Blackbox Exporter funciona como um cliente persistente: fica batendo no Service do Super Mario a cada 15 segundos e mede o tempo de resposta HTTP. É monitoramento **sintético** — não depende de instrumentação no código do app. A métrica resultante é `probe_duration_seconds`, que mede a latência de ponta a ponta vista de fora do pod.

**PowerShell e bash:**

```sh
helm install blackbox-exporter prometheus-community/prometheus-blackbox-exporter \
  --namespace monitoring
```

Aguardar subir:

```sh
kubectl get pods -n monitoring -w
# Aguarde: blackbox-exporter-prometheus-blackbox-exporter-xxxx   1/1   Running
```

Aplicar o recurso `Probe` que diz ao Prometheus qual URL sondar:

**PowerShell e bash:**

```sh
kubectl apply -f manifests/02-blackbox-probe.yaml
```

O recurso `Probe` é um CRD do Prometheus Operator. Confirmar que foi carregado:

```sh
kubectl get probe -n monitoring
# NAME                  AGE
# super-mario-http      10s
```

Após ~30 segundos, confirmar no Prometheus que a métrica chegou:

```
http://localhost:9090 → Graph → execute:
probe_duration_seconds{job="blackbox-mario"}
```

> ⚠️ **Se não retornar dados: o `probeSelector` requer um label específico**
>
> O Prometheus Operator só descobre recursos `Probe` (e `ServiceMonitor`, `PodMonitor`, `PrometheusRule`) que tenham os labels definidos no seletor da instância do Prometheus. Neste setup, o seletor exige `release: kind-prometheus`:
>
> ```sh
> kubectl get prometheus -n monitoring \
>   -o jsonpath='{.items[*].spec.probeSelector}'
> # Retorna: {"matchLabels":{"release":"kind-prometheus"}}
> ```
>
> O arquivo `manifests/02-blackbox-probe.yaml` já inclui esse label. Se o Probe foi aplicado antes dessa correção, reaplicar:
>
> ```sh
> kubectl apply -f manifests/02-blackbox-probe.yaml
> ```
>
> A mesma regra vale para qualquer `ServiceMonitor` ou `PodMonitor` customizado que você criar — sem o label `release: kind-prometheus`, o Prometheus não vai coletar.

**Diagnóstico rápido se ainda não aparecer:**

**PowerShell:**
```powershell
# Confirmar que o label foi aplicado
kubectl get probe super-mario-http -n monitoring --show-labels

# Verificar se o Blackbox Exporter está rodando
kubectl get pods -n monitoring | Select-String "blackbox"

# Testar o exporter diretamente (em outro terminal, abra o port-forward):
kubectl port-forward svc/blackbox-exporter-prometheus-blackbox-exporter -n monitoring 9115:9115
```

**bash / zsh:**
```bash
kubectl get probe super-mario-http -n monitoring --show-labels
kubectl get pods -n monitoring | grep blackbox
kubectl port-forward svc/blackbox-exporter-prometheus-blackbox-exporter -n monitoring 9115:9115
```

Com o port-forward ativo, testar a sondagem manualmente:
```sh
curl "http://localhost:9115/probe?target=http://super-mario-service.games.svc.cluster.local:8080&module=http_2xx"
# Procure: probe_success 1  (1 = OK, 0 = falhou)
# Procure: probe_duration_seconds <valor>
```

---

## Aplicar os alertas dos Four Golden Signals

**PowerShell e bash:**

```sh
kubectl apply -f manifests/01-four-golden-signals.yaml
```

Verificar se o Prometheus carregou as regras:

**PowerShell e bash:**

```sh
kubectl get prometheusrule -n monitoring
```

Confirmar no Prometheus UI:
```
http://localhost:9090 → Status → Rule Health → four-golden-signals.games
```

---

## Ativar os Grafana Alert Rules

> Os alertas acima são avaliados pelo **Prometheus** e roteados pelo **Alertmanager**. O Grafana tem seu próprio motor de alertas (Unified Alerting) — avalia regras independentemente e pode notificar por Contact Points cadastrados direto no Grafana (Discord, Slack, e-mail).
>
> São dois sistemas **paralelos e complementares**: o Alertmanager é o padrão para alertas de infraestrutura, enquanto os Grafana alert rules são úteis quando times de negócio querem configurar notificações sem mexer no Alertmanager.

### Passo 1 — Habilitar o sidecar de alertas

O arquivo `helm-values/values-prometheus-stack.yaml` já inclui `grafana.sidecar.alerts.enabled: true`. Faça o upgrade para aplicar:

**PowerShell:**

```powershell
helm upgrade kind-prometheus prometheus-community/kube-prometheus-stack `
  --namespace monitoring `
  -f helm-values/values-prometheus-stack.yaml
```

**bash / zsh:**

```bash
helm upgrade kind-prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f helm-values/values-prometheus-stack.yaml
```

O sidecar `grafana-sc-alerts` passa a monitorar ConfigMaps com label `grafana_alert: "1"` e os provisionam automaticamente no Grafana.

### Passo 2 — Aplicar o ConfigMap com as regras

**PowerShell e bash:**

```sh
kubectl apply -f manifests/03-grafana-alert-rules.yaml
```

Verificar se o sidecar carregou (aguarde ~10s após aplicar):

**PowerShell:**

```powershell
kubectl logs -n monitoring `
  -l app.kubernetes.io/name=grafana `
  -c grafana-sc-alerts --tail=20
# Deve aparecer: "Configmap added" ou "Updating existing configmap"
```

**bash / zsh:**

```bash
kubectl logs -n monitoring \
  -l app.kubernetes.io/name=grafana \
  -c grafana-sc-alerts --tail=20
```

Verificar no Grafana:

```
http://localhost:3000 → Alerting → Alert Rules
Pasta: K8s Essentials → 6 regras listadas (fgs-alto-trafego, fgs-pod-restart, ...)
```

> ⚠️ **Se as regras aparecerem com erro de datasource**
>
> As regras usam `datasourceUid: prometheus`. Se o UID do Prometheus no seu Grafana for diferente, as regras são carregadas mas não executam as queries.
>
> Para verificar o UID real:
> ```
> Grafana → Connections → Data sources → Prometheus → campo UID
> ```
>
> Se necessário, corrija no ConfigMap:
>
> **PowerShell e bash:**
> ```sh
> kubectl edit configmap grafana-alert-rules-four-golden-signals -n monitoring
> # Substitua todas as ocorrências de: datasourceUid: prometheus
> # pelo UID real encontrado no Grafana
> ```
>
> O sidecar detecta a mudança e recarrega automaticamente.

---

## Criar o dashboard dos Four Golden Signals no Grafana

> O objetivo é ter uma única tela que mostre os 4 signals do Super Mario em tempo real: Tráfego, Erros, Saturação e Latência. Cada painel usa a mesma lógica das regras de alerta — assim você vê o número que vai acionar o alerta antes dele disparar.

### Opção A — Importar o JSON pronto (recomendado)

Em algumas versões do Grafana, o editor de painéis pode apresentar um erro React ao adicionar a primeira visualização (`An unexpected error happened`). A forma mais confiável — e a usada em produção — é importar o dashboard via JSON:

1. Acesse **http://localhost:3000**, faça login
2. Menu lateral → **Dashboards → New → Import**
3. Clique em **Upload dashboard JSON file**
4. Selecione o arquivo `grafana-dashboards/four-golden-signals.json`
5. No campo **Prometheus**, selecione o datasource `Prometheus`
6. Clique em **Import**

O dashboard abre com os 5 painéis já configurados, com thresholds, unidades corretas e auto-refresh de 10s.

---

### Opção B — Criar painel a painel pela UI

Use se quiser entender cada configuração individualmente. Se aparecer o erro React, tente:
1. `Ctrl+Shift+R` para forçar um reload completo da página
2. Entrar no dashboard vazio e usar o menu **Add → Visualization** (em vez do botão `+` central)

Acesse **http://localhost:3000**, faça login e siga os passos abaixo.

1. Menu lateral → **Dashboards → New → New dashboard**
2. Clique em **+ Add visualization**
3. No seletor de datasource: escolha **Prometheus**

> Você vai criar 5 painéis. Para cada um: cole a query, configure o título/unidade e clique em **Apply**. Depois **Add → Visualization** para o próximo.

#### Painel 1 — Tráfego (Traffic)

**Query:**
```promql
sum(rate(container_network_receive_bytes_total{namespace="games", pod!=""}[5m]))
```

**Configuração:**
| Campo | Valor |
|---|---|
| Título | `Tráfego de Rede — namespace games` |
| Tipo de visualização | Time series |
| Unit (em Standard options) | `bytes/sec (SI)` |
| Thresholds | Base: verde → 1048576 (1 MB/s): amarelo |

> A linha vermelha tracejada no painel aparece quando você adiciona o threshold de 1048576 — o mesmo valor do alerta `AltoTrafego`.
>
> ⚠️ **Por que `pod!=""` e não `container!=""`?** Métricas de rede são coletadas em nível de pod — todos os containers de um pod compartilham o mesmo namespace de rede. O label `container` fica vazio nessas métricas, então `container!=""` filtra tudo e o painel aparece em branco. Use `pod!=""` para excluir apenas entradas sem pod associado.

#### Painel 2 — Erros: Restarts de containers

**Query:**
```promql
sum by (pod) (increase(kube_pod_container_status_restarts_total{namespace="games"}[15m]))
```

**Configuração:**
| Campo | Valor |
|---|---|
| Título | `Restarts de Pods (últimos 15 min)` |
| Tipo de visualização | Time series |
| Unit | `short` |
| Thresholds | Base: verde → 2: vermelho |

> Quando qualquer pod ultrapassar 2 restarts em 15 min, a linha vira vermelha — mesma condição do alerta `PodRestartandoFrequentemente`.

#### Painel 3 — Erros: Pods não Ready

**Query:**
```promql
sum(kube_pod_status_ready{namespace="games", condition="false"})
```

**Configuração:**
| Campo | Valor |
|---|---|
| Título | `Pods fora do estado Ready` |
| Tipo de visualização | Stat |
| Unit | `short` |
| Thresholds | Base: verde → 1: vermelho |
| Color mode | Background |

> No modo Stat com Background, o painel vira vermelho assim que qualquer pod sai do estado Ready.

#### Painel 4 — Saturação: CPU vs Limit

**Query A** (uso atual):
```promql
sum by (pod) (
  rate(container_cpu_usage_seconds_total{namespace="games", container="super-mario"}[5m])
)
/
sum by (pod) (
  kube_pod_container_resource_limits{namespace="games", container="super-mario", resource="cpu"}
)
```

**Configuração:**
| Campo | Valor |
|---|---|
| Título | `CPU — % do Limit (Super Mario)` |
| Tipo de visualização | Time series |
| Unit | `Percent (0.0-1.0)` |
| Thresholds | Base: verde → 0.8: amarelo → 0.95: vermelho |

#### Painel 5 — Saturação: Réplicas do HPA

**Query A** — réplicas atuais:
```promql
kube_horizontalpodautoscaler_status_current_replicas{namespace="games"}
```

**Query B** — réplicas máximas (label: `max`):
```promql
kube_horizontalpodautoscaler_spec_max_replicas{namespace="games"}
```

**Configuração:**
| Campo | Valor |
|---|---|
| Título | `Saturação — Réplicas do HPA` |
| Tipo de visualização | Time series |
| Unit | `short` |
| Thresholds | Base: verde → (valor do maxReplicas): vermelho |

> Quando a linha de atual tocar a linha de máximo, o alerta `HPANoLimiteMaximo` vai disparar. O painel deixa isso visível antes do alerta chegar.

#### Painel 6 — Latência (Latency)

> Requer o Blackbox Exporter instalado e o `Probe` aplicado (seção anterior).

**Query:**
```promql
probe_duration_seconds{job="blackbox-mario"}
```

**Configuração:**
| Campo | Valor |
|---|---|
| Título | `Latência HTTP — Super Mario (Blackbox Exporter)` |
| Tipo de visualização | Time series |
| Unit | `seconds (s)` |
| Thresholds | Base: verde → 0.5s: amarelo → 1.0s: vermelho |

> O Blackbox Exporter bate no `super-mario-service.games.svc.cluster.local:8080` a cada 15s e mede o tempo total de resposta HTTP. Sob stress test, a latência sobe à medida que os pods ficam sobrecarregados.

#### Salvar o dashboard

1. Clique no ícone 💾 (Save dashboard) no canto superior direito
2. Nome: `Four Golden Signals — Super Mario`
3. Pasta: `General` (ou crie `Módulo 03`)
4. Clique em **Save**

#### Ajustar o auto-refresh

No canto superior direito do dashboard:
- Intervalo de tempo: **Last 1 hour**
- Auto-refresh: **10s** (ícone de relógio ao lado do intervalo)

#### Ver os painéis durante o stress test

```sh
# Subir o stress test (se ainda não estiver rodando)
kubectl apply -f ../modulo-02-deploy-app/manifests/04-stress-test-fortio.yaml
```

Abra o dashboard e observe:
- **Painel 1 (Tráfego):** curva sobe e cruza o threshold de 1 MB/s
- **Painel 4 (CPU):** % do limit sobe — quando passar de 80% por 3 min → alerta `AltoCPUSuperMario`
- **Painel 5 (HPA):** réplicas sobem; quando atingir o máximo → alerta `HPANoLimiteMaximo`
- **Painel 6 (Latência):** tempo de resposta HTTP sobe à medida que os pods ficam sobrecarregados

---

## Acessar os serviços

### Prometheus
- **Opção A (NodePort):** http://localhost:9090
- **Opção B (port-forward):** `kubectl port-forward svc/kind-prometheus-kube-prome-prometheus -n monitoring 9090:9090`

### Grafana
- **Opção A (NodePort):** http://localhost:3000
- **Opção B (port-forward):** `kubectl port-forward svc/kind-prometheus-grafana -n monitoring 3000:80`
- **Login:** usuário `admin` / senha: recupere com o comando abaixo

Se a senha padrão `prom-operator` não funcionar, busque a senha real do secret:

**PowerShell:**

```powershell
kubectl --namespace monitoring get secret kind-prometheus-grafana `
  -o jsonpath="{.data.admin-password}" |
  ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

**bash / zsh:**

```bash
kubectl --namespace monitoring get secret kind-prometheus-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d ; echo
```

### Alertmanager
- **Opção A (NodePort):** http://localhost:9093
- **Opção B (port-forward):** `kubectl port-forward svc/kind-prometheus-kube-prome-alertmanager -n monitoring 9093:9093`

---

## Receber alertas no Discord

> 🎯 Os alertas dos Four Golden Signals são gerados pelo **Prometheus** (via PrometheusRule) e enviados ao **Alertmanager**. O Alertmanager usa sua própria configuração de roteamento — independente do Grafana — para decidir para onde enviar cada alerta. Para rotear ao Discord, configuramos o Alertmanager com um receiver Discord via `helm upgrade`.

> 💡 **Grafana Contact Points vs Alertmanager:** Os Contact Points do Grafana funcionam apenas para regras criadas diretamente no Grafana UI (Grafana-native alerts). Os alertas do `PrometheusRule` (como os Four Golden Signals) são avaliados pelo Prometheus e roteados pelo **Alertmanager**, que tem sua própria config — independente do Grafana.

### Passo 1 — Criar o webhook no Discord

1. No Discord, abra o canal onde quer receber os alertas
2. **Configurações do canal** (engrenagem) → **Integrações → Webhooks → Novo Webhook**
3. Dê um nome (ex: `k8s-alertas`) e clique em **Copiar URL do webhook**

A URL terá o formato:
```
https://discord.com/api/webhooks/SEU_ID/SEU_TOKEN
```

### Passo 2 — Configurar a URL do webhook

Você tem duas opções. Use a **Opção A** para testar localmente e a **Opção B** em ambientes reais.

---

#### Opção A — URL direto no arquivo (local / estudo)

Arquivo: `helm-values/values-alertmanager-discord.yaml`

Abra o arquivo e faça **duas** substituições:

**1. URL do webhook** — substitua `COLE_AQUI_A_URL_DO_WEBHOOK` pela URL copiada:

```yaml
    receivers:
      - name: "null"
      - name: discord
        discord_configs:
          - webhook_url: "https://discord.com/api/webhooks/SEU_ID/SEU_TOKEN"
```

**2. `externalUrl`** — os dois valores já estão preenchidos com `localhost`. Se estiver rodando em um cluster real (não Kind), substitua pelas URLs públicas do Prometheus e do Alertmanager:

```yaml
prometheus:
  prometheusSpec:
    externalUrl: http://SEU-PROMETHEUS-REAL:9090   # <- altere aqui

alertmanager:
  alertmanagerSpec:
    externalUrl: http://SEU-ALERTMANAGER-REAL:9093  # <- altere aqui
```

> O `externalUrl` controla o link "Source" que aparece nas mensagens do Discord. Com `localhost`, o link funciona apenas na sua máquina local.

> ⚠️ Nunca versione a URL real do webhook em repositórios públicos.

No Passo 3, use: `-f helm-values/values-alertmanager-discord.yaml`

---

#### Opção B — Secret Kubernetes + `webhook_url_file` (produção)

Arquivo: `helm-values/values-alertmanager-discord-secret.yaml`

A URL fica armazenada em um Secret no cluster — nunca aparece em YAML versionado nem em `helm get values`.

**1. Criar o Secret com a URL do webhook:**

```sh
kubectl create secret generic alertmanager-discord-webhook \
  --from-literal=webhook_url="https://discord.com/api/webhooks/SEU_ID/SEU_TOKEN" \
  -n monitoring
```

O arquivo `values-alertmanager-discord-secret.yaml` já está configurado com `alertmanagerSpec.secrets` e `webhook_url_file` — não precisa editar nada.

**2. Confirmar que o Secret foi montado no pod (após o helm upgrade do Passo 3):**

```sh
kubectl exec -n monitoring \
  statefulset/alertmanager-kind-prometheus-kube-prome-alertmanager -- \
  cat /etc/alertmanager/secrets/alertmanager-discord-webhook/webhook_url
```

No Passo 3, use: `-f helm-values/values-alertmanager-discord-secret.yaml`

---

### Passo 3 — Aplicar via helm upgrade

> ⚠️ O `--reuse-values` pode falhar se o chart foi atualizado desde a instalação (variáveis novas sem default). O comando abaixo exporta os valores atuais do release e aplica junto com o arquivo de Discord — é a forma segura.

Substitua o `-f` final pelo arquivo da opção que você escolheu no Passo 2.

**PowerShell:**

```powershell
helm get values kind-prometheus -n monitoring -o yaml |
  Out-File -Encoding utf8 "$env:TEMP\kind-prometheus-values.yaml"

# Opção A (URL direto):
helm upgrade kind-prometheus prometheus-community/kube-prometheus-stack `
  --namespace monitoring `
  -f "$env:TEMP\kind-prometheus-values.yaml" `
  -f helm-values/values-alertmanager-discord.yaml

# Opção B (Secret):
helm upgrade kind-prometheus prometheus-community/kube-prometheus-stack `
  --namespace monitoring `
  -f "$env:TEMP\kind-prometheus-values.yaml" `
  -f helm-values/values-alertmanager-discord-secret.yaml
```

**bash / zsh:**

```bash
helm get values kind-prometheus -n monitoring -o yaml > /tmp/kind-prometheus-values.yaml

# Opção A (URL direto):
helm upgrade kind-prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f /tmp/kind-prometheus-values.yaml \
  -f helm-values/values-alertmanager-discord.yaml

# Opção B (Secret):
helm upgrade kind-prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f /tmp/kind-prometheus-values.yaml \
  -f helm-values/values-alertmanager-discord-secret.yaml
```

Aguardar o Alertmanager reiniciar com a nova config:

**PowerShell e bash:**

```sh
kubectl rollout status statefulset/alertmanager-kind-prometheus-kube-prome-alertmanager -n monitoring
```

### Passo 4 — Confirmar que a config foi aplicada

Acesse **http://localhost:9093 → Status** e verifique o campo **Config**. O receiver `discord` deve aparecer com o bloco `discord_configs`.

### Passo 5 — Disparar um alerta para testar

**PowerShell e bash:**

```sh
# Gerar carga no Super Mario para acionar os Four Golden Signals
kubectl apply -f ../modulo-02-deploy-app/manifests/04-stress-test-fortio.yaml
```

Após ~3–5 minutos (tempo do `for:` nas regras), os alertas passam de `PENDING` para `FIRING`. O canal do Discord vai receber uma mensagem com os detalhes do alerta.

Para parar o stress test:

```sh
kubectl delete -f ../modulo-02-deploy-app/manifests/04-stress-test-fortio.yaml
```

Quando a carga parar e o alerta se resolver, o Discord recebe uma mensagem **✅ Resolved**.

### Como funciona o roteamento

```
PrometheusRule (FIRING)
    │
    ▼ HTTP POST
Prometheus → Alertmanager
    │
    ▼ Avalia as rotas em ordem
    ├── alertname =~ "Watchdog|InfoInhibitor"  →  receiver: null  (descartado)
    └── qualquer outro                         →  receiver: discord
                                                       │
                                                       ▼ HTTPS POST
                                               discord.com/api/webhooks/...
                                                       │
                                                       ▼
                                                Canal do Discord
```

---

## Usar o Alertmanager

> 🎯 O Alertmanager não gera alertas — ele **recebe** alertas do Prometheus e decide o que fazer com eles: agrupar, rotear para um canal (Slack, PagerDuty, e-mail) ou silenciar temporariamente. O Prometheus avalia as regras do `PrometheusRule`, identifica condições violadas e empurra os alertas para o Alertmanager via API.

Acesse: **http://localhost:9093**

### O que você verá na UI

| Aba | O que mostra |
|---|---|
| **Alerts** | Alertas ativos no momento, agrupados por `alertname` e labels |
| **Silences** | Silêncios ativos — alertas suprimidos temporariamente |
| **Status** | Configuração carregada, versão, uptime |

### Estados de um alerta

```
Prometheus avalia a regra
    │
    ├── condição não violada → (nada acontece)
    │
    ├── condição violada < for: 5m → PENDING  ← ainda não foi para o Alertmanager
    │
    └── condição violada ≥ for: 5m → FIRING   ← Alertmanager recebe e roteia
```

> O campo `for:` na `PrometheusRule` define o tempo mínimo que a condição precisa persistir antes do alerta virar `FIRING`. Isso evita alertas de spike momentâneo.

### Ver alertas ativos (FIRING) via linha de comando

**PowerShell e bash:**

```sh
# Listar alertas que o Prometheus está avaliando
kubectl get prometheusrule -n monitoring

# Ver o estado de cada regra diretamente no Prometheus
# http://localhost:9090 → Status → Rule Health
```

**PowerShell:**

```powershell
# Consultar a API do Alertmanager — alertas ativos
(Invoke-RestMethod "http://localhost:9093/api/v2/alerts") |
  Select-Object -ExpandProperty labels |
  Format-Table alertname, namespace, severity
```

**bash / zsh:**

```bash
curl -s http://localhost:9093/api/v2/alerts | jq '.[].labels | {alertname, namespace, severity}'
```

### Criar um silêncio (suprimir um alerta temporariamente)

Na UI do Alertmanager (**http://localhost:9093**):

1. Vá em **Silences → New Silence**
2. Preencha o **Matcher** com o label do alerta a suprimir:
   ```
   alertname = HighErrorRate
   namespace = games
   ```
3. Defina a duração (ex: `2h`)
4. Adicione um comentário explicando o motivo
5. Clique em **Create**

> O silêncio não cancela a avaliação da regra no Prometheus — o alerta continua `FIRING` internamente. O Alertmanager apenas para de notificar durante o período do silêncio.

### Fluxo completo: do código ao alerta

```
manifests/01-four-golden-signals.yaml   ← PrometheusRule (definição das regras)
        │
        ▼ kubectl apply
Prometheus Operator detecta o CRD e atualiza a config do Prometheus
        │
        ▼ avalia a cada 15s (padrão)
Prometheus → condição violada por N minutos → FIRING
        │
        ▼ HTTP POST /api/v2/alerts
Alertmanager → agrupa → roteia → notifica (ou silencia)
```

---

## Rodar o Stress Test e Observar no Grafana

**PowerShell e bash:**

```sh
# 1. Garantir que o Mario está rodando
kubectl get pods -n games

# 2. Disparar o stress test (Módulo 02)
kubectl apply -f ../modulo-02-deploy-app/manifests/04-stress-test-fortio.yaml

# 3. Em outro terminal: acompanhar HPA reagindo
kubectl get hpa -n games -w

# 4. No Grafana (http://localhost:3000):
#    Dashboards → Browse → Kubernetes → Compute Resources → Namespace (Pods)
#    Selecione namespace: games
#    Observe CPU e memória subindo em tempo real
```

---

## Verificar coleta de métricas do namespace games

> Abra o Prometheus em http://localhost:9090 e execute as queries abaixo no campo de expressão.

```promql
# Pods rodando no namespace games
kube_pod_info{namespace="games"}

# CPU dos pods do Mario (média 2 minutos)
sum(rate(container_cpu_usage_seconds_total{namespace="games", container!=""}[2m])) by (pod)

# Memória dos pods do Mario
container_memory_working_set_bytes{namespace="games", container="super-mario"}

# Réplicas do deployment ao longo do tempo
kube_deployment_status_replicas{namespace="games"}
```

---

## Troubleshooting: Loki não conecta no Grafana

### 1. Verificar se todos os pods subiram

**PowerShell:**

```powershell
kubectl get pods -n monitoring | Select-String "loki|fluent"
# Esperado:
# loki-0                1/1   Running   ← instância principal (SingleBinary)
# loki-gateway-xxxx     1/1   Running   ← proxy HTTP de entrada
# fluent-bit-xxxx       1/1   Running   ← agente de coleta (DaemonSet, um por node)
```

**bash / zsh:**

```bash
kubectl get pods -n monitoring | grep -E "loki|fluent"
```

Se não aparecer nenhum pod do Loki, volte para a seção "Instalação do Loki 3.x".
Se não aparecer o Fluent Bit, volte para "Instalação do Fluent Bit".

### 2. Verificar os Services do Loki

**PowerShell:**

```powershell
kubectl get svc -n monitoring | Select-String loki
# Esperado:
# loki              ClusterIP   ...   3100/TCP   ← porta interna do Loki
# loki-gateway      ClusterIP   ...   80/TCP     ← use este no Grafana
# loki-headless     ClusterIP   None  ...
# loki-memberlist   ClusterIP   None  ...
```

**bash / zsh:**

```bash
kubectl get svc -n monitoring | grep loki
```

### 3. Teste de fumaça — conectividade ao gateway

**PowerShell:**

```powershell
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never `
  -- curl http://loki-gateway.monitoring.svc.cluster.local/ready
# Esperado: ready
```

**bash / zsh:**

```bash
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never \
  -- curl http://loki-gateway.monitoring.svc.cluster.local/ready
# Esperado: ready
```

### 4. Verificar logs do Loki

**PowerShell e bash:**

```sh
kubectl logs -n monitoring loki-0 --tail=50
# Erros de ring nos primeiros 2-3 min são normais; aguarde o pod estabilizar
```

### 5. Verificar se o Fluent Bit está enviando logs

**PowerShell e bash:**

```sh
kubectl logs -n monitoring -l app.kubernetes.io/name=fluent-bit --tail=30
# Procure por linhas como: [output] loki > Flush chunk ... bytes
```

### 5b. Verificar diretamente na API do Loki quais namespaces foram indexados

**PowerShell:**

**PowerShell:**
```powershell
# Port-forward temporário para o gateway
kubectl port-forward svc/loki-gateway -n monitoring 3100:80

# Em outro terminal — namespaces indexados (última hora)
$start = [DateTimeOffset]::UtcNow.AddHours(-1).ToUnixTimeSeconds()
Invoke-RestMethod "http://localhost:3100/loki/api/v1/label/kubernetes_namespace_name/values?start=$start"
# Esperado: data: ["games", "kube-system", "monitoring"]

# Containers indexados
Invoke-RestMethod "http://localhost:3100/loki/api/v1/label/kubernetes_container_name/values?start=$start"
# Esperado: data: [..., "super-mario", ...]
```

**bash / zsh:**
```bash
# Port-forward temporário para o gateway (rode em um terminal separado)
kubectl port-forward svc/loki-gateway -n monitoring 3100:80

# Em outro terminal — namespaces indexados (última hora)
start=$(date -d '1 hour ago' +%s 2>/dev/null || date -v-1H +%s)
curl -sG "http://localhost:3100/loki/api/v1/label/kubernetes_namespace_name/values?start=$start"
# Esperado: {"data":["games","kube-system","monitoring"]}

# Containers indexados
curl -sG "http://localhost:3100/loki/api/v1/label/kubernetes_container_name/values?start=$start"
# Esperado: {"data":[..."super-mario"...]}
```

> Se `games` e `super-mario` aparecerem aqui mas não no Grafana, o problema é o **intervalo de tempo** no Grafana Explore — ajuste para "Last 1 hour".

### 6. URL correta no datasource do Grafana

Vá em **Connections → Data Sources → Loki** e confirme:

```
http://loki-gateway.monitoring.svc.cluster.local
```

> Sem porta explícita (usa 80 por padrão). Não use `:3100` — essa é a porta interna do Loki, não do gateway.

### 7. Reinstalar do zero (se necessário)

**PowerShell e bash:**

```sh
helm uninstall loki -n monitoring
helm uninstall fluent-bit -n monitoring
```

Em seguida, repita as seções de instalação acima.

---

## Limpar o ambiente

**PowerShell e bash:**

```sh
# Remover apenas o stack de monitoramento (manter o cluster)
helm uninstall kind-prometheus -n monitoring
helm uninstall loki -n monitoring
helm uninstall fluent-bit -n monitoring
kubectl delete namespace monitoring

# Ou deletar o cluster inteiro (mais rápido)
kind delete cluster --name k8s-essentials
```

---

## Resumo do que foi instalado

| Componente | Função | Porta |
|---|---|---|
| Prometheus | Coleta e armazena métricas | 9090 |
| Grafana | Dashboards visuais | 3000 |
| Alertmanager | Gerenciamento de alertas | 9093 |
| Node Exporter | Métricas do node (CPU/mem/disco) | 9100 |
| kube-state-metrics | Estado dos objetos K8s | interno |
| Prometheus Operator | Gerencia o Prometheus via CRDs | interno |
| Loki | Armazena e indexa logs (SingleBinary) | interno (3100) |
| Loki Gateway | Proxy HTTP de entrada para o Loki | interno (80) |
| Fluent Bit | Coleta logs dos containers (DaemonSet) | interno |
