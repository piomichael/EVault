function Test-AccountNameAndUserNameExist
{
    [CmdletBinding()]
    [OutputType([Bool])]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        [String]$VaultAddress,
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        [String]$AccountName,
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        [String]$AccountUserName,
        [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
        [PSCredential]$Credential
    )

    Begin
    {
        $VaultConnection = New-Object -ComObject SbeAccountManager.VaultConnection
        $VaultManager    = New-Object -ComObject SbeAccountManager.Manager
        $VaultAccount    = New-Object -ComObject SbeAccountManager.Account
        $VaultUser       = New-Object -ComObject SbeAccountManager.User

        $VaultConnection.Address = $VaultAddress
        $VaultAccount.Name       = $AccountName
        $VaultUser.Name          = $AccountUserName
        
        [Bool]$AccountExist = ''

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
        $VaultManager.accountAndUserExists($VaultConnection,$VaultAccount.Name,$VaultUser.Name,[Ref]$AccountExist)
    }
    End
    {
        Return $AccountExist
    }
}