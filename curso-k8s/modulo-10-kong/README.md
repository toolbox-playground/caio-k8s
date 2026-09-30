# Super Mario + Kong Gateway API no cluster `k8s-essentials`

Este pacote integra o jogo **Super Mario** e o **Kong** (via Gateway API) ao
seu cluster kind `k8s-essentials`, que já roda outros módulos (Prometheus,
Grafana, Mimir, MinIO, ArgoCD, Gitea). O Kong **coexiste** com o acesso
direto que você já tem ao Mario por NodePort (`localhost:8081`) — ele não
substitui nada que já funciona.

## Contexto: seu cluster já existe

Diferente de um setup do zero, aqui você está estendendo um cluster que já
está rodando. Isso muda duas coisas importantes:

1. **Os manifests do Mario e do Kong podem ser aplicados agora**, sem
   recriar o cluster — eles não dependem de `extraPortMappings` novos.
2. **Se você quiser que os mapeamentos de porta do Módulo 07 (ArgoCD `8080`
   e Gitea `33000`) do seu `cluster-config.yaml` realmente funionem**, você
   precisa recriar o cluster — `extraPortMappings` só é lido na criação do
   node, o kind não consegue adicioná-los a um cluster já em pé.

Se seu cluster atual já foi criado com uma versão anterior do
`cluster-config.yaml` (sem os blocos do Módulo 07), os Services do ArgoCD e
do Gitea podem até existir e funcionar internamente, mas não estarão
acessíveis em `localhost:8080` / `localhost:33000` até a recriação.

### Checklist de migração segura (delete + create do cluster)

Siga esta ordem para não perder trabalho:

1. **Exporte/garanta que tudo está versionado em manifests.** Se algo no
   cluster foi criado só via `kubectl create` imperativo ou `helm install`
   sem `values.yaml` salvo, regenere os arquivos antes de continuar:
   ```bash
   kubectl get all --all-namespaces -o yaml > backup-cluster-pre-migracao.yaml
   ```
   Trate esse backup como rede de segurança, não como fonte de verdade —
   prefira sempre reaplicar a partir dos seus manifests/Helm releases reais.

2. **Anote os releases Helm instalados**, para reinstalar na mesma ordem:
   ```bash
   helm list --all-namespaces
   ```

3. **Confirme que o ArgoCD não tem estado importante não commitado** (apps
   `OutOfSync` com mudanças manuais via UI, por exemplo). Se usar GitOps de
   verdade, o Git já é a fonte da verdade e a recriação é tranquila.

4. **Delete o cluster antigo:**
   ```bash
   kind delete cluster --name k8s-essentials
   ```

5. **Crie o cluster com o `cluster-config.yaml` atualizado** (o mesmo que
   você já tem, incluído neste pacote):
   ```bash
   kind create cluster --config cluster-config.yaml
   ```

6. **Reaplique tudo, módulo por módulo**, na ordem das suas próprias
   instalações (CRDs → Helm releases → manifests). Para o Kong + Mario,
   siga o passo a passo abaixo.

7. **Valide as portas uma a uma** antes de seguir para o próximo módulo:
   `localhost:8081` (Mario), `localhost:9090` (Prometheus), `localhost:3000`
   (Grafana), `localhost:9093` (Alertmanager), `localhost:9100` (Node
   Exporter), `localhost:4040` (Pyroscope), `localhost:9009` (Mimir),
   `localhost:9001` (MinIO), `localhost:8080` (ArgoCD), `localhost:33000`
   (Gitea).

> Se seu cluster atual **já tem** os blocos do Módulo 07 desde a criação
> (ou seja, você já recriou antes), pode pular esse checklist inteiro e ir
> direto para a seção abaixo.

## O que este pacote adiciona

- Namespace `games` com o Deployment e o Service (NodePort, porta `30000` →
  host `8081`, igual ao seu `cluster-config.yaml`) do Super Mario.
- Kong instalado via Helm no namespace `kong`, no modo **Gateway
  Discovery** (padrão atual, recomendado pela Kong).
- Um `Gateway` e um `HTTPRoute` (Gateway API) no namespace `kong`,
  roteando `/` para o Service do Mario em `games` — uma segunda via de
  acesso ao jogo, em paralelo ao NodePort.
- Uma `ReferenceGrant`, peça que faltava no material original e que é
  **obrigatória** para o `HTTPRoute` (em `kong`) referenciar um `Service`
  em outro namespace (`games`).

## Pré-requisitos

- Docker, kind, kubectl, Helm 3 já instalados (você já os usa nos outros
  módulos).
- Cluster `k8s-essentials` rodando.

## 1. Instalar os CRDs da Gateway API

Só precisa rodar uma vez por cluster. Se você já instalou em algum módulo
anterior, pode pular este passo.

```bash
kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/standard-install.yaml
```

## 2. Instalar o Kong via Helm

```bash
helm repo add kong https://charts.konghq.com
helm repo update

helm install kong kong/ingress `
  --namespace kong `
  --create-namespace
```

Por padrão, o Service de proxy do Kong (`kong-gateway-proxy`) sobe como
`LoadBalancer`. Em kind, sem MetalLB instalado, ele fica `<pending>`
indefinidamente — isso é esperado, não é erro. Você tem duas opções para
acessá-lo:

**Opção A — port-forward (mais simples, recomendado):**
```bash
kubectl port-forward -n kong svc/kong-gateway-proxy 8888:80
```
Acesse em `http://localhost:8888`. Mantenha o comando rodando enquanto usa.

**Opção B — NodePort fixo, igual aos outros módulos:**
Se preferir uma porta sempre disponível sem manter um terminal aberto,
reinstale apontando o proxy para NodePort, usando uma porta livre dentro do
range `30000-40000` que seu `cluster-config.yaml` já abre (por exemplo,
`30880`, que não colide com nenhum módulo existente):
```bash
helm upgrade kong kong/ingress `
  --namespace kong `
  --set proxy.type=NodePort `
  --set proxy.http.nodePort=30880
```
Para isso responder em `localhost`, adicione ao `cluster-config.yaml`:
```yaml
    - containerPort: 30880
      hostPort: 8082
      protocol: TCP
```
e recrie o cluster (mesmo checklist da seção anterior).

Verifique se os pods do Kong subiram:
```bash
kubectl get pods -n kong
```

## 3. Aplicar os manifests deste pacote

```bash
kubectl apply -f manifests/
```

Ou na ordem, se preferir acompanhar:
```bash
kubectl apply -f manifests/00-namespace-games.yaml
kubectl apply -f manifests/01-deployment-mario.yaml
kubectl apply -f manifests/02-service-mario.yaml
kubectl apply -f manifests/04-kong-gateway.yaml
kubectl apply -f manifests/05-mario-httproute.yaml
kubectl apply -f manifests/06-referencegrant.yaml
```

> `manifests/03-kong-gatewayclass.yaml` é só referência/fallback — o Helm
> já cria a `GatewayClass kong` automaticamente no modo Gateway Discovery.
> Só aplique se `kubectl get gatewayclass` não mostrar `kong`.

## 4. Verificar

```bash
kubectl get pods -n games
kubectl get gateway -n kong
kubectl describe httproute mario-route -n kong
```

A condição `ResolvedRefs` no `describe` deve estar `True`. Se vier `False`,
confira se a `ReferenceGrant` foi aplicada (`kubectl get referencegrant -n games`).

## 5. Acessar o jogo (duas vias, ambas válidas)

- **Via NodePort direto (Módulo 02, já validado):** `http://localhost:8081`
- **Via Kong Gateway (novo):** `http://localhost:8888` (ou `:8082` se você
  escolheu a Opção B com NodePort fixo)

## O que foi corrigido em relação aos arquivos originais enviados

| Arquivo | Problema encontrado | Correção |
|---|---|---|
| `kong-gatewayclass.yaml` | `controllerName: konghq.com/gateway-controller` — não existe | `konghq.com/kic-gateway-controller` |
| `meu-gateway.yaml` / `mario-gateway-route.yaml` | Dois `Gateway` concorrentes em namespaces diferentes (`default` e `games`) | Unificado em um único `Gateway` (`kong-gateway`, namespace `kong`) |
| Geral | `HTTPRoute` cruzando namespace sem `ReferenceGrant` | Adicionada `06-referencegrant.yaml` |
| Geral | Namespace `games` nunca era criado explicitamente | Adicionado `00-namespace-games.yaml` |
| `02-service-mario.yaml` | — | Mantido `NodePort` (porta `30000`/host `8081`), por decisão sua de coexistência com o Kong |
| README original | Gateway API CRDs na `v1.0.0`, desatualizada | Atualizado para `v1.5.1` |

## Estrutura dos arquivos

```
cluster-config.yaml             # Config do cluster kind (com Módulo 07: ArgoCD + Gitea)
manifests/
├── 00-namespace-games.yaml      # Namespace da aplicação
├── 01-deployment-mario.yaml     # Deployment do Super Mario (games)
├── 02-service-mario.yaml        # Service NodePort do Mario (games), 30000 -> host 8081
├── 03-kong-gatewayclass.yaml    # GatewayClass — referência/fallback
├── 04-kong-gateway.yaml         # Gateway (kong), escuta HTTP:80
├── 05-mario-httproute.yaml      # HTTPRoute (kong) -> Service (games)
└── 06-referencegrant.yaml       # Libera o cross-namespace kong -> games
README.md
```

## Solução de problemas comuns

**Service `kong-gateway-proxy` fica `<pending>` em `EXTERNAL-IP`**
Esperado em kind sem MetalLB. Use port-forward (Opção A) ou troque para
NodePort (Opção B).

**`HTTPRoute` com `ResolvedRefs: False`**
Confirme a `ReferenceGrant` em `games`, com `from.namespace: kong` e
`to.name: super-mario-service`.

**Porta já em uso ao tentar `kind create cluster`**
Outro processo (ex.: um port-forward antigo de outro módulo) pode estar
ocupando a porta do host. Rode `lsof -i :PORTA` para identificar e finalize
o processo antes de recriar.

**Pods do Mario em `ImagePullBackOff`**
A imagem `pengbai/docker-supermario:latest` é pública; se o kind não
conseguir baixá-la, carregue manualmente após `docker pull` local:
```bash
kind load docker-image pengbai/docker-supermario:latest --name k8s-essentials
```
