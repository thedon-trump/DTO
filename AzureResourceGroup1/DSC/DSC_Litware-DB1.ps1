Configuration Litware-DB1
{
    # Parameters
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [string]
        $prmTeam
    )

    # Create Credential Objects
    $strPassword = ConvertTo-SecureString '5!MakeItReal#' -AsPlainText -Force
    $crdDomainAdmin = New-Object System.Management.Automation.PSCredential('LITWARE\LabAdmin',$strPassword)

    # Import our DSC Resources
    Import-DscResource -Module PSDesiredStateConfiguration, xComputerManagement, xNetworking
  
    # Node for DB1
    Node localhost
    {
        # Configure LCM for Reboot
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
        }

        # Wait for Litware Domain
        WaitForAll DC1Domain
        {
            ResourceName     = '[xADDomain]FirstDS'
            NodeName         = "itware-dc1.$prmTeam.litware.com"
            RetryIntervalSec = 60
            RetryCount       = 60
        }

        # Wait for LabAdmin to be created and promoted to Domain Admin
        WaitForAll DC1AdminAccount
        {
            ResourceName     = '[xADGroup]DA_LabAdmin'
            NodeName         = "litware-dc1.$prmTeam.litware.com"
            RetryIntervalSec = 60
            RetryCount       = 60
        }
    
        # Join Litware Domain
        xComputer AD_LITWARE
        {
            Name       = $env:COMPUTERNAME
            DomainName = "$prmTeam.litware.com"
            Credential = $crdDomainAdmin
            DependsOn  = '[WaitForAll]DC1Domain','[WaitForAll]DC1AdminAccount'
        }

        # Setting - Choco Source for CreeperHub
		Script CreeperHubSource {
			GetScript  = "Get-PackageSource -Name CreeperHub -ErrorAction SilentlyContinue -WarningAction SilentlyContinue"
            TestScript = "(Get-PackageSource -Name CreeperHub -ErrorAction SilentlyContinue -WarningAction SilentlyContinue).Count -eq 1"
            SetScript  = "Register-PackageSource -Name CreeperHub -ProviderName Chocolatey -Location http://creeperhub.azurewebsites.net/nuget -Trusted -Force"
		}

        # Choco - Get Content (places all files in C:\Source)
        Script GetChocoContent {
            GetScript  = 'Get-Package'
            TestScript = { (Get-Package | Where-Object {$_.Name -eq 'litware-db1'}).Count -eq 1 }
            SetScript  = 'Install-Package litware-fs01 -Source CreeperHub -ProviderName chocolatey -Force'
            DependsOn  = '[Script]CreeperHubSource'
        }

        # Set Firewall rule for MySQL
        # -Name "MySQL" -DisplayName "MySQL - 3306 In" -Enabled True -Profile Public -Direction Inbound -Action Allow
        xFirewall FWMySQL
        {
            Name        = 'MySQL'
            DisplayName = 'MySQL - 3306 In'
            Group       = 'MySQL'
            Enabled     = 'True'
            Profile     = ('Public')
            Direction   = 'Inbound'
            LocalPort   = ('3306')
            Protocol    = 'TCP'
            Description = 'MySQL - 3306 In'
            Ensure      = 'Present'
            DependsOn   = '[Script]GetChocoContent'
        }
    }
}