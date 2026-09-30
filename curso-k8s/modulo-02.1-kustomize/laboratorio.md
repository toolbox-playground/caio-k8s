# 🧪 Laboratório: Multi-Ambiente com Kustomize

Neste laboratório, você vai aprender a gerenciar múltiplos ambientes sem duplicar código.

## 🚀 Passo 1: Preparando o Ambiente

Certifique-se de que seu cluster Kind está rodando:
```powershell
kind get clusters
```

Crie os namespaces necessários:
```powershell
kubectl create namespace mario-dev
kubectl create namespace mario-prod
```

---

## 🛠️ Passo 2: O Poder do "Dry-Run"

Antes de aplicar qualquer coisa, o Kustomize permite que você veja o YAML final gerado. Isso é fundamental para evitar erros em produção.

### Visualizando o Ambiente de DEV
```powershell
kubectl kustomize overlays/dev
```
**Observe:**
- O `name` do deployment agora é `dev-super-mario`.
- O `namespace` é `mario-dev`.
- Existe um `ConfigMap` gerado automaticamente com um hash no nome (proteção contra cache).

### Visualizando o Ambiente de PROD
```powershell
kubectl kustomize overlays/prod
```
**Observe:**
- O número de `replicas` subiu para 3.
- Os `limits` de CPU e Memória são maiores.

---

## 🚢 Passo 3: Deploy dos Ambientes

Agora, vamos aplicar os dois ambientes simultaneamente:

```powershell
# Deploy Dev
kubectl apply -k overlays/dev

# Deploy Prod
kubectl apply -k overlays/prod
```

### Verificando os Pods
```powershell
# Ver pods de Dev
kubectl get pods -n mario-dev

# Ver pods de Prod
kubectl get pods -n mario-prod
```

---

## 🔍 Questões de Fixação

1. **Por que o Kustomize é considerado "template-free"?**
   > Porque ele não usa placeholders como `{{ .Values.name }}`, mas sim arquivos YAML válidos que são "remontados" via patches.

2. **O que acontece se eu mudar uma imagem no arquivo `base/deployment.yaml`?**
   > A mudança será propagada automaticamente para todos os overlays (Dev e Prod) no próximo deploy.

3. **Qual a vantagem do `configMapGenerator` em relação a um ConfigMap comum?**
   > Ele gera um novo nome (hash) sempre que o conteúdo muda, forçando o Kubernetes a reiniciar os pods (Rollout) para ler a nova configuração.

---

## 🧹 Limpeza

```powershell
kubectl delete -k overlays/dev
kubectl delete -k overlays/prod
kubectl delete ns mario-dev mario-prod
```
