<#
.SYNOPSIS
    Sets up Azure infrastructure and GitHub integration for OpenCTI deployment.

.DESCRIPTION
    This script creates Azure resources including resource groups, managed identities, 
    Entra ID security groups, GitHub federated identity credentials, and Enterprise Application 
    with SAML SSO configuration for OpenCTI deployment.

.PARAMETER AdminUpn
    The UPN of the admin user to add to the infrastructure admin group.
    Default: "admin@example.onmicrosoft.com"

.PARAMETER Location
    The Azure region where resources will be deployed.
    Default: "westeurope"

.PARAMETER AppName
    The application name used as a prefix for resource names.
    Default: "opencti"

.PARAMETER AppVersion
    The application version used in resource names.
    Default: "001"

.PARAMETER RepoName
    The main GitHub repository name. This is used to connect the GitHub identity with the federated identity to grant access to the resource group.
    Default: "Infra.Aks.OpenCTI"

.PARAMETER GithubOrga
    The GitHub organization name. This is used to connect the GitHub identity with the federated identity to grant access to the resource group.
    Default: "example"

.PARAMETER EnvironmentName
    The GitHub environment name for federated identity credentials.
    Default: "example"

.PARAMETER AksResourceGroup
    The name of the resource group where the AKS cluster is located.
    Default: "rg-aks-001"

.EXAMPLE
    .\Setup.ps1
    Runs the script with default values.

.EXAMPLE
    .\Setup.ps1 -AppName "myopencti" -AppVersion "002" -Location "eastus"
    Runs the script with custom application name, version, and location.

.EXAMPLE
    .\Setup.ps1 -AdminUpn "admin@mycompany.com" -GithubOrga "MyOrg" -EnvironmentName "production"
    Runs the script with custom admin user, GitHub organization, and environment.

.NOTES
    Prerequisites:
    - Azure PowerShell module must be installed and connected (Connect-AzAccount)
    - Microsoft Graph PowerShell module must be installed and connected with appropriate scopes:
      Connect-MgGraph -Scopes "Application.ReadWrite.All","Directory.ReadWrite.All"
    - Appropriate permissions in Azure and Entra ID
#>

param(
    # Azure and Admin Configuration
    [Parameter(Mandatory = $false, HelpMessage = "Admin UPN for the environment")]
    [string]$AdminUpn = "admin@example.onmicrosoft.com",
    
    # Azure Information
    [Parameter(Mandatory = $false, HelpMessage = "Azure region where resources will be deployed")]
    [string]$Location = "westeurope",
    
    [Parameter(Mandatory = $false, HelpMessage = "Application name")]
    [string]$AppName = "opencti",
    
    [Parameter(Mandatory = $false, HelpMessage = "Application version")]
    [string]$AppVersion = "001",
    
    # GitHub Information
    [Parameter(Mandatory = $false, HelpMessage = "GitHub repository name")]
    [string]$RepoName = "Infra.Aks.OpenCTI",
    
    [Parameter(Mandatory = $false, HelpMessage = "GitHub organization name")]
    [string]$GithubOrga = "example",
    
    [Parameter(Mandatory = $false, HelpMessage = "GitHub environment name")]
    [string]$EnvironmentName = "example",

    [Parameter(Mandatory = $false, HelpMessage = "AKS Resource Group name")]
    [string]$AksResourceGroup = "rg-aks-001",
    
    # SAML Configuration
    [Parameter(Mandatory = $false, HelpMessage = "OpenCTI SAML callback URL")]
    [string]$SamlCallbackUrl = "https://opencti.kurcontoso.ch/auth/saml/callback",
    
    [Parameter(Mandatory = $false, HelpMessage = "OpenCTI SAML login URL")]
    [string]$SamlLoginUrl = "https://opencti.kurcontoso.ch/",
    
    [Parameter(Mandatory = $false, HelpMessage = "Notification email for certificate expiry")]
    [string]$NotificationEmail = "admin@example.onmicrosoft.com"
)

# --- Derived Variables ---
$rgName = "rg-$AppName-$AppVersion"
$miName = "id-$AppName-github-$AppVersion"
$grpNameInfraAdmin = "sg-$AppName-infraadmin"
$grpNameThreatIntel = "sg-$AppName-threatintel"
$grpNameAnalysts = "sg-$AppName-analysts"
$samlAppName = "$AppName-saml-$AppVersion"

# --- Module Installation Checks ---
Write-Host ""
Write-Host "📦 MODULE DEPENDENCY VERIFICATION" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "⏳ Checking required PowerShell modules..."

# Define required modules with their minimum versions
$requiredModules = @(
    @{ Name = "Az.Accounts"; MinVersion = "2.0.0"; Description = "Azure PowerShell authentication" },
    @{ Name = "Az.Resources"; MinVersion = "6.0.0"; Description = "Azure resource management" },
    @{ Name = "Az.ManagedServiceIdentity"; MinVersion = "1.0.0"; Description = "Managed identity operations" },
    @{ Name = "Az.Aks"; MinVersion = "4.0.0"; Description = "Azure Kubernetes Service management" },
    @{ Name = "Az.ContainerRegistry"; MinVersion = "2.0.0"; Description = "Azure Container Registry management" },
    @{ Name = "Microsoft.Graph.Authentication"; MinVersion = "2.0.0"; Description = "Microsoft Graph authentication" },
    @{ Name = "Microsoft.Graph.Applications"; MinVersion = "2.0.0"; Description = "Enterprise application management" },
    @{ Name = "Microsoft.Graph.Groups"; MinVersion = "2.0.0"; Description = "Group management operations" }
)

$missingModules = @()
$outdatedModules = @()

foreach ($module in $requiredModules) {
    Write-Host "🔍 Checking $($module.Name)..." -ForegroundColor Yellow
    
    try {
        $installedModule = Get-Module -Name $module.Name -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
        
        if ($installedModule) {
            if ($installedModule.Version -ge [Version]$module.MinVersion) {
                Write-Host "✅ $($module.Name) v$($installedModule.Version) - OK" -ForegroundColor Green
            } else {
                Write-Host "⚠️  $($module.Name) v$($installedModule.Version) - Outdated (minimum: $($module.MinVersion))" -ForegroundColor Yellow
                $outdatedModules += $module
            }
        } else {
            Write-Host "❌ $($module.Name) - Not installed" -ForegroundColor Red
            $missingModules += $module
        }
    } catch {
        Write-Host "❌ $($module.Name) - Error checking module: $($_.Exception.Message)" -ForegroundColor Red
        $missingModules += $module
    }
}

# Handle missing or outdated modules
if ($missingModules.Count -gt 0 -or $outdatedModules.Count -gt 0) {
    Write-Host ""
    Write-Host "⚠️  MODULE INSTALLATION REQUIRED" -ForegroundColor Yellow
    Write-Host "==================================================" -ForegroundColor Yellow
    
    if ($missingModules.Count -gt 0) {
        Write-Host "📦 Missing modules that need to be installed:" -ForegroundColor Red
        foreach ($module in $missingModules) {
            Write-Host "   • $($module.Name) (v$($module.MinVersion)+) - $($module.Description)" -ForegroundColor Red
        }
    }
    
    if ($outdatedModules.Count -gt 0) {
        Write-Host "⬆️  Outdated modules that should be updated:" -ForegroundColor Yellow
        foreach ($module in $outdatedModules) {
            Write-Host "   • $($module.Name) (minimum v$($module.MinVersion)) - $($module.Description)" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    Write-Host "💡 To install/update the required modules, run these commands:" -ForegroundColor Cyan
    Write-Host "   Install-Module -Name Az -Force -AllowClobber" -ForegroundColor White
    Write-Host "   Install-Module -Name Microsoft.Graph -Force -AllowClobber" -ForegroundColor White
    Write-Host ""
    Write-Host "   Or install specific modules individually:" -ForegroundColor Cyan
    
    $allModules = $missingModules + $outdatedModules | Sort-Object -Property Name -Unique
    foreach ($module in $allModules) {
        Write-Host "   Install-Module -Name $($module.Name) -MinimumVersion $($module.MinVersion) -Force -AllowClobber" -ForegroundColor White
    }
    
    Write-Host ""
    $response = Read-Host "Do you want to continue anyway? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Host "❌ Setup cancelled. Please install the required modules and run the script again." -ForegroundColor Red
        exit 1
    }
    Write-Host "⚠️  Continuing with potentially missing dependencies..." -ForegroundColor Yellow
} else {
    Write-Host "✅ All required modules are installed and up to date!" -ForegroundColor Green
}

Write-Host ""

# --- Authentication Checks ---
Write-Host ""
Write-Host "🔐 AUTHENTICATION VERIFICATION" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "⏳ Verifying authentication status..."

# Check Azure PowerShell authentication
try {
    $azContext = Get-AzContext
    if (-not $azContext -or -not $azContext.Account) {
        throw "Not authenticated to Azure"
    }
    Write-Host "✅ Azure PowerShell: Connected as $($azContext.Account.Id)" -ForegroundColor Green
} catch {
    Write-Host "❌ Azure PowerShell authentication failed" -ForegroundColor Red
    Write-Error "Please run 'Connect-AzAccount' first."
    throw "Azure PowerShell authentication required"
}

# Check Microsoft Graph PowerShell authentication
try {
    $mgContext = Get-MgContext
    if (-not $mgContext -or -not $mgContext.Account) {
        throw "Not authenticated to Microsoft Graph"
    }
    Write-Host "✅ Microsoft Graph: Connected as $($mgContext.Account)" -ForegroundColor Green
} catch {
    Write-Error "❌ Microsoft Graph authentication failed. Please run 'Connect-MgGraph' first."
    throw "Microsoft Graph authentication required"
}

# Verify both contexts use the same account/tenant
if ($azContext.Account.Id -ne $mgContext.Account -and $azContext.TenantId -ne $mgContext.TenantId) {
    Write-Host "⚠️  Azure and Microsoft Graph are authenticated with different accounts/tenants" -ForegroundColor Yellow
    Write-Host "   Azure: $($azContext.Account.Id) (Tenant: $($azContext.TenantId))" -ForegroundColor Yellow
    Write-Host "   Graph: $($mgContext.Account) (Tenant: $($mgContext.TenantId))" -ForegroundColor Yellow
    Write-Host "   This may cause issues. Consider using the same account for both." -ForegroundColor Yellow
}

Write-Host "✅ Authentication verification completed successfully" -ForegroundColor Green
Write-Host ""

# --- Azure Infrastructure Setup ---
Write-Host "�🚀 AZURE INFRASTRUCTURE SETUP" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "📝 Configuration: $AppName ($AppVersion) in $Location"
Write-Host ""

# --- Resource Group ---
Write-Host "📁 Creating Azure Resource Group..." -ForegroundColor Yellow
$rg = Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue
if (-not $rg) {
    Write-Host "⏳ Creating resource group: $rgName"
    $rg = New-AzResourceGroup -Name $rgName -Location $Location
    Write-Host "✅ Resource group created successfully" -ForegroundColor Green
} else {
    Write-Host "✅ Resource group already exists: $rgName" -ForegroundColor Green
}

# --- Managed Identity ---
Write-Host ""
Write-Host "🆔 Creating User-Assigned Managed Identity..." -ForegroundColor Yellow
$managedIdentity = Get-AzUserAssignedIdentity -Name $miName -ResourceGroupName $rgName -ErrorAction SilentlyContinue
if (-not $managedIdentity) {
    Write-Host "⏳ Creating managed identity: $miName"
    $managedIdentity = New-AzUserAssignedIdentity -Name $miName -ResourceGroupName $rgName -Location $Location
    Write-Host "✅ Managed identity created successfully" -ForegroundColor Green
} else {
    Write-Host "✅ Managed identity already exists: $miName" -ForegroundColor Green
}
Start-Sleep -Seconds 5

# --- Entra ID Security Group ---
Write-Host ""
Write-Host "👥 Creating Entra ID Security Group..." -ForegroundColor Yellow
$grp = Get-AzADGroup -DisplayName $grpNameInfraAdmin -ErrorAction SilentlyContinue
if (-not $grp) {
    Write-Host "⏳ Creating security group: $grpNameInfraAdmin"
    $grp = New-AzADGroup -DisplayName $grpNameInfraAdmin -MailNickname $grpNameInfraAdmin -Description "Infrastructure Admin"
    Write-Host "✅ Security group created successfully" -ForegroundColor Green
} else {
    Write-Host "✅ Security group already exists: $grpNameInfraAdmin" -ForegroundColor Green
}

# --- Threat Intel Security Group ---
Write-Host "" 
Write-Host "👥 Creating Threat Intel Security Group..." -ForegroundColor Yellow 
$grpThreatIntel = Get-AzADGroup -DisplayName $grpNameThreatIntel -ErrorAction SilentlyContinue 
if (-not $grpThreatIntel) { 
    Write-Host "⏳ Creating security group: $grpNameThreatIntel" 
    $grpThreatIntel = New-AzADGroup -DisplayName $grpNameThreatIntel -MailNickname $grpNameThreatIntel -Description "Threat Intelligence" 
    Write-Host "✅ Security group created successfully" -ForegroundColor Green 
} else { 
    Write-Host "✅ Security group already exists: $grpNameThreatIntel" -ForegroundColor Green 
}

# --- Analysts Security Group ---
Write-Host "" 
Write-Host "👥 Creating Analysts Security Group..." -ForegroundColor Yellow 
$grpAnalysts = Get-AzADGroup -DisplayName $grpNameAnalysts -ErrorAction SilentlyContinue 
if (-not $grpAnalysts) { 
    Write-Host "⏳ Creating security group: $grpNameAnalysts" 
    $grpAnalysts = New-AzADGroup -DisplayName $grpNameAnalysts -MailNickname $grpNameAnalysts -Description "Analysts" 
    Write-Host "✅ Security group created successfully" -ForegroundColor Green 
} else { 
    Write-Host "✅ Security group already exists: $grpNameAnalysts" -ForegroundColor Green 
}

# --- Add Managed Identity to Group ---
Write-Host ""
Write-Host "🔗 Configuring Group Memberships..." -ForegroundColor Yellow
try {
    Add-AzADGroupMember -MemberObjectId $managedIdentity.PrincipalId -TargetGroupObjectId $grp.Id -ErrorAction Stop
    Write-Host "✅ Managed identity added to security group" -ForegroundColor Green
} catch {
    Write-Host "ℹ️  Managed identity is already a member of the security group" -ForegroundColor Blue
}

# --- Add Admin User to Group ---
$adminUser = Get-AzADUser -Mail $AdminUpn -ErrorAction SilentlyContinue
if ($adminUser) {
    try {
        Add-AzADGroupMember -MemberObjectId $adminUser.Id -TargetGroupObjectId $grp.Id -ErrorAction Stop
        Write-Host "✅ Admin user added to security group" -ForegroundColor Green
    } catch {
        Write-Host "ℹ️  Admin user is already a member of the security group" -ForegroundColor Blue
    }
} else {
    Write-Host "⚠️  Admin user $AdminUpn not found in Azure AD" -ForegroundColor Yellow
}

# --- Enterprise Application Creation ---
Write-Host ""
Write-Host "🏢 ENTERPRISE APPLICATION SETUP" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "⏳ Setting up SAML SSO Enterprise Application..."

# Import Microsoft Graph Applications module
Import-Module Microsoft.Graph.Applications -ErrorAction SilentlyContinue

# Template ID for non-gallery applications
$applicationTemplateId = "8adf8e6e-67b2-4cf2-a259-e3dc5476c621"
Write-Host "📋 Using non-gallery application template: $applicationTemplateId"

# Check if application already exists
$existingApp = $null
$existingSP = $null

$existingApp = Get-MgApplication -Filter "DisplayName eq '$samlAppName'" -ErrorAction SilentlyContinue
$existingSP = Get-MgServicePrincipal -Filter "DisplayName eq '$samlAppName'" -ErrorAction SilentlyContinue

if ($existingApp -and $existingSP) {
    Write-Host "Enterprise Application '$samlAppName' already exists."
    $applicationId = $existingApp.Id
    $servicePrincipalId = $existingSP.Id
    
    # Update existing application with app ID as identifier URI if not already set
    if ($existingApp.IdentifierUris -notcontains $existingApp.AppId) {
        Write-Host "Updating existing application with App ID as identifier URI..."
        try {
            # Use api:// prefix format which is more commonly accepted
            $entityId = "api://$($existingApp.AppId)"
            $appParams = @{
                IdentifierUris = @($entityId)
            }
            Update-MgApplication -ApplicationId $applicationId -BodyParameter $appParams
            Write-Host "✅ Existing application updated with App ID as Entity ID: $entityId"
        } catch {
            Write-Warning "Could not update identifier URI automatically: $($_.Exception.Message)"
            Write-Host "Manual configuration required:"
            Write-Host "1. Go to Azure Portal > Entra ID > App registrations > $samlAppName"
            Write-Host "2. Go to 'Expose an API'"
            Write-Host "3. Set Application ID URI to: api://$($existingApp.AppId)"
            Write-Host "4. Or use the App ID directly: $($existingApp.AppId)"
        }
    } else {
        Write-Host "App ID is already set as identifier URI."
    }
    
    # Check and update Web configuration separately if needed
    if ($existingApp.Web.RedirectUris -notcontains $SamlCallbackUrl) {
        Write-Host "Updating SAML callback URLs..."
        try {
            $webParams = @{
                Web = @{
                    RedirectUris = @($SamlCallbackUrl)
                    LogoutUrl = $SamlCallbackUrl
                }
            }
            Update-MgApplication -ApplicationId $applicationId -BodyParameter $webParams
            Write-Host "✅ SAML callback URLs updated."
        } catch {
            Write-Warning "Could not update Web configuration: $($_.Exception.Message)"
            Write-Host "You may need to update the redirect URIs manually in the Azure Portal."
        }
    }
    
    # Configure groups claim for existing application
    Write-Host "Configuring SAML groups claim for existing application..."
    try {
        
        $appGroupParams = @{
            GroupMembershipClaims = "ApplicationGroup"
        }
        Update-MgApplication -ApplicationId $applicationId -BodyParameter $appGroupParams
        Write-Host "✅ Application configured for ApplicationGroup claims."
    } catch {
        Write-Warning "Failed to configure any groups claim settings: $($_.Exception.Message)"
    }
    
} else {
    # Create new Enterprise Application from template
    $params = @{
        DisplayName = $samlAppName
    }
    
    Write-Host "Creating Enterprise Application: $samlAppName"
    Invoke-MgInstantiateApplicationTemplate -ApplicationTemplateId $applicationTemplateId -BodyParameter $params
    
    Write-Host "Application and Service Principal created. Waiting 60 seconds for propagation..."
    Start-Sleep -Seconds 60
    
    # Get the created Service Principal and Application
    $createdSP = Get-MgServicePrincipal -Filter "DisplayName eq '$samlAppName'"
    $servicePrincipalId = $createdSP.Id
    
    $createdApp = Get-MgApplication -Filter "DisplayName eq '$samlAppName'"
    $applicationId = $createdApp.Id
    
    # Update Application Object with SAML URLs
    Write-Host "Configuring Application object with SAML URLs..."
    $entityId = "api://$($createdApp.AppId)"
    $appParams = @{
        Web = @{
            RedirectUris = @($SamlCallbackUrl)
            LogoutUrl = $SamlCallbackUrl
        }
        IdentifierUris = @($entityId)
    }
    Update-MgApplication -ApplicationId $applicationId -BodyParameter $appParams
    
    # Update Service Principal for SAML SSO
    Write-Host "Configuring Service Principal for SAML SSO..."
    $spParams = @{
        PreferredSingleSignOnMode = "saml"
    }
    Update-MgServicePrincipal -ServicePrincipalId $servicePrincipalId -BodyParameter $spParams
    
    # Add token signing certificate
    Write-Host "Adding token signing certificate..."
    Add-MgServicePrincipalTokenSigningCertificate -ServicePrincipalId $servicePrincipalId
    Start-Sleep -Seconds 5
    
    # Configure SAML groups claim
    Write-Host "Configuring SAML groups claim..."
    try {
        $appGroupParams = @{
            GroupMembershipClaims = "ApplicationGroup"
        }
        Update-MgApplication -ApplicationId $applicationId -BodyParameter $appGroupParams
        Write-Host "✅ Application configured for ApplicationGroup claims."
        Write-Host "Note: The specific groups claim may need to be configured in Azure Portal."
    } catch {
        Write-Error "Failed to configure any groups claim settings: $($_.Exception.Message)"
    }
    
    
    # Update Service Principal with additional SAML settings
    Write-Host "Updating Service Principal with SAML settings..."
    $finalSpParams = @{
        NotificationEmailAddresses = @($NotificationEmail)
        LoginUrl = $SamlLoginUrl
    }
    Update-MgServicePrincipal -ServicePrincipalId $servicePrincipalId -BodyParameter $finalSpParams
    
    Write-Host "✅ Enterprise Application SAML configuration completed!"
}

# --- Assign Infrastructure Admin Group to Enterprise Application ---
Write-Host "`nAssigning Infrastructure Admin Group to Enterprise Application..."

# Import required Graph modules for group assignments
Import-Module Microsoft.Graph.Groups -ErrorAction SilentlyContinue

try {
    $servicePrincipal = Get-MgServicePrincipal -ServicePrincipalId $servicePrincipalId
    $defaultAppRole = $servicePrincipal.AppRoles | Where-Object { $_.Value -eq "User" -or $_.DisplayName -eq "User" }
    
    if (-not $defaultAppRole) {
        # If no specific user role exists, use the default role (00000000-0000-0000-0000-000000000000)
        $appRoleId = "00000000-0000-0000-0000-000000000000"
    } else {
        $appRoleId = $defaultAppRole.Id
    }

    # Check if group is already assigned to the enterprise application
    $existingAssignment = Get-MgServicePrincipalAppRoleAssignedTo -ServicePrincipalId $servicePrincipalId | Where-Object { $_.PrincipalId -eq $grp.Id }
    
    if ($existingAssignment) {
        Write-Host "Infrastructure Admin Group is already assigned to the Enterprise Application."
    } else {
        # Get the default app role for user assignment
        
        
        # Create the app role assignment
        $assignmentParams = @{
            PrincipalId = $grp.Id
            ResourceId = $servicePrincipalId
            AppRoleId = $appRoleId
        }
        
        New-MgServicePrincipalAppRoleAssignedTo -ServicePrincipalId $servicePrincipalId -BodyParameter $assignmentParams | Out-Null
        Write-Host "✅ Infrastructure Admin Group assigned to Enterprise Application."
    }

    # Assign Threat Intel group
    $existingAssignmentThreatIntel = Get-MgServicePrincipalAppRoleAssignedTo -ServicePrincipalId $servicePrincipalId | Where-Object { $_.PrincipalId -eq $grpThreatIntel.Id }
    if ($existingAssignmentThreatIntel) {
        Write-Host "Threat Intel Group is already assigned to the Enterprise Application."
    } else {
        $assignmentParamsThreatIntel = @{
            PrincipalId = $grpThreatIntel.Id
            ResourceId = $servicePrincipalId
            AppRoleId = $appRoleId
        }
        New-MgServicePrincipalAppRoleAssignedTo -ServicePrincipalId $servicePrincipalId -BodyParameter $assignmentParamsThreatIntel | Out-Null
        Write-Host "✅ Threat Intel Group assigned to Enterprise Application."
    }

    # Assign Analysts group
    $existingAssignmentAnalysts = Get-MgServicePrincipalAppRoleAssignedTo -ServicePrincipalId $servicePrincipalId | Where-Object { $_.PrincipalId -eq $grpAnalysts.Id }
    if ($existingAssignmentAnalysts) {
        Write-Host "Analysts Group is already assigned to the Enterprise Application."
    } else {
        $assignmentParamsAnalysts = @{
            PrincipalId = $grpAnalysts.Id
            ResourceId = $servicePrincipalId
            AppRoleId = $appRoleId
        }
        New-MgServicePrincipalAppRoleAssignedTo -ServicePrincipalId $servicePrincipalId -BodyParameter $assignmentParamsAnalysts | Out-Null
        Write-Host "✅ Analysts Group assigned to Enterprise Application."
    }
} catch {
    Write-Warning "Failed to assign Infrastructure Admin Group to Enterprise Application: $($_.Exception.Message)"
    Write-Host "You may need to assign the group manually in the Azure Portal:"
    Write-Host "1. Go to Azure Portal > Entra ID > Enterprise applications > $samlAppName"
    Write-Host "2. Navigate to 'Users and groups'"
    Write-Host "3. Click 'Add user/group'"
    Write-Host "4. Select the '$grpNameInfraAdmin' group"
}

Write-Host ""
Write-Host "🔗 GITHUB INTEGRATION SETUP" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# --- Federated Identity Credentials for Main Repo ---
Write-Host "⏳ Creating federated identity credentials for main repository..."
$subjectUri = "repo:$GithubOrga/$($RepoName):environment:$EnvironmentName"
New-AzFederatedIdentityCredentials -ResourceGroupName $rgName -IdentityName $miName -Name "$($managedIdentity.Name)-0" -Issuer "https://token.actions.githubusercontent.com" -Subject $subjectUri | Out-Null
Write-Host "✅ Main repository credentials created: $RepoName" -ForegroundColor Green


# --- Assign Owner Role to Managed Identity ---
Write-Host ""
Write-Host "🔐 Configuring Permissions..." -ForegroundColor Yellow
$roleAssignment = Get-AzRoleAssignment -ObjectId $managedIdentity.PrincipalId -ResourceGroupName $rgName -RoleDefinitionName "Owner" -ErrorAction SilentlyContinue
if (-not $roleAssignment) {
    Write-Host "⏳ Assigning Owner role to managed identity..."
    Start-Sleep -Seconds 5
    New-AzRoleAssignment -ApplicationId $managedIdentity.ClientId -ResourceGroupName $rgName -RoleDefinitionName "Owner"
    Write-Host "✅ Owner role assigned to managed identity" -ForegroundColor Green
} else {
    Write-Host "ℹ️  Managed identity already has Owner role" -ForegroundColor Blue
}

Write-Host ""
Write-Host "🔐 Configuring Azure Kubernetes Service RBAC Cluster Admin role on Rg $AksResourceGroup ..." -ForegroundColor Yellow
$roleAssignment = Get-AzRoleAssignment -ObjectId $managedIdentity.PrincipalId -ResourceGroupName $AksResourceGroup -RoleDefinitionName "Azure Kubernetes Service RBAC Cluster Admin" -ErrorAction SilentlyContinue
if (-not $roleAssignment) {
    Write-Host "⏳ Assigning Azure Kubernetes Service RBAC Cluster Admin role to managed identity on Rg $AksResourceGroup ..."
    Start-Sleep -Seconds 5
    New-AzRoleAssignment -ApplicationId $managedIdentity.ClientId -ResourceGroupName $AksResourceGroup -RoleDefinitionName "Azure Kubernetes Service RBAC Cluster Admin" | Out-Null
    Write-Host "✅ Azure Kubernetes Service RBAC Cluster Admin role assigned to managed identity on Rg $AksResourceGroup" -ForegroundColor Green
} else {
    Write-Host "ℹ️  Managed identity already has Azure Kubernetes Service RBAC Cluster Admin role on Rg $AksResourceGroup" -ForegroundColor Blue
}


Write-Host ""
Write-Host "🔐 Configuring Container Registry Pull Permissions..." -ForegroundColor Yellow
Write-Host "⏳ Finding Azure Container Registry in resource group $AksResourceGroup..."
try {
    $acr = Get-AzContainerRegistry -ResourceGroupName $AksResourceGroup | Select-Object -First 1
    if (-not $acr) {
        throw "No Azure Container Registry found in resource group $AksResourceGroup"
    }
    
    Write-Host "✅ Found Azure Container Registry: $($acr.Name)" -ForegroundColor Green
    
    # Check if the managed identity already has AcrPull role on the specific ACR
    $roleAssignment = Get-AzRoleAssignment -ObjectId $managedIdentity.PrincipalId -Scope $acr.Id -RoleDefinitionName "AcrPull" -ErrorAction SilentlyContinue
    if (-not $roleAssignment) {
        Write-Host "⏳ Assigning AcrPull role to managed identity on ACR $($acr.Name)..."
        Start-Sleep -Seconds 5
        New-AzRoleAssignment -ApplicationId $managedIdentity.ClientId -Scope $acr.Id -RoleDefinitionName "AcrPull" | Out-Null
        Write-Host "✅ AcrPull role assigned to managed identity on ACR $($acr.Name)" -ForegroundColor Green
    } else {
        Write-Host "ℹ️  Managed identity already has AcrPull role on ACR $($acr.Name)" -ForegroundColor Blue
    }
} catch {
    Write-Warning "Failed to configure Container Registry permissions: $($_.Exception.Message)"
    Write-Host "⚠️  You may need to configure ACR permissions manually:" -ForegroundColor Yellow
    Write-Host "   1. Ensure an Azure Container Registry exists in resource group $AksResourceGroup" -ForegroundColor Yellow
    Write-Host "   2. Grant 'AcrPull' role to the managed identity on the ACR" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🔐 Configuring AKS Key Vault Secrets Provider Permissions..." -ForegroundColor Yellow
Write-Host "⏳ Getting AKS Key Vault Secrets Provider managed identity..."
try {
    $aks = Get-AzAksCluster -ResourceGroupName $AksResourceGroup | Select-Object -First 1
    if (-not $aks) {
        throw "No AKS cluster found in resource group $AksResourceGroup"
    }
    
    $addonIdentityObjectId = $aks.AddonProfiles["azureKeyvaultSecretsProvider"].Identity.ObjectId
    if (-not $addonIdentityObjectId) {
        throw "AKS Key Vault Secrets Provider addon is not enabled or configured"
    }
    
    Write-Host "✅ Found AKS Key Vault Secrets Provider identity: $addonIdentityObjectId" -ForegroundColor Green
    
    # Grant "Key Vault Secrets User" role
    $secretsUserRoleAssignment = Get-AzRoleAssignment -ObjectId $addonIdentityObjectId -ResourceGroupName $rgName -RoleDefinitionName "Key Vault Secrets User" -ErrorAction SilentlyContinue
    if (-not $secretsUserRoleAssignment) {
        Write-Host "⏳ Assigning Key Vault Secrets User role to AKS Secrets Provider..."
        New-AzRoleAssignment -ObjectId $addonIdentityObjectId -RoleDefinitionName "Key Vault Secrets User" -ResourceGroupName $rgName | Out-Null
        Write-Host "✅ Key Vault Secrets User role assigned to AKS Secrets Provider" -ForegroundColor Green
    } else {
        Write-Host "ℹ️  AKS Secrets Provider already has Key Vault Secrets User role" -ForegroundColor Blue
    }
    
    # Grant "Key Vault Certificates Officer" role
    $certOfficerRoleAssignment = Get-AzRoleAssignment -ObjectId $addonIdentityObjectId -ResourceGroupName $rgName -RoleDefinitionName "Key Vault Certificates Officer" -ErrorAction SilentlyContinue
    if (-not $certOfficerRoleAssignment) {
        Write-Host "⏳ Assigning Key Vault Certificates Officer role to AKS Secrets Provider..."
        New-AzRoleAssignment -ObjectId $addonIdentityObjectId -RoleDefinitionName "Key Vault Certificates Officer" -ResourceGroupName $rgName | Out-Null
        Write-Host "✅ Key Vault Certificates Officer role assigned to AKS Secrets Provider" -ForegroundColor Green
    } else {
        Write-Host "ℹ️  AKS Secrets Provider already has Key Vault Certificates Officer role" -ForegroundColor Blue
    }
    
} catch {
    Write-Warning "Failed to configure AKS Key Vault Secrets Provider permissions: $($_.Exception.Message)"
    Write-Host "⚠️  You may need to configure these permissions manually:" -ForegroundColor Yellow
    Write-Host "   1. Ensure AKS Key Vault Secrets Provider addon is enabled" -ForegroundColor Yellow
    Write-Host "   2. Grant 'Key Vault Secrets User' role to the provider's managed identity" -ForegroundColor Yellow
    Write-Host "   3. Grant 'Key Vault Certificates Officer' role to the provider's managed identity" -ForegroundColor Yellow
}



Write-Host ""
Write-Host "📜 CERTIFICATE RETRIEVAL" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# Get final application information for output
$finalApp = Get-MgApplication -ApplicationId $applicationId

# Retrieve SAML signing certificate from federation metadata
Write-Host "`n🔐 Retrieving SAML signing certificate from federation metadata..." -ForegroundColor Yellow
try {
    $tenantId = (Get-MgContext).TenantId
    $federationMetadataUrl = "https://login.microsoftonline.com/$tenantId/federationmetadata/2007-06/federationmetadata.xml?appid=$($finalApp.AppId)"
    
    Write-Host "📋 Federation metadata URL: $federationMetadataUrl"
    
    # Download the federation metadata XML with proper handling and headers
    try {
        $headers = @{
            'User-Agent' = 'PowerShell/7.0'
            'Accept' = 'application/xml, text/xml'
        }
        
        Write-Host "⏳ Downloading federation metadata..." -ForegroundColor Yellow
        $response = Invoke-WebRequest -Uri $federationMetadataUrl -Method Get -UseBasicParsing -Headers $headers -TimeoutSec 30
        
        Write-Host "📊 Response Status: $($response.StatusCode)" -ForegroundColor Blue
        Write-Host "📊 Content Type: $($response.Headers['Content-Type'])" -ForegroundColor Blue
        Write-Host "📊 Content Length: $($response.Content.Length) characters" -ForegroundColor Blue
        
        $metadataXmlString = $response.Content
        
        # Check if the response looks like XML
        if (-not $metadataXmlString.TrimStart().StartsWith('<?xml') -and -not $metadataXmlString.TrimStart().StartsWith('<')) {
            throw "Response does not appear to be XML. First 200 characters: $($metadataXmlString.Substring(0, [Math]::Min(200, $metadataXmlString.Length)))"
        }
        
        Write-Host "✅ XML content received successfully" -ForegroundColor Green
        
    } catch {
        Write-Warning "Failed to download federation metadata: $($_.Exception.Message)"
        
        # Try alternative approach using Invoke-RestMethod
        Write-Host "🔄 Trying alternative download method..." -ForegroundColor Yellow
        try {
            $metadataXmlString = Invoke-RestMethod -Uri $federationMetadataUrl -Method Get -TimeoutSec 30
            Write-Host "✅ XML content received via alternative method" -ForegroundColor Green
        } catch {
            throw "Both download methods failed. Last error: $($_.Exception.Message)"
        }
    }
    
    # Create XML document and load the content properly
    Write-Host "⏳ Parsing XML content..." -ForegroundColor Yellow
    $xmlDoc = New-Object System.Xml.XmlDocument
    
    # Add XML settings for better error handling
    $xmlSettings = New-Object System.Xml.XmlReaderSettings
    $xmlSettings.IgnoreWhitespace = $true
    $xmlSettings.IgnoreComments = $true
    
    try {
        # Try to load XML with better error handling
        $xmlDoc.LoadXml($metadataXmlString)
        Write-Host "✅ XML parsed successfully" -ForegroundColor Green
    } catch {
        Write-Warning "XML parsing failed: $($_.Exception.Message)"
        
        # Try to clean the XML string
        Write-Host "🧹 Attempting to clean XML content..." -ForegroundColor Yellow
        $cleanedXml = $metadataXmlString.Trim()
        
        # Remove any BOM or special characters at the beginning
        if ($cleanedXml.StartsWith([char]0xFEFF)) {
            $cleanedXml = $cleanedXml.Substring(1)
            Write-Host "   Removed BOM character" -ForegroundColor Blue
        }
        
        # Try loading the cleaned XML
        try {
            $xmlDoc.LoadXml($cleanedXml)
            Write-Host "✅ XML parsed successfully after cleaning" -ForegroundColor Green
        } catch {
            # Show more details about the XML content for debugging
            Write-Host "❌ XML parsing still failed. Debugging information:" -ForegroundColor Red
            Write-Host "   First 500 characters of response:" -ForegroundColor Yellow
            Write-Host "   $($metadataXmlString.Substring(0, [Math]::Min(500, $metadataXmlString.Length)))" -ForegroundColor Gray
            
            # Check if this might be an HTML error page
            if ($metadataXmlString.Contains('<html') -or $metadataXmlString.Contains('<!DOCTYPE')) {
                throw "Received HTML response instead of XML. This might be an authentication or authorization issue."
            }
            
            throw "Failed to parse XML after cleaning. Original error: $($_.Exception.Message)"
        }
    }
    
    # Create namespace manager to handle XML namespaces
    $nsManager = New-Object System.Xml.XmlNamespaceManager($xmlDoc.NameTable)
    $nsManager.AddNamespace("ds", "http://www.w3.org/2000/09/xmldsig#")
    $nsManager.AddNamespace("saml", "urn:oasis:names:tc:SAML:2.0:metadata")
    $nsManager.AddNamespace("fed", "http://docs.oasis-open.org/wsfed/federation/200706")
    
    # Look for X509Certificate elements using XPath with namespace
    Write-Host "🔍 Searching for certificates in XML..." -ForegroundColor Yellow
    $certNodes = $xmlDoc.SelectNodes("//ds:X509Certificate", $nsManager)
    
    Write-Host "📊 Found $($certNodes.Count) certificate nodes" -ForegroundColor Blue
    
    if ($certNodes.Count -gt 0) {
        # Get the first signing certificate (there might be multiple, but we want the first one)
        $certData = $certNodes[0].InnerText.Trim()
        
        # Remove any whitespace/newlines from the certificate data
        $certData = $certData -replace '\s+', ''
        
        Write-Host "✅ SAML signing certificate retrieved successfully!" -ForegroundColor Green
        Write-Host "`n📜 X.509 Certificate (Base64 - Single Line):"
        Write-Host "=============================================="
        Write-Host $certData -ForegroundColor Cyan
        Write-Host "=============================================="
        
        # Format as standard PEM for reference
        Write-Host "`n📜 Standard PEM Format (for reference):"
        Write-Host "========================================"
        Write-Host "-----BEGIN CERTIFICATE-----" -ForegroundColor Cyan
        # Split the certificate into 64-character lines
        for ($i = 0; $i -lt $certData.Length; $i += 64) {
            $line = $certData.Substring($i, [Math]::Min(64, $certData.Length - $i))
            Write-Host $line -ForegroundColor Cyan
        }
        Write-Host "-----END CERTIFICATE-----" -ForegroundColor Cyan
        Write-Host "========================================"
        
        # Store the raw certificate data for GitHub secrets
        $certDataForGitHub = $certData
        
    } else {
        Write-Warning "No X509Certificate elements found in federation metadata."
        Write-Host "📥 Searching for alternative certificate locations..." -ForegroundColor Yellow
        
        # Try alternative approach - look for certificates in KeyDescriptor elements
        $keyDescriptors = $xmlDoc.SelectNodes("//saml:KeyDescriptor[@use='signing']//ds:X509Certificate", $nsManager)
        Write-Host "📊 Found $($keyDescriptors.Count) KeyDescriptor certificate nodes" -ForegroundColor Blue
        
        if ($keyDescriptors.Count -gt 0) {
            $certData = $keyDescriptors[0].InnerText.Trim() -replace '\s+', ''
            $certDataForGitHub = $certData
            Write-Host "✅ Found certificate in KeyDescriptor element!" -ForegroundColor Green
            Write-Host "📜 Certificate: $certData" -ForegroundColor Cyan
        } else {
            # Try looking in federation metadata without use attribute
            $allKeyDescriptors = $xmlDoc.SelectNodes("//saml:KeyDescriptor//ds:X509Certificate", $nsManager)
            Write-Host "📊 Found $($allKeyDescriptors.Count) total KeyDescriptor certificate nodes" -ForegroundColor Blue
            
            if ($allKeyDescriptors.Count -gt 0) {
                $certData = $allKeyDescriptors[0].InnerText.Trim() -replace '\s+', ''
                $certDataForGitHub = $certData
                Write-Host "✅ Found certificate in any KeyDescriptor element!" -ForegroundColor Green
                Write-Host "📜 Certificate: $certData" -ForegroundColor Cyan
            } else {
                Write-Host "❌ No certificates found in any location within the XML" -ForegroundColor Red
                Write-Host "📥 Manual certificate download required from Azure Portal." -ForegroundColor Yellow
                $certDataForGitHub = $null
            }
        }
    }
    
} catch {
    Write-Warning "Could not retrieve certificate from federation metadata: $($_.Exception.Message)"
    Write-Host "📋 Federation metadata URL: https://login.microsoftonline.com/$tenantId/federationmetadata/2007-06/federationmetadata.xml?appid=$($finalApp.AppId)" -ForegroundColor Yellow
    Write-Host "📥 You can manually download the certificate from Azure Portal > Enterprise Application > Single sign-on > SAML Certificates" -ForegroundColor Yellow
    $certDataForGitHub = $null
}


Write-Host ""
Write-Host "📋 CONFIGURATION SUMMARY" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "🏗️  AZURE RESOURCES CREATED:" -ForegroundColor Yellow
Write-Host "   📁 Resource Group: $rgName"
Write-Host "   🆔 Managed Identity: $miName"
Write-Host "   👥 Security Group: $grpNameInfraAdmin"
Write-Host "   🏢 Enterprise Application: $samlAppName"

Write-Host ""
Write-Host "🔐 SAML CONFIGURATION:" -ForegroundColor Yellow
Write-Host "   🆔 Application (Client) ID: $($finalApp.AppId)"
Write-Host "   🔧 Service Principal ID: $servicePrincipalId"
Write-Host "   🌐 Entity ID: api://$($finalApp.AppId)"
Write-Host "   🔗 Reply URL: $SamlCallbackUrl"
Write-Host "   🚀 Sign-on URL: $SamlLoginUrl"
Write-Host "   📜 Federation Metadata: https://login.microsoftonline.com/$tenantId/federationmetadata/2007-06/federationmetadata.xml?appid=$($finalApp.AppId)"

Write-Host ""
Write-Host "🔧 GITHUB CONFIGURATION REQUIRED" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "📝 ADD THESE SECRETS TO GITHUB ENVIRONMENT:" -ForegroundColor Yellow
Write-Host "   AZURE_CLIENT_ID: $($managedIdentity.ClientId)"
Write-Host "   AZURE_TENANT_ID: $($managedIdentity.TenantId)"
Write-Host "   AZURE_SUBSCRIPTION_ID: $($managedIdentity.Id.Split('/')[2])"
if ($certDataForGitHub) {
    Write-Host "   SAML_CERT_DATA: $certDataForGitHub"
} else {
    Write-Host "   SAML_CERT_DATA: [Certificate data not retrieved - add manually]" -ForegroundColor Yellow
}
Write-Host "   MINIO_ROOT_USER: [Set your MinIO root username]" -ForegroundColor Yellow
Write-Host "   MINIO_ROOT_PASSWORD: [Set your MinIO root password]" -ForegroundColor Yellow
Write-Host "   RABBITMQ_USER: [Set your RabbitMQ username]" -ForegroundColor Yellow
Write-Host "   RABBITMQ_PASSWORD: [Set your RabbitMQ password]" -ForegroundColor Yellow
Write-Host "   OPENCTI_ADMIN_EMAIL: [Set OpenCTI admin email]" -ForegroundColor Yellow
Write-Host "   OPENCTI_ADMIN_PASSWORD: [Set OpenCTI admin password]" -ForegroundColor Yellow
Write-Host "   OPENCTI_ADMIN_TOKEN: [Set OpenCTI admin token, a valid UUID v4 Token https://www.uuidgenerator.net/]" -ForegroundColor Yellow
Write-Host "   OPENCTI_HEALTHCHECK_ACCESS_KEY: [Set OpenCTI healthcheck access key, a valid UUID v4 Token https://www.uuidgenerator.net/]" -ForegroundColor Yellow
Write-Host "   REDIS_PASSWORD: [Set Redis password]" -ForegroundColor Yellow
Write-Host "   SMTP_HOSTNAME: [Set SMTP hostname for email notifications]" -ForegroundColor Yellow
Write-Host "   SOCRADAR_USERNAME: [Set SOCRadar username]" -ForegroundColor Yellow
Write-Host "   SOCRADAR_PASSWORD: [Set SOCRadar password]" -ForegroundColor Yellow

Write-Host ""
Write-Host "📝 ADD THESE VARIABLES TO GITHUB ENVIRONMENT:" -ForegroundColor Yellow
Write-Host "   APPNAME: $AppName"
Write-Host "   APPVERSION: $AppVersion"
Write-Host "   ENTRA_ID_INFRA_ADMIN_GROUP_ID: $($grp.Id)"
Write-Host "   SAML_CALLBACK_URL: $SamlCallbackUrl"
Write-Host "   SAML_ENTRY_POINT: https://login.microsoftonline.com/$tenantId/saml2"
Write-Host "   SAML_ISSUER: api://$($finalApp.AppId)"
Write-Host "   AKS_RESOURCE_GROUP: $AksResourceGroup"
Write-Host "   AKS_CLUSTER_NAME: $(if ($aks.Name) { $aks.Name } else { '[AKS not found]' })"
Write-Host "   ACR_NAME: $(if ($acr.Name) { $acr.Name } else { '[ACR not found]' })"
Write-Host "   OPENCTI_BASE_URL: [Set your OpenCTI base URL]" -ForegroundColor Yellow

Write-Host ""
Write-Host "✅ NEXT STEPS:" -ForegroundColor Green
Write-Host "   1. 🔧 Configure GitHub Secrets and Variables as shown above"
Write-Host "   2. 🚀 Deploy your OpenCTI infrastructure using GitHub Actions"

Write-Host ""
Write-Host "🎉 SETUP COMPLETED SUCCESSFULLY!" -ForegroundColor Green -BackgroundColor Black
Write-Host "==================================================" -ForegroundColor Green
