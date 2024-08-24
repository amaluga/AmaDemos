# https://learn.microsoft.com/en-us/azure/role-based-access-control/tutorial-custom-role-powershell


$credentials = Get-Credential
Connect-AzAccount -Tenant 'xxx' -Subscription 'xxx' -Credential $credentials
#check for actions in specific access resource
Get-AzProviderOperation "Microsoft.Automation/*" | FT Operation, Description -AutoSize

cd '.\Entra Permission Management'
#create new custom role from JSON
New-AzRoleDefinition -InputFile '.\custom_role.json'

