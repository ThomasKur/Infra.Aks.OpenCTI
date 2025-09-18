param location string = resourceGroup().location
@maxLength(8)
@minLength(3)
@description('The name of the application. This will be used to generate unique names for resources.')
param appName string = 'opencti'

@maxLength(3)
@minLength(3)
param appVersion string = '001'

@description('Enable auto-scaling for AKS node pools. Default is true.')
param enableAutoScaling bool = true

@description('Minimum number of nodes in the AKS node pools when auto-scaling is enabled.')
param minNodeCount int = 1

@description('Maximum number of nodes in the AKS node pools when auto-scaling is enabled.')
param maxNodeCount int = 10

@description('The name of the Log Analytics workspace.')
@maxLength(63)
param logAnalyticsWorkspaceName string = 'log-${appName}-${appVersion}'

@description('Retention period in days for Log Analytics workspace.')
param logAnalyticsRetentionInDays int = 30

@description('MinIO root user for object storage.')
@secure()
param minioRootUser string

@description('MinIO root password for object storage.')
@secure()
param minioRootPassword string

@description('RabbitMQ user for message broker.')
@secure()
param rabbitmqUser string

@description('RabbitMQ password for message broker.')
@secure()
param rabbitmqPassword string

@description('OpenCTI base FQDN without HTTP/HTTPS')
@secure()
param openctiBaseUrl string

@description('OpenCTI admin email.')
@secure()
param openctiAdminEmail string

@description('OpenCTI admin password.')
@secure()
param openctiAdminPassword string

@description('OpenCTI admin token.')
@secure()
param openctiAdminToken string

@description('OpenCTI healthcheck access key.')
@secure()
param openctiHealthcheckAccessKey string

@description('Redis password.')
@secure()
param redisPassword string

@description('SMTP hostname.')
@secure()
param smtpHostname string

@description('SAML certificate data (base64 encoded) for SAML SSO authentication.')
@secure()
param samlCertData string

param entraIdInfraAdminGroupObjectId string 

@description('SOCRadar username for TAXII2 connector authentication.')
@secure()
param socradarUsername string

@description('SOCRadar password for TAXII2 connector authentication.')
@secure()
param socradarPassword string


var keyVaultName = take('kv-${appName}-${appVersion}-${uniqueString(resourceGroup().id)}', 24)





// Key Vault for storing Docker Hub credentials and other secrets
module keyVault 'modules/keyVault.bicep' = {
  name: 'keyVaultDeployment'
  params: {
    location: location
    keyVaultName: keyVaultName
    minioRootUser: minioRootUser
    minioRootPassword: minioRootPassword
    rabbitmqUser: rabbitmqUser
    rabbitmqPassword: rabbitmqPassword
    openctiBaseUrl: toLower(openctiBaseUrl)
    openctiAdminEmail: openctiAdminEmail
    openctiAdminPassword: openctiAdminPassword
    openctiAdminToken: openctiAdminToken
    openctiHealthcheckAccessKey: openctiHealthcheckAccessKey
    redisPassword: redisPassword
    smtpHostname: smtpHostname
    samlCertData: samlCertData
    socradarUsername: socradarUsername
    socradarPassword: socradarPassword
  }
}

resource keyVaultExisting 'Microsoft.KeyVault/vaults@2024-11-01' existing = {
  name: keyVaultName
  scope: resourceGroup()
  dependsOn: [
    keyVault
  ]
}

// Grant Infra group Certificate Officer and Secret Officer role on Keyvault
resource infraAdminGroupKeyVaultSecretOfficer 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVaultExisting.id, 'b24988ac-6180-42a0-ab88-20f7382dd24c', entraIdInfraAdminGroupObjectId)
  scope: keyVaultExisting
  properties: {
    principalId: entraIdInfraAdminGroupObjectId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Key Vault Secrets Officer
    principalType: 'Group'
  }
}
resource infraAdminGroupKeyVaultCertificateOfficer 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVaultExisting.id, 'db79e9a7-68ee-4b58-9aeb-b90e7c24fcba', entraIdInfraAdminGroupObjectId)
  scope: keyVaultExisting
  properties: {
    principalId: entraIdInfraAdminGroupObjectId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'db79e9a7-68ee-4b58-9aeb-b90e7c24fcba') // Key Vault Certificates Officer
    principalType: 'Group'
  }
}

