# Evidência de logs e eventos — Grafana Cloud

Data da confirmação: 27/10/2026.
Origem: verificação manual no portal Loki pelo responsável.
Não é consulta automatizada nem captura de tela.

## Observações confirmadas

- Logs reais dos Pods Kubernetes visíveis no destino.
- 74 eventos no filtro job=integrations/kubernetes/eventhandler.
- Eventos Created e Started do Pod tc3-observability-check.

A [consulta de métricas](2026-10-27-grafana-cloud-api.json) registra CPU/memória
de nós/Pods recebidas pelo Cloud. Logs/eventos possuem a confirmação manual acima.

As consultas automatizadas de leitura Loki retornaram 401 por falta de scope.
Esse resultado é preservado: não significa falha de envio e não foi substituído
por um sucesso fictício. Não há captura de tela associada neste catálogo.

Essas observações não comprovam traces, logs JSON correlacionados da aplicação
ou alertas de negócio.

[Configuração](../observability/PLANO-GRAFANA.md) · [Índice](INDEX.md)
