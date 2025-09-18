
// Key Vault module for storing Docker Hub credentials and other secrets
param location string 
param keyVaultName string
param tenantId string = subscription().tenantId
param enabledForDeployment bool = false
param enabledForDiskEncryption bool = false
param enabledForTemplateDeployment bool = false
param enableSoftDelete bool = true
param softDeleteRetentionInDays int = 7
param enablePurgeProtection bool = true
param skuName string = 'standard'

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

@description('OpenCTI FQDN without HTTP/HTTPS.')
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

@description('SOCRadar username for TAXII2 connector authentication.')
@secure()
param socradarUsername string

@description('SOCRadar password for TAXII2 connector authentication.')
@secure()
param socradarPassword string


// Note: Certificate will be stored as passwordless PFX from pipeline

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: skuName
    }
    enabledForDeployment: enabledForDeployment
    enabledForDiskEncryption: enabledForDiskEncryption
    enabledForTemplateDeployment: enabledForTemplateDeployment
    enableSoftDelete: enableSoftDelete
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enablePurgeProtection: enablePurgeProtection
    enableRbacAuthorization: true // Use RBAC instead of access policies
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
  }
}
// Store MinIO credentials in Key Vault
resource minioRootUserSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'minio-root-user'
  properties: {
    value: minioRootUser
    contentType: 'MinIO root user'
    attributes: {
      enabled: true
    }
  }
}

resource minioRootPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'minio-root-password'
  properties: {
    value: minioRootPassword
    contentType: 'MinIO root password'
    attributes: {
      enabled: true
    }
  }
}

resource rabbitmqUserSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'rabbitmq-user'
  properties: {
    value: rabbitmqUser
    contentType: 'RabbitMQ user'
    attributes: {
      enabled: true
    }
  }
}

resource rabbitmqPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'rabbitmq-password'
  properties: {
    value: rabbitmqPassword
    contentType: 'RabbitMQ password'
    attributes: {
      enabled: true
    }
  }
}

resource openctiBaseUrlSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'opencti-base-url'
  properties: {
    value: 'https://${openctiBaseUrl}'
    contentType: 'OpenCTI base URL'
    attributes: {
      enabled: true
    }
  }
}

resource openctiAdminEmailSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'opencti-admin-email'
  properties: {
    value: openctiAdminEmail
    contentType: 'OpenCTI admin email'
    attributes: {
      enabled: true
    }
  }
}

resource openctiAdminPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'opencti-admin-password'
  properties: {
    value: openctiAdminPassword
    contentType: 'OpenCTI admin password'
    attributes: {
      enabled: true
    }
  }
}

resource openctiAdminTokenSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'opencti-admin-token'
  properties: {
    value: openctiAdminToken
    contentType: 'OpenCTI admin token'
    attributes: {
      enabled: true
    }
  }
}

resource openctiHealthcheckAccessKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'opencti-healthcheck-access-key'
  properties: {
    value: openctiHealthcheckAccessKey
    contentType: 'OpenCTI healthcheck access key'
    attributes: {
      enabled: true
    }
  }
}

resource redisPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'redis-password'
  properties: {
    value: redisPassword
    contentType: 'Redis password'
    attributes: {
      enabled: true
    }
  }
}

resource smtpHostnameSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'smtp-hostname'
  properties: {
    value: smtpHostname
    contentType: 'SMTP hostname'
    attributes: {
      enabled: true
    }
  }
}

// Store SAML certificate data as secret for SAML SSO authentication
resource samlCertificateSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'saml-certificate-data'
  properties: {
    value: samlCertData
    contentType: 'SAML certificate data (base64)'
    attributes: {
      enabled: true
    }
  }
}

// Store SOCRadar credentials for TAXII2 connector
resource socradarUsernameSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'socradar-username'
  properties: {
    value: socradarUsername
    contentType: 'SOCRadar username for TAXII2 connector'
    attributes: {
      enabled: true
    }
  }
}

resource socradarPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'socradar-password'
  properties: {
    value: socradarPassword
    contentType: 'SOCRadar password for TAXII2 connector'
    attributes: {
      enabled: true
    }
  }
}


// Outputs
output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
