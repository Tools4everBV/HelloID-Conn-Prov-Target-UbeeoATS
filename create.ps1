#################################################
# HelloID-Conn-Prov-Target-UbeeoATS-Create
# PowerShell V2
#################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

#region functions
function Resolve-UbeeoATSError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]
        $ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            ScriptLineNumber = $ErrorObject.InvocationInfo.ScriptLineNumber
            Line             = $ErrorObject.InvocationInfo.Line
            ErrorDetails     = $ErrorObject.Exception.Message
            FriendlyMessage  = $ErrorObject.Exception.Message
        }
        if ($ErrorObject.Exception.StatusCode -eq 401) {
            $httpErrorObj.ErrorDetails = 'Unauthorized. Please check the ClientId and ClientSecret.'
            $httpErrorObj.FriendlyMessage = 'Unauthorized. Please check the ClientId and ClientSecret.'
        } elseif (-not [string]::IsNullOrEmpty($ErrorObject.ErrorDetails.Message)) {
            $httpErrorObj.ErrorDetails = $ErrorObject.ErrorDetails.Message
        } elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
            if ($null -ne $ErrorObject.Exception.Response) {
                $streamReaderResponse = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
                if (-not [string]::IsNullOrEmpty($streamReaderResponse)) {
                    $httpErrorObj.ErrorDetails = $streamReaderResponse
                }
            }
        }
        if (-not ($ErrorObject.Exception.StatusCode -eq 401)) {
            try {
                $errorDetailsObject = ($httpErrorObj.ErrorDetails | ConvertFrom-Json)
                $httpErrorObj.FriendlyMessage = "$($errorDetailsObject.Error) - $($errorDetailsObject.message)"
            } catch {
                $httpErrorObj.FriendlyMessage = "[$($httpErrorObj.ErrorDetails)] - $($_.Exception.Message)"
            }
        }
        Write-Output $httpErrorObj
    }
}
#endregion

try {
    # Initial Assignments
    $outputContext.AccountReference = 'Currently not available'

    if ($actionContext.CorrelationConfiguration.Enabled) {
        throw 'Correlation is not supported. Please disable the correlation configuration in the HelloID configuration.'
    }

    Write-Information 'Getting Access Token for UbeeoATS API'
    $splatGetToken = @{
        Uri     = "$($actionContext.configuration.BaseUrl)/api/oauth/token"
        Method  = 'POST'
        Headers = @{
            'Content-Type' = 'application/x-www-form-urlencoded'
            Accept         = 'application/json'
        }
        Body    = @{
            grant_type    = 'client_credentials'
            client_id     = $actionContext.Configuration.ClientId
            client_secret = $actionContext.Configuration.ClientSecret
        }
    }
    $accessToken = (Invoke-RestMethod @splatGetToken).access_token

    Write-Information 'Creating and updating UbeeoATS account'
    $splatCreateParams = @{
        Uri     = "$($actionContext.Configuration.BaseUrl)/api/users"
        Method  = 'POST'
        Body    = ([System.Text.Encoding]::UTF8.GetBytes(($actionContext.Data | ConvertTo-Json)))
        Headers = @{
            'Content-Type' = 'application/ats.api.v1+json'
            Authorization  = "Bearer $($accessToken)"
        }
    }
    if (-not($actionContext.DryRun -eq $true)) {
        $null = Invoke-RestMethod @splatCreateParams
    } else {
        Write-Information '[DryRun] Create or update UbeeoATS account, will be executed during enforcement'
    }
    $outputContext.Data = $actionContext.Data
    $outputContext.AccountReference = $actionContext.Data.employeeId
    $outputContext.Success = $true
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = "Create or update account was successful. AccountReference is: [$($outputContext.AccountReference)]"
            IsError = $false
        })
} catch {
    $outputContext.Success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-UbeeoATSError -ErrorObject $ex
        $auditMessage = "Could not create or update UbeeoATS account. Error: $($errorObj.FriendlyMessage)"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    } else {
        $auditMessage = "Could not create or update UbeeoATS account. Error: $($ex.Exception.Message)"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
}