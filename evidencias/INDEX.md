# Índice de evidências

Fotografias datadas, não garantia de estado atual. Originais preservados.
Não publicar states, planos, logs privados ou credenciais.

| Registro | Comprovação e alcance |
| --- | --- |
| [Kubernetes/HPA](2026-10-27-kubernetes-hpa.txt) | Nós, CNI/métricas e sintético 1→4→1; não API |
| [Metrics](2026-10-27-metrics-idempotencia.txt) | Reexecução autorizada com spec preservada |
| [Grafana preflight](2026-10-27-grafana-preflight.md) | Capacidade antes da instalação; histórico |
| [Grafana plano](2026-10-27-grafana-plano.txt) | Preparação; hash/Fleet não representam values final |
| [Grafana cluster](2026-10-27-grafana-cluster.txt) | Saúde/consumo dos agentes |
| [Grafana API](2026-10-27-grafana-cloud-api.json) | Métricas; 401 Loki não indica falha de envio |
| [Grafana fontes](2026-10-27-grafana-fontes.json) | Leitura de arquivos; não prova isolada de chegada |
| [Grafana envio](2026-10-27-grafana-envio.json) | Aceitação Loki HTTP 204 e contadores |
| [Grafana RBAC](2026-10-27-grafana-rbac.txt) | Verificações seletivas, não auditoria completa |
| [Grafana smoke](2026-10-27-grafana-smoke.txt) | Marcador/eventos; não logs JSON de negócio |
| [Grafana manual](2026-10-27-grafana-validacao-manual.md) | Logs/74 eventos confirmados pelo usuário |
| [CI local antigo](2026-10-27-cicd-local.md) | Quatro testes da versão anterior |
| [CI real](2026-10-27-ci-github-feature.md) | Falha lockfile/correção/CI aprovado |
| [Deploy](tc3-deploy-kubernetes-validacao.txt) | Pods/Jobs/eventos; v1/v2 falhas históricas, v3 Complete |
| [Resultado API](tc3-deploy-resultado-local.json) | Schema/Swagger/API e HPA configurado, sem carga nessa consulta |
| [Cloud API](tc3-deploy-observabilidade-local.json) | Séries CPU/memória; readiness sem série nessa consulta |
| [Loki API](tc3-deploy-loki-confirmacao-manual-local.json) | Confirmação manual, sem screenshot |
| [Resultados finais](2026-10-28-resultados-informados.md) | HPA 1→2/9.986 HTTP e Apply sem alterações: declaração identificada |
| [Testes atuais](../docs/VALIDACAO-LOCAL-CICD.md) | Fluxo homolog/main local, sem operações remotas |

Versionar os registros técnicos sanitizados selecionados e este índice.
Rascunhos podem permanecer locais se não ajudarem a avaliação; não apagá-los.
Topologia/identidade em logs pode exigir cópia sanitizada identificada, preservando
a fonte. Não alterar arquivos antigos para simular testes posteriores.

A cópia publicável do terminal Kubernetes foi derivada do registro local original,
preservado no workspace. Apenas BOM, finais de linha e espaços ao fim das linhas
foram normalizados; estados, eventos e resultados não foram alterados.

[README](../README.md) · [Status](../docs/STATUS-INFRA.md)
