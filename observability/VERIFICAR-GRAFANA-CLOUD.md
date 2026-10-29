# Grafana Cloud — reprodução e validação

[Configuração](PLANO-GRAFANA.md) · [Evidências](../evidencias/INDEX.md).

## Configuração efetiva

Release grafana-cloud, namespace grafana-monitoring, cluster
kubernetes-admin-kubernetes. Métricas, logs e eventos são explícitos no values.
Fleet e coletores opcionais não utilizados estão desabilitados.
Metrics Server é preservado para HPA/top. Não duplicar o release ou instalar outro
Grafana/Prometheus/Loki Server.

## Reprodução autorizada

1. Confirmar conta, contexto, nós, capacidade e ausência de release concorrente.
2. Conferir stack/endpoints/nome de cluster do destino. Values e
   grafana-private.ps1 incluem referências do ambiente demonstrado; não presumir
   compatibilidade universal com outra stack.
3. Obter configuração do assistente Grafana por arquivo privado fora do Git.
   Utilizá-la como fonte de parâmetros, sem executar diretamente seu comando.
4. Revisar campos e destinos antes de criar namespace/Secret, com autorização.
5. Definir SSH_PRIVATE_KEY_PATH e CONTROL_PLANE_HOST no processo, sem registrar
   credenciais. No PowerShell:

```powershell
./observability/criar-credenciais.ps1 -SshKeyPath $env:SSH_PRIVATE_KEY_PATH -ControlPlane $env:CONTROL_PLANE_HOST
```

6. Copiar instalar-monitoramento.sh, grafana-rbac.yaml e
   grafana-lightweight.values.yaml para uma pasta no Control Plane.
7. Com autorização, executar bash instalar-monitoramento.sh nessa pasta.
   A instalação é mutante e aguarda o release/agentes.
8. Consultar saúde/consumo com bash verificar-coleta.sh nessa pasta.
9. Consultar métricas Cloud com validar-cloud.ps1 no ambiente configurado.
   O helper depende do arquivo privado e não concede automaticamente logs:read.

O helper de credenciais cria o Secret e recusa sobrescrever um existente.
Não colocar tokens em values, argumentos Helm, histórico ou arquivos versionados.
Validar a identidade SSH antes de usar os helpers.
Arquivos privados precisam de acesso restrito e descarte controlado após uso.

## Confirmação no destino

Dashboard Kubernetes Monitoring: CPU/memória, Pods Ready e restarts.
Loki, últimos 15 minutos, com labels do ambiente:

```logql
{cluster="kubernetes-admin-kubernetes",namespace="oficina-tc3",container="api"}
{cluster="kubernetes-admin-kubernetes",job="integrations/kubernetes/eventhandler"}
```

Resposta 401 por ausência de scope de leitura não prova falha de envio.
Manter a origem manual ou automatizada identificada e não substituir falhas
registradas por resultados fictícios. Alertas e traces precisam de provas próprias.

[Guia de execução](../GUIA-EXECUCAO.md) · [README](../README.md)
