Configuration Litware-TC1
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
    Import-DscResource -Module PSDesiredStateConfiguration, xComputerManagement, xWebAdministration
  
    # Node for TC1
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
            NodeName         = 'litware-dc1.team'+$prmTeam+'.litware.com'
            RetryIntervalSec = 60
            RetryCount       = 60
        }

        # Wait for LabAdmin to be created and promoted to Domain Admin
        WaitForAll DC1AdminAccount
        {
            ResourceName     = '[xADGroup]DA_LabAdmin'
            NodeName         = 'litware-dc1.team'+$prmTeam+'.litware.com'
            RetryIntervalSec = 60
            RetryCount       = 60
        }
    
        # Join Litware Domain
        xComputer AD_LITWARE
        {
            Name       = $env:COMPUTERNAME
            DomainName = 'team'+$prmTeam+'.litware.com'
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
            TestScript = { (Get-Package | Where-Object {$_.Name -eq 'litware-tc1'}).Count -eq 1 }
            SetScript  = 'Install-Package litware-tc1 -Source CreeperHub -ProviderName chocolatey -Force'
            DependsOn  = '[Script]CreeperHubSource'
        }

        # Install IIS
        WindowsFeature IIS
        {
            Name                 = 'Web-Server'
            IncludeAllSubFeature = $true
            Ensure               = 'Present'
        }

        # Remove Default WebSite
        xWebSite WebDefault
        {
            Name      = 'Default Web Site'
            Ensure    = 'Absent'
            DependsOn = '[WindowsFeature]IIS'
        }

        # Copy Timecard into Inetpub
        File fldTimeCard
        {
            DestinationPath = 'C:\inetpub'
            SourcePath      = 'C:\Source'
            Recurse         = $true
            Ensure          = 'Present'
            DependsOn       = '[xWebSite]WebDefault','[Script]GetChocoContent'
        }

        # Create Website - Timecard
        xWebSite WebTimecard
        {
            Name = 'Litware Timecard'
            BindingInfo = MSFT_xWebBindingInformation
                {
                    Protocol = 'http'
                    Port     = 80
                }
            AuthenticationInfo = MSFT_xWebAuthenticationInformation
                {
                    Anonymous = $false
                    Windows   = $true
                }
            PhysicalPath = 'C:\inetpub\LitwareTimecard'
            Ensure = 'Present'
            DependsOn = '[xWebSite]WebDefault','[File]fldTimeCard'
        }
    }
}