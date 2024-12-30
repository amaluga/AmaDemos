#Script Author: Amadeusz Maluga

#in this demo both lifecycle workflow and access package will trigger same function app
#Lifecycle Workflow: If added to specific group, customExtension is triggered, check for authentication methods of the user, 
#if there's no certain method assigned e.g. FIDO2 key then LogicApp will send email to user's manager
#Access Package: After access request is raised, customExtension is triggered, auth methods of requestor are being checked,
#then email to Approver is being sent with auth methods assigned to help him decide about approval

using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)


# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
$name = $Request.Query.Name
if (-not $name) {
    $name = $Request.Body.Name
}


#region Functions
#check for auth methods and set values in $responseBody
Function Check-AuthMethod($method) {
    
    try {
        switch ($method.AdditionalProperties.'@odata.type') {
            '#microsoft.graph.fido2AuthenticationMethod' {
                Write-Output 'Found fido2AuthenticationMethod'
                $responseBody.fido2AuthenticationMethod = $true
                break;
            }
            '#microsoft.graph.emailAuthenticationMethod' {
                Write-Output 'Found emailAuthenticationMethod'
                $responseBody.emailAuthenticationMethod = $true
                break;
            }
            '#microsoft.graph.microsoftAuthenticatorAuthenticationMethod' {
                Write-Output 'Found microsoftAuthenticatorAuthenticationMethod'
                $responseBody.microsoftAuthenticatorAuthenticationMethod = $true
                break;
            }
            '#microsoft.graph.phoneAuthenticationMethod' {
                Write-Output 'Found phoneAuthenticationMethod'
                $responseBody.phoneAuthenticationMethod = $true
                break;
            }
            '#microsoft.graph.softwareOathAuthenticationMethod' {
                Write-Output 'Found softwareOathAuthenticationMethod'
                $responseBody.softwareOathAuthenticationMethod = $true
                break;
            }
            '#microsoft.graph.temporaryAccessPassAuthenticationMethod' {
                Write-Output 'Found temporaryAccessPassAuthenticationMethod'
                $responseBody.temporaryAccessPassAuthenticationMethod = $true
                break;
            }
            '#microsoft.graph.passwordAuthenticationMethod' {
                Write-Output 'Found passwordAuthenticationMethod'                
                $responseBody.passwordAuthenticationMethod = $true
                break;
            }
            Default {
                Write-Output 'This script does not handle method type: ' + $method.AdditionalProperties['@odata.type']
            }
        }
    }
    catch {
        return $false
    }
}

#need to get MI access token by calling REST API, because 'connect-mggraph -identity -clientid' didn't work (version 2.19.0) - 36 hours after granting
#EntitlementManagement.Read.All API permission, it still was not included in the scope of the token. API REST call response contains all scopes
Function Get-AccessToken {
    $resourceURI = 'https://graph.microsoft.com/'
    $client_id = '<client_id>'
    $tokenAuthURI = $env:IDENTITY_ENDPOINT + "?resource=$resourceURI&client_id=$client_id&api-version=2019-08-01"
    $tokenResponse = Invoke-RestMethod -Method Get -Headers @{"X-IDENTITY-HEADER"="$env:IDENTITY_HEADER"} -Uri $tokenAuthURI
    $accessToken = $tokenResponse.access_token 
    $accessToken = ConvertTo-SecureString -String $accessToken -AsPlainText -Force
    return $accessToken
}

#endregion

#region variables

$responseBody = [PSCustomObject]@{
    #auth methods
    fido2AuthenticationMethod = $false
    emailAuthenticationMethod = $false
    microsoftAuthenticatorAuthenticationMethod = $false
    phoneAuthenticationMethod = $false
    softwareOathAuthenticationMethod = $false
    temporaryAccessPassAuthenticationMethod = $false
    passwordAuthenticationMethod = $false
    #recipient of emails sent by Logic App in later steps
    approverMails = $null
    managerMail = $null
}
#endregion

#region logic
$token = Get-AccessToken
Connect-Mggraph -AccessToken $token

#initializing variables depending if function app was triggered by access package or lifecycle workflow, $null checks different schemas    
#lifecycleWorkflow
if($null -ne $Request.Body.userUPN){
    $UPN = $Request.Body.userUPN
    $managerGUID = (Get-MgUserManager -UserId $UPN).Id   
    $managerMail = (Get-MgUser -UserId $managerGUID -Property Mail).Mail
    
#accessPackage
} elseif ($null -ne $Request.Body.AssignmentPolicyId){
    $UPN = $Request.Body.requestorUPN
    $assignmentPolicyId = $Request.Body.AssignmentPolicyId
    
    #approvers are stored in array as there can be more than 1 approver assigned
    $approvers = @()
    $approvers += (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/identityGovernance/entitlementManagement/assignmentPolicies/$assignmentPolicyId").RequestApprovalSettings.Stages.PrimaryApprovers.userid 

    $approverMails = @()
    foreach($approver in $approvers){
        $approverMails += (Get-MgUser -UserId $approver -Property Mail).Mail
    }   
} else {
    throw "Wrong or no payload received"
    exit
}

#checking for auth methods
$methods = Get-MgUserAuthenticationMethod -UserId $UPN

foreach($method in $methods){
    Check-AuthMethod -method $method 
}
#endregion

# Associate values to output bindings by calling 'Push-OutputBinding'.


#again checking if function was triggered by lifecycle workflow or access package
#accessPackage
if($null -ne $approverMails){
    $responseBody.approverMails = $approverMails

#lifecycleWorkflow
} elseif ($null -ne $managerMail){
    $responseBody.managerMail = $managerMail
}

Disconnect-MgGraph

$response = $responseBody | ConvertTo-Json
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $response
})
