# 🧩 Módulo 02.1: Kustomize - O Elo Perdido do YAML

## 📖 Visão Geral

No Módulo 02, aprendemos a fazer o deploy do Super Mario usando arquivos YAML estáticos. Em um cenário real, você nunca tem apenas um ambiente. Você terá no mínimo:
- **Dev**: Onde os desenvolvedores testam bugs (economia de recursos).
- **Prod**: Onde o usuário final acessa (alta disponibilidade e performance).

Manter dois conjuntos de arquivos YAML quase idênticos é um pesadelo de manutenção. É aqui que entra o **Kustomize**.

O Kustomize permite que você defina uma **Base** (o YAML comum) e aplique **Overlays** (modificações específicas por ambiente) sem nunca tocar no arquivo original.

---

## 🎯 Objetivos de Aprendizado

- ✅ Entender a diferença entre Gestão de Configuração por Template (Helm) vs. Patches (Kustomize).
- ✅ Criar uma estrutura de Bases e Overlays.
- ✅ Customizar o número de réplicas e recursos (CPU/Memória) por ambiente.
- ✅ Aplicar Common Labels e Namespaces globalmente.
- ✅ Gerar ConfigMaps a partir de arquivos de propriedades (ConfigMapGenerator).

---

## 🛠️ Por Que Kustomize?

1. **Nativo do Kubectl**: Não precisa instalar ferramentas extras (`kubectl apply -k`).
2. **Template-free**: Você trabalha com YAML puro de Kubernetes, sem linguagens de script complexas dentro do YAML.
3. **Dry-run nativo**: Veja o resultado final antes de aplicar com `kubectl kustomize <folder>`.

---

## 📁 Estrutura do Módulo

```text
modulo-02.1-kustomize/
├── base/                # O YAML "puro" e comum
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
└── overlays/            # As variações de ambiente
    ├── dev/
    │   └── kustomization.yaml
    └── prod/
        └── kustomization.yaml
```

---

## 🚀 Desafio Prático

Você vai pegar o Mario que rodava com 1 réplica no Módulo 02 e transformá-lo em uma arquitetura robusta:
1. **Ambiente Dev**: Rodando no namespace `games-dev`, com 1 réplica.
2. **Ambiente Prod**: Rodando no namespace `games-prod`, com 3 réplicas e limites de CPU garantidos.

[Próximo Passo: Configurando a Base ➡️](base/README.md)
