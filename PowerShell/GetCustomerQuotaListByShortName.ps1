function Get-CustomerQuotaListByShortName
{
    [CmdletBinding()]
    [OutputType([String[]])]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        [String]$VaultAddress,
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        [String]$CustomerShortName,
        [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
        [PSCredential]$Credential
    )

    Begin
    {
        $VaultConnection = New-Object -ComObject SbeAccountManager.VaultConnection
        $VaultManager    = New-Object -ComObject SbeAccountManager.Manager
        $VaultCustomer   = New-Object -ComObject SbeAccountManager.Customer

        $VaultConnection.Address = $VaultAddress
        $VaultCustomer.ShortName = $CustomerShortName
        
        if ($Credential)
        {
            $VaultConnection.Domain   = $Credential.GetNetworkCredential().Domain
            $VaultConnection.userName = $Credential.GetNetworkCredential().UserName
            $VaultConnection.Password = $Credential.GetNetworkCredential().Password
        }
        else
        {
            $VaultConnection.AuthenticationMode = 1
        }
    }
    Process
    {
        [String[]]$CustomerQuotaList = $VaultManager.getCustomerQuotaList($VaultConnection,$VaultCustomer)
    }
    End
    {
        Return $CustomerQuotaList
    }
}