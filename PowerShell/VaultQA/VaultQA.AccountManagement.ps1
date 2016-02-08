function VaultQA.New-CustomerComputerTask
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        [String]$XMLConfigurationFile
    )

    VaultQA.New-Customer -XMLConfigurationFile $XMLConfigurationFile
    VaultQA.New-Computer -XMLConfigurationFile $XMLConfigurationFile
    VaultQA.New-Task     -XMLConfigurationFile $XMLConfigurationFile
}

function VaultQA.New-Customer
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        [String]$XMLConfigurationFile
    )

    Begin
    {
        # Importing configuration file into XML format.
        $XML = [XML](Get-Content -Path $XMLConfigurationFile)

        # Creating hashtable to group individual Vault configurations.
        [Hashtable]$Config = @{}
        
        # Importing Vault address information from configuration file.
        $Config.VaultAddress = @()
        foreach ($VaultAddress in $XML.Configuration.VaultInformation.Address)
        {
            $Config.VaultAddress += $VaultAddress.Name
        }

        # Setting Customer properties from configuration file.
        [String]$CustomerName              = $XML.Configuration.AccountInformation.CustomerName
        [String]$CustomerPhone             = $XML.Configuration.AccountInformation.CustomerPhone
        [String]$CustomerLocation          = $XML.Configuration.AccountInformation.CustomerLocation
        [String]$CustomerBillingCodePrefix = $XML.Configuration.AccountInformation.CustomerBillingCodePrefix
        [String]$CustomerAccountName       = $XML.Configuration.AccountInformation.CustomerAccountName
        [String]$CustomerAccountUserName   = $XML.Configuration.AccountInformation.CustomerAccountUserName
        [String]$CustomerAccountPassword   = $XML.Configuration.AccountInformation.CustomerAccountPassword
        
        # Setting the amount of Customers to create.
        [Int32]$CustomerAccountQuantity = $XML.Configuration.AccountInformation.CustomerAccountQuantity

        # Scriptblock to allow 32bit execution against the VaultApi for max compatibility.
        $ApiCallCreateCustomer =
        {
            $VaultAddress = $args[0]
            
            # Customer parameters.
            $CustomerIncrement       = $args[1]
            $CustomerName            = $args[2] + ("{0:D2}" -F $CustomerIncrement) # Create unique customer names by adding the increment count as a suffix.
            $CustomerPhone           = $args[3]
            $CustomerLocation        = $args[4]
            $CustomerBillingCode     = $args[5] + ("{0:D2}" -F $CustomerIncrement) # Create unique billing codes by adding the increment count as a suffix.
            $CustomerAccountName     = $args[6] + ("{0:D2}" -F $CustomerIncrement) # Create unique account names by adding the increment count as a suffix.
            $CustomerAccountUserName = $args[7]
            $CustomerAccountPassword = $args[8]

            # Creating VaultApi ComObjects.
            $VaultConnection = New-Object -ComObject SbeAccountManager.VaultConnection
            $VaultManager    = New-Object -ComObject SbeAccountManager.Manager
            $VaultCustomer   = New-Object -ComObject SbeAccountManager.Customer
            $VaultLocation   = New-Object -ComObject SbeAccountManager.Location
            $VaultAccount    = New-Object -ComObject SbeAccountManager.Account
            $VaultUser       = New-Object -ComObject SbeAccountManager.User

            # Setting VaultConnection parameters.
            $VaultConnection.Address            = $VaultAddress
            $VaultConnection.AuthenticationMode = 1
            
            # Setting VaultCustomer parameters.
            $VaultCustomer.Name          = $CustomerName
            $VaultCustomer.ShortName     = $CustomerName
            $VaultCustomer.Phone         = $CustomerPhone
            $VaultCustomer.Email         = ([Security.Principal.WindowsIdentity]::GetCurrent().Name.Split("\")[1]).ToLower() + "@email.com" # Use logon user for informatoin.
            $VaultCustomer.ContactPerson = ([Security.Principal.WindowsIdentity]::GetCurrent().Name.Split("\")[1]) # Use logon user for information.
            
            # Setting VaultLocation parameters.
            $VaultLocation.Name        = $CustomerLocation
            $VaultLocation.BillingCode = $CustomerBillingCode

            # Setting VaultAccount parameters.
            $VaultAccount.Name = $CustomerAccountName
            
            # Setting VaultUser parameters.
            $VaultUser.Name     = $CustomerAccountUserName
            $VaultUser.Password = $CustomerAccountPassword

            # Creating Customer account on the Vault.
            $VaultManager.Create($VaultConnection,$VaultCustomer,$VaultLocation,$VaultAccount,$VaultUser)
        }
    }
    Process
    {
        # Processing request based on provided configuration file.
        foreach ($VaultAddress in $Config.VaultAddress)
        {
            [Int32]$ProcessCount = 1

            while ($ProcessCount -le $CustomerAccountQuantity)
            {
                $JobName = $VaultAddress + "_" + $ProcessCount
                $ResultApiCallCreateCustomer = Start-Job $ApiCallCreateCustomer -RunAs32 -Name $JobName -ArgumentList `
                  $VaultAddress, `
                  $ProcessCount, `
                  $CustomerName, `
                  $CustomerPhone, `
                  $CustomerLocation, `
                  $CustomerBillingCodePrefix, `
                  $CustomerAccountName, `
                  $CustomerAccountUserName, `
                  $CustomerAccountPassword | Wait-Job | Receive-Job
                
                # Output results to console.
                $ResultApiCallCreateCustomer

                Remove-Job -Name $JobName -Force

                $ProcessCount++
            }
        }
    }
}

function VaultQA.New-Computer
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        [String]$Configuration
    )

    Begin
    {
        # Importing configuration file into XML format.
        $XML = [XML](Get-Content -Path $XMLConfigurationFile)

        # Creating hashtable to group individual Vault configurations.
        [Hashtable]$Config = @{}
        
        # Importing Vault address information from configuration file.
        $Config.VaultAddress = @()
        foreach ($VaultAddress in $XML.Configuration.VaultInformation.Address)
        {
            $Config.VaultAddress += $VaultAddress.Name
        }

        # Setting computer properties from configuration file.
        [String]$ComputerName = $XML.Configuration.ComputerInformation.ComputerName
        
        # Setting the amount of Computers to create.
        [Int32]$ComputerQuantity = $XML.Configuration.ComputerInformation.ComputerQuantity

        # Setting file path to FakeAgent.exe from configuration file.
        [String]$FakeBinary = $XML.Configuration.FakeAgentFilePath

        # Scriptblock to allow 32bit execution against the VaultApi for max compatibility.
        $ApiCallCollectCustomer =
        {
            $VaultAddress = $args[0]

            # Creating VaultApi ComObjects.
            $VaultConnection = New-Object SbeAccountManager.VaultConnection
            $VaultManager    = New-Object SbeAccountManager.Manager

            # Setting VaultConnection parameters.
            $VaultConnection.Address            = $VaultAddress
            $VaultConnection.AuthenticationMode = 1

            # Collecting Customer information.
            [PSCustomObject]$VaultCustomers = $VaultManager.getCustomerList($VaultConnection) |
                Select-Object Id

            # Creating an array to group Customer information together.
            [String[]]$VaultCustomerCollection = @()

            # Looping through Customer list to capture AccountName, AccountUserName, and AccountPassword.
            foreach ($Customer in $VaultCustomers)
            {
                [PSCustomObject]$VaultLocations = $VaultManager.getLocationList($VaultConnection,$Customer.Id) |
                    Select-Object Id

                foreach ($Location in $VaultLocations)
                {
                    [PSCustomObject]$VaultCustomerAccount = $VaultManager.getAccountList($VaultConnection,$Location.Id) |
                        Select-Object Name
                    
                    [PSCustomObject]$VaultCustomerAccountUserName = $VaultManager.getUserList($VaultConnection,$Location.Id) |
                        Select-Object Name,Password

                    $VaultCustomerCollection += "$($VaultCustomerAccount.Name),$($VaultCustomerAccountUserName.Name),$($VaultCustomerAccountUserName.Password)"
                }
            }
            Return $VaultCustomerCollection
        }
    }
    Process
    {
        foreach ($VaultAddress in $Config.VaultAddress)
        {
            # Get Customer list from the Vault.
            $VaultCustomerCollection = Start-Job $ApiCallCollectCustomer -RunAs32 -ArgumentList $VaultAddress | Wait-Job | Receive-Job   
            Get-Job | Remove-Job -Force
            foreach ($Customer in $VaultCustomerCollection)
            {
                # Extract individual account properties from collection
                $AccountName     = $Customer.Split(",")[0]
                $AccountUserName = $Customer.Split(",")[1]
                $AccountPassword = $Customer.Split(",")[2]

                # FakeAgent parameters to register a new computer.
                $Command         = "Register Computer"
                $AgentId         = "-AgentTypeId=1"
                $AccountName     = "-Account=" + $AccountName
                $AccountUserName = "-User=" + $AccountUserName
                $AccountPassword = "-Password=" + $AccountPassword
                $VaultAddress    = "-Vault=" + $VaultAddress
                $VaultLocation   = "-Remote"

                # Registering new Computer to the Vault.
                $ProcessCount = 1
                while ($ProcessCount -le $ComputerQuantity)
                {
                    $ComputerName = "-ComputerName=" + $ComputerName + "{0:D2}" -F $ProcessCount
                    Start-Process -FilePath $FakeBinary -ArgumentList "`
                        $Command `
                        $ComputerName `
                        $AgentId `
                        $AccountName `
                        $AccountUserName `
                        $AccountPassword `
                        $VaultAddress `
                        $VaultLocation `
                        " -NoNewWindow -Wait
                    $ProcessCount++
                }
            }
        }
    }
}

function VaultQA.New-Task
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        [String]$Configuration
    )

    Begin
    {
        # Importing configuration file into XML format.
        $XML = [XML](Get-Content -Path $XMLConfigurationFile)

        # Creating hashtable to group individual Vault configurations.
        [Hashtable]$Config = @{}
        
        # Importing Vault address information from configuration file.
        $Config.VaultAddress = @()
        foreach ($VaultAddress in $XML.Configuration.VaultInformation.Address)
        {
            $Config.VaultAddress += $VaultAddress.Name
        }

        # Setting task properties from configuration file.
        [String]$TaskName = $XML.Configuration.TaskInformation.TaskName
        
        # Setting the amount of Tasks to create.
        [Int32]$TaskQuantity = $XML.Configuration.TaskInformation.TaskQuantity

        # Setting file path to FakeAgent.exe from configuration file.
        [String]$FakeBinary = $XML.Configuration.FakeAgentFilePath

        # Scriptblock to allow 32bit execution against the VaultApi for max compatibility.
        $ApiCallCollectCustomerComputer =
        {
            $VaultAddress = $args[0]

            # Creating VaultApi ComObjects.
            $VaultConnection = New-Object SbeAccountManager.VaultConnection
            $VaultManager    = New-Object SbeAccountManager.Manager

            # Setting VaultConnection parameters.
            $VaultConnection.Address            = $VaultAddress
            $VaultConnection.AuthenticationMode = 1

            # Collecting Customer information.
            [PSCustomObject]$VaultCustomers = $VaultManager.getCustomerList($VaultConnection) |
                Select-Object Id

            # Creating an array to group Customer information together.
            [String[]]$VaultCustomerCollection = @()

            # Looping through Customer list to capture AccountName, AccountUserName, AccountPassword, ComputerGuid.
            foreach ($Customer in $VaultCustomers)
            {
                [PSCustomObject]$VaultLocations = $VaultManager.getLocationList($VaultConnection,$Customer.Id) |
                    Select-Object Id

                foreach ($Location in $VaultLocations)
                {
                    [PSCustomObject]$VaultCustomerAccount = $VaultManager.getAccountList($VaultConnection,$Location.Id) |
                        Select-Object Name
                    
                    [PSCustomObject]$VaultCustomerAccountUserName = $VaultManager.getUserList($VaultConnection,$Location.Id) |
                        Select-Object Name,Password

                    [PSCustomObject]$VaultComputers = $VaultManager.getComputerList($VaultConnection,$Location.Id) |
                        Select-Object Guid

                    foreach ($Computer in $VaultComputers)
                    {
                        $VaultCustomerCollection += "$($VaultCustomerAccount.Name),$($VaultCustomerAccountUserName.Name),$($VaultCustomerAccountUserName.Password),$($Computer.Guid)"
                    }
                }
            }
            Return $VaultCustomerCollection
        }
    }
    Process
    {
        foreach ($VaultAddress in $Config.VaultAddress)
        {
            # Get Computer list from the Vault.
            $VaultCustomerCollection = Start-Job $ApiCallCollectCustomerComputer -RunAs32 -ArgumentList $VaultAddress | Wait-Job | Receive-Job   
            Get-Job | Remove-Job -Force
            foreach ($Customer in $VaultCustomerCollection)
            {
                # Extract individual account properties from collection
                $AccountName     = $Customer.Split(",")[0]
                $AccountUserName = $Customer.Split(",")[1]
                $AccountPassword = $Customer.Split(",")[2]
                $ComputerGuid    = $Cusotmer.Split(",")[3]

                # FakeAgent parameters to register a new computer.
                $Command         = "Register Task"
                $ComputerGuid    = "-ComputerId=" + $ComputerGuid
                $AccountName     = "-Account=" + $AccountName
                $AccountUserName = "-User=" + $AccountUserName
                $AccountPassword = "-Password=" + $AccountPassword
                $VaultAddress    = "-Vault=" + $VaultAddress
                $VaultLocation   = "-Remote"

                # Registering new Task to the Vault.
                $ProcessCount = 1
                while ($ProcessCount -le $TaskQuantity)
                {
                    $TaskName = "-TaskName=" + $ComputerName + "{0:D2}" -F $ProcessCount
                    Start-Process -FilePath $FakeBinary -ArgumentList "`
                        $Command `
                        $TaskName `
                        $ComputerGuid `
                        $AccountName `
                        $AccountUserName `
                        $AccountPassword `
                        $VaultAddress `
                        $VaultLocation `
                        " -NoNewWindow -Wait
                    $ProcessCount++
                }
            }
        }
    }
}