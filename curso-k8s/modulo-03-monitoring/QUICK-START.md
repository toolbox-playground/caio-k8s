# 🚀 Módulo 03 — Guia de Início Rápido

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
  --set prometheus.service.nodePort=30090 `
  --set prometheus.service.type=NodePort `
  --set grafana.service.nodePort=31000 `
  --set grafana.service.type=NodePort `
  --set alertmanager.service.nodePort=32000 `
  --set alertmanager.service.type=NodePort `
  --set prometheus-node-exporter.service.nodePort=32001 `
  --set prometheus-node-exporter.service.type=NodePort
```

**bash / zsh (Linux, Mac, WSL):**

```bash
helm install kind-prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.service.nodePort=30090 \
  --set prometheus.service.type=NodePort \
  --set grafana.service.nodePort=31000 \
  --set grafana.service.type=NodePort \
  --set alertmanager.service.nodePort=32000 \
  --set alertmanager.service.type=NodePort \
  --set prometheus-node-exporter.service.nodePort=32001 \
  --set prometheus-node-exporter.service.type=NodePort
```

> 💡 A diferença entre os dois é apenas o caractere de continuação de linha: `` ` `` (backtick) no PowerShell e `\` (backslash) no bash/zsh.

> 💡 **O que cada `--set` faz:**
>
> | Flag | O que faz | Sem ele |
> |---|---|---|
> | `prometheus.service.nodePort=30090` + `type=NodePort` | Expõe o Prometheus na porta `30090` de cada node; mapeada para `localhost:9090` pelo Kind | O serviço fica `ClusterIP` — inacessível fora do cluster |
> | `grafana.service.nodePort=31000` + `type=NodePort` | Expõe o Grafana na porta `31000`; mapeada para `localhost:3000` | Idem |
> | `alertmanager.service.nodePort=32000` + `type=NodePort` | Expõe o Alertmanager na porta `32000`; mapeada para `localhost:9093` | Idem |
> | `prometheus-node-exporter.service.nodePort=32001` + `type=NodePort` | Expõe o Node Exporter na porta `32001`; mapeada para `localhost:9100` | Idem |
>
> O NodePort sozinho não é suficiente — o Kind também precisa do mapeamento `hostPort` no `cluster-config.yaml` para repassar a porta do container do Kind para o `localhost` do seu computador.

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
  --set deploymentMode=SingleBinary `
  --set loki.auth_enabled=false `
  --set loki.commonConfig.replication_factor=1 `
  --set loki.storage.type=filesystem `
  --set loki.useTestSchema=true `
  --set singleBinary.replicas=1 `
  --set read.replicas=0 `
  --set write.replicas=0 `
  --set backend.replicas=0 `
  --set chunksCache.enabled=false `
  --set resultsCache.enabled=false `
  --set lokiCanary.enabled=false `
  --set test.enabled=false `
  --set minio.enabled=false `
  --set grafana.enabled=false
```

**bash / zsh:**

```bash
helm install loki grafana/loki \
  --namespace monitoring \
  --set deploymentMode=SingleBinary \
  --set loki.auth_enabled=false \
  --set loki.commonConfig.replication_factor=1 \
  --set loki.storage.type=filesystem \
  --set loki.useTestSchema=true \
  --set singleBinary.replicas=1 \
  --set read.replicas=0 \
  --set write.replicas=0 \
  --set backend.replicas=0 \
  --set chunksCache.enabled=false \
  --set resultsCache.enabled=false \
  --set lokiCanary.enabled=false \
  --set test.enabled=false \
  --set minio.enabled=false \
  --set grafana.enabled=false
```

> 💡 **O que cada flag faz:**
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
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update
```

**PowerShell:**

```powershell
helm install fluent-bit fluent/fluent-bit `
  --namespace monitoring `
  -f manifests/values-fluent-bit.yaml
```

**bash / zsh:**

```bash
helm install fluent-bit fluent/fluent-bit \
  --namespace monitoring \
  -f manifests/values-fluent-bit.yaml
```

> O arquivo `manifests/values-fluent-bit.yaml` sobrescreve o bloco `[OUTPUT]` padrão do chart para apontar ao endpoint `http://loki-gateway.monitoring.svc.cluster.local:80/loki/api/v1/push`, adicionando automaticamente os labels de `namespace`, `pod` e `container` em cada stream de log.

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

> 💡 Os labels `kubernetes_namespace_name` e `kubernetes_container_name` vêm do metadado Kubernetes enriquecido pelo filtro do Fluent Bit (`label_keys` no `[OUTPUT]` do Loki plugin). Se os labels não aparecerem no dropdown, o Fluent Bit pode ter sido instalado antes dessa configuração — rode `helm upgrade fluent-bit fluent/fluent-bit --namespace monitoring -f manifests/values-fluent-bit.yaml` e aguarde o DaemonSet reiniciar.

> ⚠️ Se o dropdown aparecer vazio, verifique o intervalo de tempo. O Loki expira queries sem range de tempo explícito — use sempre "Last 1 hour" ou mais no Grafana Explore.

---

## Aplicar os alertas dos Four Golden Signals

**PowerShell e bash:**

```sh
kubectl apply -f manifests/03-four-golden-signals.yaml
```

Verificar se o Prometheus carregou as regras:

**PowerShell e bash:**

```sh
kubectl get prometheusrule -n monitoring
```

Confirmar no Prometheus UI:
```
http://localhost:9090 → Status → Rules → four-golden-signals.games
```

---

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

## Receber alertas por e-mail

> 🎯 O Alertmanager tem suporte nativo a SMTP. Para testar localmente sem precisar de conta real, usamos o **Mailhog** — um servidor SMTP falso com caixa de entrada acessível no browser. Para produção, basta trocar as configs do SMTP pelo Gmail (ou qualquer outro provedor).

### Passo 1 — Subir o Mailhog (caixa de entrada fake local)

**PowerShell e bash:**

```sh
kubectl apply -f manifests/mailhog.yaml
```

Aguardar subir e verificar:

**PowerShell e bash:**

```sh
kubectl get pods -n monitoring | grep mailhog
# Esperado: mailhog-xxxx   1/1   Running
```

Acesse a caixa de entrada em **http://localhost:8025**

> Se a porta 8025 não estiver mapeada no seu `cluster-config.yaml`, use port-forward:
> ```sh
> kubectl port-forward svc/mailhog -n monitoring 8025:8025
> ```

### Passo 2 — Aplicar a configuração de e-mail no Alertmanager

O arquivo `manifests/values-alertmanager-email.yaml` sobrescreve o bloco `alertmanager.config` do Helm release. Abra o arquivo e ajuste o campo `to:` com o e-mail de destino desejado (pode ser qualquer endereço — o Mailhog aceita tudo).

**PowerShell:**

```powershell
helm upgrade kind-prometheus prometheus-community/kube-prometheus-stack `
  --namespace monitoring `
  --reuse-values `
  -f manifests/values-alertmanager-email.yaml
```

**bash / zsh:**

```bash
helm upgrade kind-prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --reuse-values \
  -f manifests/values-alertmanager-email.yaml
```

> `--reuse-values` mantém todos os `--set` que foram usados na instalação original (NodePorts, etc.) e aplica apenas as novas configs do arquivo.

Aguardar o Alertmanager reiniciar com a nova config:

**PowerShell e bash:**

```sh
kubectl rollout status statefulset/alertmanager-kind-prometheus-kube-prome-alertmanager -n monitoring
```

### Passo 3 — Disparar um alerta e verificar o e-mail

```sh
# Sobe o stress test para gerar carga e disparar as regras dos Four Golden Signals
kubectl apply -f ../modulo-02-deploy-app/manifests/04-stress-test-fortio.yaml
```

Após ~5 minutos (tempo do `for:` nas regras), os alertas passam de `PENDING` para `FIRING` e o Alertmanager envia o e-mail. Verifique no Mailhog: **http://localhost:8025**

### Usar Gmail em vez do Mailhog (produção)

1. Gere uma **App Password** do Gmail em: https://myaccount.google.com/apppasswords  
   _(requer 2FA ativado na conta Google)_

2. Crie um Secret Kubernetes com a senha:

**PowerShell e bash:**

```sh
kubectl create secret generic alertmanager-smtp \
  --from-literal=password='SUA_APP_PASSWORD' \
  -n monitoring
```

3. No arquivo `manifests/values-alertmanager-email.yaml`, comente o bloco do Mailhog e descomente o bloco do Gmail:

```yaml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: '<seu-email>@gmail.com'
  smtp_auth_username: '<seu-email>@gmail.com'
  smtp_auth_password: '<sua-app-password>'
  smtp_require_tls: true
```

4. Repita o `helm upgrade` do Passo 2.

> ⚠️ Nunca coloque a senha em texto simples em arquivos versionados. O bloco acima é apenas para referência — em produção, use `smtp_auth_password_file` apontando para um Secret montado como volume, ou o campo `alertmanager.config.global.smtp_auth_password` via Secret do Helm.

### Como funciona o roteamento

```
PrometheusRule (FIRING)
    │
    ▼ HTTP POST /api/v2/alerts
Alertmanager
    ├── alertname = Watchdog ou InfoInhibitor  →  receiver: null  (descartado)
    ├── severity = critical                    →  receiver: email-receiver (imediato, 30m)
    └── qualquer outro                         →  receiver: email-receiver (group_wait: 30s)
                                                        │
                                                        ▼ SMTP → mailhog:1025
                                               Caixa de entrada: http://localhost:8025
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
# http://localhost:9090 → Status → Rules
```

**PowerShell:**

```powershell
# Consultar a API do Alertmanager — alertas ativos
Invoke-RestMethod "http://localhost:9093/api/v2/alerts" |
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
manifests/03-four-golden-signals.yaml   ← PrometheusRule (definição das regras)
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
