# 🐍 Abordagem 1: Pyroscope SDK

> **Resumo:** instrumentação direto no código Python com `pyroscope-io`.  
> A aplicação amostra o próprio call stack e **envia (push)** os profiles para o Pyroscope Server.

## Quando usar esta abordagem

- ✅ Você controla o código-fonte da aplicação
- ✅ Precisa de `tag_wrapper` — perfis separados por endpoint, feature flag ou usuário
- ✅ Quer correlação precisa **Trace → Profile** (Tempo ↔ Pyroscope via `service.name`)
- ✅ A linguagem tem SDK suportado: Python, Go, Java, Ruby, .NET, Node.js

## O que muda em relação ao Módulo 04

| Arquivo | Mudança |
|---|---|
| `app/requirements.txt` | `+ pyroscope-io==0.8.7` |
| `app/main.py` | `pyroscope.configure()` no startup + `tag_wrapper` em cada endpoint |
| `app/Dockerfile` | `+ gcc python3-dev` para compilar extensão C do SDK |
| `manifests/01-deployment-ranking-api-v2.yaml` | `+ PYROSCOPE_*` env vars |
| `manifests/cluster-config.yaml` | `+ porta 34040 → 4040` para a UI do Pyroscope |

## Como funciona

```
ranking-api (Python)
  └── pyroscope-io SDK (thread de background)
      ├── a cada ~10ms: snapshot do call stack
      ├── a cada 15s:  agrega + envia via HTTP POST
      └── → http://pyroscope.monitoring.svc.cluster.local:4040/ingest
```

## Tag wrapper — por que isso importa

Sem `tag_wrapper`, todos os endpoints aparecem misturados num único flame graph.  
Com `tag_wrapper`, você consegue no Grafana:

```python
# Cada endpoint tem seu próprio "slice" de profile
with pyroscope.tag_wrapper({"endpoint": "/rankings"}):
    resultado = calcular_rankings()   # tempo daqui é taggeado como endpoint=/rankings

with pyroscope.tag_wrapper({"endpoint": "/score"}):
    resultado = salvar_score()        # tempo daqui é taggeado como endpoint=/score
```

Filtro no Grafana: `{service_name="ranking-api", endpoint="/rankings"}`  
Diff flame graph: `/rankings` v2.0.0 vs v1.0.0

## Estrutura

```
pyroscope-sdk/
├── README.md                              ← você está aqui
├── QUICK-START.md                         ← guia passo a passo
├── app/
│   ├── main.py                            ← ranking-api v2 com pyroscope.configure() + tag_wrapper
│   ├── requirements.txt                   ← + pyroscope-io==0.8.7
│   └── Dockerfile                         ← + gcc/python3-dev para compilar o SDK C
├── helm-values/
│   └── values-pyroscope.yaml              ← Pyroscope Server (NodePort 4040, retenção 1h)
└── manifests/
    ├── cluster-config.yaml                ← Kind com porta 34040→4040
    └── 01-deployment-ranking-api-v2.yaml  ← Deployment com PYROSCOPE_* env vars
```

## Início rápido

Veja o [QUICK-START.md](QUICK-START.md) para o guia completo.

> 📚 Para a **teoria** (o que é um profiler, flame graph, 4 pilares, casos de uso), consulte o [README.md do módulo](../README.md).
