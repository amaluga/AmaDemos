#Here are my first attempts joying with Azure REST API:
#https://learn.microsoft.com/en-us/rest/api/azure/

#I just started to fetch assigned roles, users assigned to roles and custom roles
#possibly in conjunction with Log Analytics from "Activity Log" of Subscriptions, EPM could be replaced with custom product


#region functions
function Get-AccessToken([String] $clientId, [securestring] $appSecret, [String] $tenantId)
{
        [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"

		# Construct URI and body needed for authentication
		$uri = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
		$body = @{
			client_id     = $ClientId
            scope         = "https://management.azure.com/.default"
			client_secret = ConvertFrom-SecureString $appSecret -AsPlainText
			grant_type    = "client_credentials"
		}

		$tokenRequest = Invoke-WebRequest -Method Post -Uri $uri -ContentType "application/x-www-form-urlencoded" -Body $body -UseBasicParsing 
		# Unpack Access Token
		$token = ($tokenRequest.Content | ConvertFrom-Json).access_token

        return $token
	
}
#endregion


$tenantId = "xxx"
$clientId = '8xxx'
$subscriptionId = 'xxxxxxx'
$appSecret = Read-Host "Provide secret of $clientId" -AsSecureString

$accessToken = Get-AccessToken -tenantId $tenantId -clientId $clientId -appSecret $appSecret

#region headers
$headers = New-Object "System.Collections.Generic.Dictionary[String,String]"
$headers.Add("Authorization", "Bearer $accessToken")
$headers.Add("Content", "application/json")
#endregion


$response = Invoke-RestMethod -Method GET `
     -Uri "https://management.azure.com/subscriptions/$subscriptionId/providers/Microsoft.Authorization/roleAssignments?api-version=2022-04-01" `
     -Headers $headers


#Set-Location '.\Entra Permission Management'
$response.value | ConvertTo-Json | Out-File -FilePath '.\alternatives_roleAssignments'


#roleDefinitionIds (from roleAssignments payload) can be easily translated by Get-AzRoleDefinition
Get-AzRoleDefinition -Id '18d7d88d-d35e-4fb5-a5c3-7773c20a72d9'


#you can get custom roles through AZURE REST API / built-in roles can also be obtained using same endpoint:
$response = Invoke-RestMethod -Method GET `
     -Uri "https://management.azure.com/subscriptions/$subscriptionId/providers/Microsoft.Authorization/roleDefinitions/?`$filter=type+eq+'CustomRole'&api-version=2022-04-01" `
     -Headers $headers

$response.value | ConvertTo-Json -depth 5| Out-File -FilePath '.\alternatives_roleDefinitions_CustomRoles'


#region tests
$response = Invoke-RestMethod -Method GET `
     -Uri "https://management.azure.com/subscriptions/$subscriptionId/providers/Microsoft.Authorization/roleDefinitions/?api-version=2022-04-01" `
     -Headers $headers

$response.value.properties | Get-Member

#endregion tests
