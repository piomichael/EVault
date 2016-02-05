function Verb-Noun
{
    [CmdletBinding()]
    [OutputType([Type])]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        [String]$VaultAddress,
        [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
        [PSCredential]$Credential
    )

    Begin
    {
        $VaultConnection = New-Object -ComObject SbeAccountManager.VaultConnection
        $VaultManager    = New-Object -ComObject SbeAccountManager.Manager

        $VaultConnection.Address = $VaultAddress
        
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

    }
    End
    {
        Return 
    }
}