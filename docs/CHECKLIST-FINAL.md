# Checklist de entrega e operação

## Evidências

- [ ] Conferir Lab ativo/tempo e credenciais temporárias antes de leituras remotas.
- [ ] Confirmar conta/região, EC2, contexto, dois nós Ready e Metrics Server.
- [ ] Conferir API/PostgreSQL e Job schema sem seed.
- [ ] Separar HPA sintético 1→4→1 do HPA API 1→2.
- [ ] Vincular registro dos 9.986 HTTP/zero erros à origem, sem alegar benchmark externo.
- [ ] Conferir métricas/logs/eventos e indicar confirmação manual/API.
- [ ] Vincular run/commit do Apply final informado, sem reaproveitar Plan antigo.
- [ ] Revisar capturas, segredos e dados pessoais antes de publicar.

## GitHub

- [ ] Validar CI remoto autorizado do novo commit.
- [ ] Configurar produção e aprovação, preservando homolog.
- [ ] Separar state e decidir capacidade antes de habilitar produção.
- [ ] Adaptar autorização do repositório para Fernando.
- [ ] Não afirmar validação remota de produção sem execução/evidência.

## Grupo

- [ ] Consolidar [requisitos](REQUISITOS-FASE-3.md), quatro repos e acesso soat-architecture.
- [ ] Consolidar banco gerenciado, CPF/Lambda/Gateway e deploy da aplicação.
- [ ] Consolidar traces, correlação JSON, latência e dashboards/alertas de negócio.
- [ ] Finalizar diagramas/RFCs/ADRs e modelagem/justificativa do banco.
- [ ] Entregar PDF único com links e vídeo até 15 minutos.

## Limpeza posterior — aprovação separada

- [ ] Salvar evidências; revisar conta, state e dependências.
- [ ] Obter autorização explícita, sem limpar durante a demonstração.
- [ ] Preservar state/bucket e recursos compartilhados.
