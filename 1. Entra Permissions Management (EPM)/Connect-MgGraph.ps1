#This is the script I used for EPM initial configuration
#https://learn.microsoft.com/en-us/entra/permissions-management/permissions-management-quickstart-guide - Setup in Azure
#https://learn.microsoft.com/en-us/entra/permissions-management/onboard-azure - setup in Entra Permissions App (EPM)

#region initial config
#Azure
Connect-MgGraph -Scopes "Application.ReadWrite.All"


Connect-AzAccount

#Creation of Authentication System in Azure
#assigning required permissions
#b46c3ac5-9da6-418f-a849-0a07a10b3c6c is EPM application with type of "Microsoft App" - created after you enable EPM in your tenant
New-AzRoleAssignment -ApplicationId b46c3ac5-9da6-418f-a849-0a07a10b3c6c  -RoleDefinitionName "Reader" -Scope "/subscriptions/xxx"
New-AzRoleAssignment -ApplicationId b46c3ac5-9da6-418f-a849-0a07a10b3c6c  -RoleDefinitionName "User Access Administrator" -Scope "/subscriptions/xxx"

#Creation of Authentication System in AWS
New-Mgapplication -DisplayName "mciem-aws-oidc-connector" -identifierUris "api://mciem-aws-oidc-app"


#AWS CONFIGURATION - ORIGINAL SUB CLAIM IN mciem-oidc-connect-role! cbbdeae9-3964-4552-9df0-1876b9472db7
#endregion
