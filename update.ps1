#################################################
# HelloID-Conn-Prov-Target-UbeeoATS-Update
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
    # Verify if [aRef] has a value
    if ([string]::IsNullOrEmpty($($actionContext.References.Account))) {
        throw 'The account reference could not be found'
    }
    # There is no PreviousData, so always triggers updates.
    $outputContext.PreviousData = $null

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

    # Process
    Write-Information "Updating UbeeoATS account with accountReference: [$($actionContext.References.Account)]"
    $actionContext.Data | Add-Member @{
        employeeId = $actionContext.References.Account
    } -Force
    $splatUpdateParams = @{
        Uri     = "$($actionContext.Configuration.BaseUrl)/api/users"
        Method  = 'POST'
        Body    = ([System.Text.Encoding]::UTF8.GetBytes(($actionContext.Data | ConvertTo-Json)))
        Headers = @{
            'Content-Type' = 'application/ats.api.v1+json'
            Authorization  = "Bearer $($accessToken)"
        }
    }

    if (-not($actionContext.DryRun -eq $true)) {
        $null = Invoke-RestMethod @splatUpdateParams
    } else {
        Write-Information "[DryRun] Update UbeeoATS account with accountReference: [$($actionContext.References.Account)], will be executed during enforcement"
    }
    $outputContext.Success = $true
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = "Update account was successful. AccountReference is: [$($actionContext.References.Account)]"
            IsError = $false
        }
    )
} catch {
    $outputContext.Success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-UbeeoATSError -ErrorObject $ex
        $auditMessage = "Could not update UbeeoATS account. Error: $($errorObj.FriendlyMessage)"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    } else {
        $auditMessage = "Could not update UbeeoATS account. Error: $($ex.Exception.Message)"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
}
