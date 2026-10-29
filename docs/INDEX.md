# Documentação — Fase 3

## Operação

- [README](../README.md): apresentação e componentes.
- [Comece aqui](../COMECE-AQUI.md): início rápido.
- [Guia de execução](../GUIA-EXECUCAO.md): validação, acesso e limpeza autorizada.
- [Reprodução em outra conta AWS e configuração do GitHub Actions](../GUIA-EXECUCAO.md#reprodução-em-outra-conta-aws-e-configuração-do-github-actions).
- [CI/CD homolog/main](CICD-HOMOLOG.md).
- [CI/CD validado e checklist FIAP](CI-CD.md).
- [Bootstrap de produção pós-Apply](BOOTSTRAP-PRODUCAO.md): join, TLS e teste HPA isolado.

## Arquitetura e decisões

- [Arquitetura da infraestrutura](ARQUITETURA-INFRA.md).
- [ADR-001: observabilidade](ADR-001-observabilidade.md).
- [ADR-002: ambientes e aprovação de Apply](ADR-002-CICD-AMBIENTES.md).
- [Rastreabilidade dos requisitos](REQUISITOS-FASE-3.md).

## Observabilidade e evidências

- [Fechamento de homologação](EVIDENCIAS-HOMOLOG.md): Plan/Apply e Kubernetes reconsultado.
- [Fechamento de produção](EVIDENCIAS-PRODUCAO.md): Apply, AWS, dois nós Ready, TLS e HPA real.
- [Grafana Cloud Lightweight](../observability/PLANO-GRAFANA.md).
- [Reprodução e validação Grafana](../observability/VERIFICAR-GRAFANA-CLOUD.md).
- [Índice de evidências](../evidencias/INDEX.md).
- [CI/CD](../evidencias/CI-CD.md).
- [HPA da aplicação](../evidencias/HPA-APLICACAO.md).

Os registros de coleta identificam sua data e origem. Não representam consultas
ao vivo ou comprovam funcionalidades além do alcance descrito.
