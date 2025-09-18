# OpenCTI Azure Deployment on Existing AKS

[![Deploy Infrastructure](https://github.com/ThomasKur/Infra.Aks.OpenCTI/actions/workflows/0_infra-deploy.yaml/badge.svg)](https://github.com/ThomasKur/Infra.Aks.OpenCTI/actions/workflows/0_infra-deploy.yaml)

This project provides a comprehensive enterprise-grade deployment of [OpenCTI](https://www.opencti.io/) (Open Cyber Threat Intelligence Platform) on Microsoft Azure using an existing Azure Kubernetes Service (AKS) cluster. The deployment uses Infrastructure as Code (IaC) with Bicep templates and automated GitHub Actions workflows.

## 🏗️ Architecture Overview

This deployment leverages your existing AKS infrastructure and adds the following Azure services specifically for OpenCTI:

- **Azure Key Vault** - Secure secret and certificate management for OpenCTI credentials
- **Kubernetes Manifests** - Complete OpenCTI platform deployment with all required services
- **SAML SSO Integration** - Enterprise authentication via Azure Entra ID
- **Threat Intelligence Connectors** - Pre-configured connectors including SOCRadar TAXII2

### Prerequisites

Your existing Azure infrastructure should include:
- **Azure Kubernetes Service (AKS)** - Running cluster with Key Vault Secrets Provider addon enabled
- **Azure Container Registry (ACR)** - For container image storage (optional if using public images)
- **Azure Virtual Network** - Network connectivity for AKS cluster
- **Ingress Controller** - For external access to OpenCTI platform

## 📋 Features

### 🔐 Security
- **Azure Key Vault Integration** - All OpenCTI secrets managed securely in Azure Key Vault
- **AKS Key Vault Secrets Provider** - Seamless secret injection into Kubernetes pods
- **SAML SSO Support** - Enterprise single sign-on with Azure Entra ID
- **RBAC Integration** - Role-based access control for infrastructure management
- **Managed Identity Authentication** - Secure service-to-service authentication

### 🚀 Production Ready
- **Existing AKS Integration** - Deploys to your established Kubernetes infrastructure
- **Container Orchestration** - Full Kubernetes deployment with proper resource limits
- **High Availability** - Multi-pod deployments with health checks
- **Persistent Storage** - MinIO object storage and Redis caching
- **Message Queuing** - RabbitMQ for reliable message processing

### 🔄 Automation & CI/CD
- **GitHub Actions Workflows** - Automated infrastructure and application deployment
- **Infrastructure as Code** - Bicep templates for Key Vault and secret management
- **Variable Substitution** - Dynamic configuration based on environment variables
- **Credential Management** - Secure handling of all secrets via Azure Key Vault

### 🔌 OpenCTI Connectors
Pre-configured connectors for comprehensive threat intelligence:
- **TAXII2 SOCRadar Connector** - Automated threat intelligence feed integration
- **Document Analysis Connector** - PDF, HTML, and text document processing
- **File Import/Export Connectors** - STIX2, CSV, and TXT format support
- **Worker Services** - Background processing for data ingestion and analysis

## 📁 Project Structure

```
.
├── .github/workflows/          # GitHub Actions workflows
│   └── 0_infra-deploy.yaml    # Complete infrastructure and application deployment
├── main.bicep                 # Main Bicep template for Key Vault and secrets
├── modules/                   # Bicep modules
│   └── keyVault.bicep        # Key Vault creation and secret management
├── k8s/                      # Kubernetes manifests
│   ├── services/             # Supporting services
│   │   ├── elasticsearch-deployment.yaml    # Elasticsearch for data indexing
│   │   ├── minio-service.yaml              # MinIO object storage
│   │   ├── rabbitmq-deployment.yaml        # RabbitMQ message broker
│   │   ├── redis-deployment.yaml           # Redis caching service
│   │   └── secretproviderclass.yaml        # Key Vault secret integration
│   └── opencti/              # OpenCTI platform and connectors
│       ├── ingress.yaml                     # Ingress configuration
│       ├── platform-deployment.yaml        # Main OpenCTI platform
│       ├── worker-deployment.yaml          # OpenCTI worker processes
│       ├── connector-analysis-deployment.yaml
│       ├── connector-import-document-deployment.yaml
│       ├── connector-export-file-csv-deployment.yaml
│       ├── connector-export-file-stix-deployment.yaml
│       ├── connector-export-file-txt-deployment.yaml
│       ├── connector-import-file-stix-deployment.yaml
│       └── connector-taxii-socradar-bv-collection-01.yaml
├── Setup.ps1                 # Automated Azure setup and GitHub integration script
└── README.md                 # This documentation
```

## 🚀 Quick Start

### Prerequisites

- **Existing Azure Kubernetes Service (AKS) cluster** with:
  - Key Vault Secrets Provider addon enabled
  - Ingress controller configured (e.g., nginx-ingress, Application Gateway)
  - Container Registry access configured (if using private registry)
- **Azure Subscription** with Contributor access to AKS resource group
- **Azure CLI** or **Azure PowerShell** installed
- **Git** for repository management
- **PowerShell 7+** (for setup script)

### 1. Repository Setup

```bash
git clone https://github.com/ThomasKur/Infra.Aks.OpenCTI.git
cd Infra.Aks.OpenCTI
```

### 2. Automated Setup

Run the automated setup script to configure Azure resources and GitHub integration:

```powershell
.\Setup.ps1 -AdminUpn "admin@yourdomain.com" -EnvironmentName "production" -GithubOrga "YourGitHubOrg" -AksResourceGroup "your-aks-rg-name"
```

This script will:
- Create user-assigned managed identity for GitHub Actions
- Set up Azure Entra ID security groups for OpenCTI access
- Configure SAML SSO enterprise application
- Set up GitHub federated identity credentials
- Configure AKS Key Vault Secrets Provider permissions
- Display all required GitHub secrets and variables

### 3. Configure GitHub Environment

After running the setup script, configure your GitHub repository with the displayed secrets and variables:

#### Required Secrets
- `AZURE_CLIENT_ID` - Managed identity client ID (provided by setup script)
- `AZURE_TENANT_ID` - Azure tenant ID (provided by setup script)
- `AZURE_SUBSCRIPTION_ID` - Azure subscription ID (provided by setup script)
- `SAML_CERT_DATA` - SAML certificate data (provided by setup script)
- `MINIO_ROOT_USER` - MinIO storage username (set your own)
- `MINIO_ROOT_PASSWORD` - MinIO storage password (set your own)
- `RABBITMQ_USER` - RabbitMQ username (set your own)
- `RABBITMQ_PASSWORD` - RabbitMQ password (set your own)
- `OPENCTI_ADMIN_EMAIL` - OpenCTI administrator email
- `OPENCTI_ADMIN_PASSWORD` - OpenCTI administrator password
- `OPENCTI_ADMIN_TOKEN` - OpenCTI API token (UUID format)
- `OPENCTI_HEALTHCHECK_ACCESS_KEY` - Health check access key
- `REDIS_PASSWORD` - Redis password (set your own)
- `SMTP_HOSTNAME` - SMTP server for notifications
- `SOCRADAR_USERNAME` - SOCRadar TAXII username (optional)
- `SOCRADAR_PASSWORD` - SOCRadar TAXII password (optional)

#### Required Variables
- `APPNAME` - Application name (provided by setup script)
- `APPVERSION` - Version identifier (provided by setup script)
- `ENTRA_ID_INFRA_ADMIN_GROUP_ID` - Azure AD group ID (provided by setup script)
- `AKS_RESOURCE_GROUP` - AKS cluster resource group name
- `AKS_CLUSTER_NAME` - AKS cluster name
- `ACR_NAME` - Azure Container Registry name (if using private registry)
- `OPENCTI_BASE_URL` - Public FQDN for OpenCTI (without https://)
- `SAML_CALLBACK_URL` - SAML callback URL (provided by setup script)
- `SAML_ENTRY_POINT` - SAML entry point (provided by setup script)
- `SAML_ISSUER` - SAML issuer (provided by setup script)

### 4. Deploy OpenCTI

Trigger the complete deployment workflow:

1. Go to **Actions** tab in your GitHub repository
2. Select **"0 Deploy Infra"** workflow
3. Click **"Run workflow"** and select your environment
4. The workflow will:
   - Deploy Key Vault and store all secrets
   - Deploy all Kubernetes services (Elasticsearch, MinIO, RabbitMQ, Redis)
   - Deploy OpenCTI platform and worker processes
   - Deploy all configured connectors
   - Configure ingress for external access

## 🔧 Configuration

### AKS Prerequisites

Before deploying, ensure your AKS cluster meets these requirements:

```bash
# Enable Key Vault Secrets Provider addon
az aks addon enable --addon azure-keyvault-secrets-provider --name YOUR_AKS_CLUSTER --resource-group YOUR_AKS_RG

# Verify addon is enabled
az aks addon show --addon azure-keyvault-secrets-provider --name YOUR_AKS_CLUSTER --resource-group YOUR_AKS_RG
```

### SAML SSO Configuration

The deployment automatically configures SAML SSO with Azure Entra ID. The setup script will provide:

```yaml
SAML_ISSUER: "api://your-app-id"
SAML_ENTRY_POINT: "https://login.microsoftonline.com/your-tenant-id/saml2"
SAML_CALLBACK_URL: "https://your-opencti-domain.com/auth/saml/callback"
```

### SOCRadar TAXII Integration

The deployment includes a pre-configured SOCRadar TAXII2 connector:

- Automatically pulls threat intelligence from SOCRadar Business collections
- Updates every 12 hours by default
- Credentials securely managed via Azure Key Vault
- Configurable collection IDs in the connector YAML

### Ingress Configuration

Update the ingress configuration in `k8s/opencti/ingress.yaml` to match your ingress controller:

```yaml
# For NGINX Ingress Controller
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
```

### Custom Connectors

To add custom connectors:

1. Create a new deployment YAML in `k8s/opencti/`
2. Add the connector to the GitHub Actions workflow
3. Configure required secrets in Azure Key Vault
4. Update the `secretproviderclass.yaml` if new secrets are needed

## 🔍 Monitoring & Troubleshooting

### Accessing OpenCTI

After deployment, access OpenCTI at your configured domain:
- URL: `https://your-opencti-base-url`
- Username: As configured in `OPENCTI_ADMIN_EMAIL`
- Password: As configured in `OPENCTI_ADMIN_PASSWORD`

### Monitoring

- **AKS Insights** - Container and pod monitoring for OpenCTI components
- **Azure Key Vault** - Secret access monitoring and audit logs
- **Kubernetes Events** - Pod scheduling and health events
- **Application Logs** - OpenCTI platform and connector logs

### Common Issues

1. **Secret Provider Issues**: 
   ```bash
   # Check if secrets are mounted correctly
   kubectl describe secretproviderclass opencti-azure-kv -n opencti
   kubectl get events -n opencti --field-selector reason=SecretProviderClassReady
   ```

2. **Key Vault Access**: Verify AKS Key Vault Secrets Provider has proper permissions
   ```bash
   # Check the managed identity permissions
   az role assignment list --assignee <aks-secrets-provider-client-id> --scope /subscriptions/<sub-id>/resourceGroups/<rg-name>
   ```

3. **Pod Startup Issues**: Check if all required secrets are available
   ```bash
   # Check pod events for secret mounting issues
   kubectl describe pod <pod-name> -n opencti
   ```

4. **Ingress Issues**: Verify ingress controller and DNS configuration
   ```bash
   # Check ingress status
   kubectl get ingress -n opencti
   kubectl describe ingress opencti-ingress -n opencti
   ```

### Logs and Diagnostics

```bash
# Check OpenCTI namespace status
kubectl get all -n opencti

# View OpenCTI platform logs
kubectl logs -f deployment/opencti-platform -n opencti

# View worker logs
kubectl logs -f deployment/opencti-worker -n opencti

# View connector logs
kubectl logs -f deployment/connector-taxii-socradar-bv-collection-01 -n opencti

# Check secret provider class status
kubectl get secretproviderclass -n opencti
kubectl describe secretproviderclass opencti-azure-kv -n opencti

# Check if secrets are properly mounted
kubectl exec -it deployment/opencti-platform -n opencti -- ls -la /mnt/secrets-store/
```

### Health Checks

```bash
# Check OpenCTI platform health
kubectl get pods -n opencti -l app=opencti-platform

# Check all connectors status
kubectl get pods -n opencti -l component=connector

# Check supporting services
kubectl get pods -n opencti -l component=service
```

## 🛡️ Security Considerations

- **Azure Key Vault Integration**: All sensitive data stored securely in Azure Key Vault
- **AKS Secrets Provider**: Secrets injected securely into pods without storing in Kubernetes etcd
- **Managed Identity Authentication**: No service principal secrets stored in GitHub or Kubernetes
- **RBAC Controls**: Role-based access control for both Azure resources and Kubernetes
- **SAML SSO**: Enterprise authentication with Azure Entra ID integration
- **Network Security**: Leverages existing AKS network security policies and ingress controls

## 📚 Additional Documentation

- [OpenCTI Official Documentation](https://docs.opencti.io/) - Complete OpenCTI platform documentation
- [Azure AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/) - AKS best practices and configuration
- [Key Vault Secrets Provider](https://docs.microsoft.com/en-us/azure/aks/csi-secrets-store-driver) - AKS Key Vault integration guide
- [Azure Entra ID SAML](https://docs.microsoft.com/en-us/azure/active-directory/saas-apps/) - SAML SSO configuration

## 🤝 Contributing

1. Fork this repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes and test thoroughly
4. Update documentation as needed
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For issues and questions:

1. Check the troubleshooting section above
2. Review existing [GitHub Issues](https://github.com/ThomasKur/Infra.Aks.OpenCTI/issues)
3. Create a new issue with:
   - Clear description of the problem
   - Steps to reproduce
   - Relevant logs and error messages
   - Environment details (AKS version, ingress controller, etc.)

## 🏷️ Version Information

Current version supports:
- **OpenCTI**: Latest stable (6.x)
- **Kubernetes**: 1.28+ (AKS supported versions)
- **Azure Key Vault**: Current API version
- **GitHub Actions**: Latest workflow syntax