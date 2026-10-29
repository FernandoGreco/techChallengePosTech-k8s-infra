# Grafana Cloud — reprodução e validação

A instalação do laboratório foi executada em 27/10/2026. Release grafana-cloud,
namespace grafana-monitoring, cluster kubernetes-admin-kubernetes.
[Plano efetivo](PLANO-GRAFANA.md) · [Evidências](../evidencias/INDEX.md).

## Configuração efetiva

Valores em grafana-lightweight.values.yaml: métricas, logs e eventos explícitos;
Fleet, Beyla, profiling e OpenCost desabilitados. Seis Pods permanentes. Metrics
Server é preservado para HPA e kubectl top. Não instalar outro Grafana/Prometheus/
Loki Server ou repetir o assistente no mesmo cluster.

## Reprodução autorizada em outro ambiente

1. Confirmar conta, contexto, nós, capacidade e ausência de release concorrente.
2. Conferir endpoints/stack/nome do cluster do destino. Os values e o helper
   grafana-private.ps1 incluem referências do laboratório; não presumir que
   funcionam universalmente em outra stack.
3. Obter comando privado do assistente Grafana, fora do Git, somente como fonte
   de configuração. **Não executar diretamente esse comando** neste procedimento.
4. Revisar a compatibilidade dos campos com o helper. Criar namespace e Secret
   somente com autorização. O helper cria, não sobrescreve, Secret existente.
5. Informar explicitamente ControlPlane atual e caminho privado no Windows:

```powershell
./observability/criar-credenciais.ps1 -SshKeyPath "C:\caminho\privado\labsuser.pem" -ControlPlane "<IP_ATUAL_VERIFICADO>"
```

6. Copiar instalar-monitoramento.sh, grafana-rbac.yaml e
   grafana-lightweight.values.yaml para uma mesma pasta no Control Plane.
7. Somente após autorização, executar bash instalar-monitoramento.sh nessa pasta.
   O script instala/verifica Helm, aplica RBAC e faz upgrade/install. É mutante.
8. Executar bash verificar-coleta.sh nessa pasta para saúde/consumo.
9. No Windows, validar-cloud.ps1 faz consultas e saída sanitizada. Ele depende
   do arquivo privado e do helper; não fornece automaticamente logs:read.

Não colocar tokens em values, argumentos Helm, respostas ou arquivos versionados.
Não aceitar host SSH desconhecido. Arquivos privados no TEMP não são
armazenamento permanente confiável; revisar permissões, retenção e descarte.

## Validação no destino

Métricas: dashboard Kubernetes Monitoring com CPU/memória e amostras recentes.
Loki, últimos 15 minutos:

```logql
{cluster="kubernetes-admin-kubernetes",namespace="oficina-tc3",container="api"}
{cluster="kubernetes-admin-kubernetes",job="integrations/kubernetes/eventhandler"}
```

Logs/eventos foram confirmados manualmente; consultas API históricas com 401
indicam falta de scope de leitura, sem provar falha de escrita. Não alterar esses
resultados para simular sucesso automatizado. Alertas precisam de prova própria.
Traces, latência por rota e dashboards de negócio não foram comprovados por esses
testes de infraestrutura.

[README](../README.md) · [Guia](../GUIA-EXECUCAO.md)
