# Guia para Fernando — outra conta e repositório original

O procedimento completo está em
[Reprodução em outra conta AWS e configuração do GitHub Actions](../GUIA-EXECUCAO.md#reprodução-em-outra-conta-aws-e-configuração-do-github-actions).

1. Iniciar Lab e configurar três credenciais temporárias fora do Git.
2. Identificar a própria conta, região, VPC/subnets, Key Pair e CIDR SSH.
3. Preparar backend; manter homolog/terraform.tfstate separado de
   production/terraform.tfstate. Não copiar/adotar state de Felipe.
4. Configurar os quatro Environments e secrets/variables do guia.
5. No original, configurar INFRA_DEPLOY_REPOSITORY exatamente como
   FernandoGreco/techChallengePosTech-k8s-infra. Sem isso, CD é bloqueado.
6. Manter PRODUCTION_CAPACITY_APPROVED ausente/false até decidir capacidade e
   isolamento. Novo state pode propor outro par de EC2.
7. Proteger homolog/main e exigir aprovação humana em homolog-apply/production-apply.
8. Após publicação autorizada, demonstrar CI e Plan; revisar antes de aprovar Apply.
9. Separar provisionamento, join, validação Kubernetes e monitoramento. Os scripts
   locais deploy.sh/destroy.sh atendem somente homolog.
10. Planejar limpeza por ambiente, com aprovação explícita, após salvar evidências.

Não reutilizar chave, known_hosts ou tokens de Felipe. Os helpers/values de
observabilidade têm endpoints/nome de cluster do laboratório: revisar a stack
de destino antes de reprodução autorizada. Não duplicar releases Grafana.

Nenhuma alteração foi realizada no repositório original ou no GitHub nesta etapa.
Apoios pessoais da gravação não são procedimentos universais.
