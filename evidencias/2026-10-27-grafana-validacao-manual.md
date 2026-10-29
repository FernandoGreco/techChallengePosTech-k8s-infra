# Confirmação manual Grafana Cloud

Registrada em 27/10/2026, conforme confirmação explícita do responsável pelo
projeto nesta conversa. Não é uma consulta automatizada nem captura de tela.

O usuário confirmou no Loki:

- Logs reais dos pods Kubernetes.
- 74 eventos com o filtro job=integrations/kubernetes/eventhandler.
- Eventos Started e Created do pod tc3-observability-check.

Conclusão: leitura de logs e eventos no destino validada manualmente. Com a
validação automática anterior de CPU/memória de nós e pods, os três sinais
solicitados estão validados.

O token de instalação continua sem logs:read. Os relatórios anteriores com
HTTP 401 e logs_and_events_read_verified=false são resultados históricos da
API com esse token; não foram alterados para simular sucesso automatizado.

Capturas do portal podem ser acrescentadas para o vídeo/entrega; nenhuma
captura foi fornecida nesta etapa. Nenhuma credencial foi registrada.
