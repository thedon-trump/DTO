Configuration Litware-DMZ1
{
    # Parameters
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [string]
        $prmTeam,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [string]
        $prmThumbprint
    )

    # Create Credential Objects
    $strPassword = ConvertTo-SecureString '5!MakeItReal#' -AsPlainText -Force
    $certPassword = ConvertTo-SecureString 'litware' -AsPlainText -Force
    $crdDomainAdmin = New-Object System.Management.Automation.PSCredential('LITWARE\LabAdmin',$strPassword)
    $crdCertificate = New-Object System.Management.Automation.PSCredential('cert',$certPassword)

    # Import our DSC Resources
    Import-DscResource -Module PSDesiredStateConfiguration, xComputerManagement, xWebAdministration, xCertificate
  
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
            TestScript = { (Get-Package | Where-Object {$_.Name -eq 'litware-dmz1'}).Count -eq 1 }
            SetScript  = 'Install-Package litware-dmz1 -Source CreeperHub -ProviderName chocolatey -Force'
            DependsOn  = '[Script]CreeperHubSource'
        }

        # Install IIS
        WindowsFeature IIS
        {
            Name                 = 'Web-Server'
            IncludeAllSubFeature = $true
            Ensure               = 'Present'
        }

        # Import Cert from Source
        xPfxImport CertB2C
        {
            Location = 'LocalMachine'
            Thumbprint = $prmThumbprint
            Path = 'C:\Source\star.team'+$prmTeam+'.litware.com.pfx'
            Store = 'WebHosting'
            Credential = $crdCertificate
            DependsOn = '[Script]GetChocoContent','[WindowsFeature]IIS'
        }

        # Remove Default WebSite
        xWebSite WebDefault
        {
            Name      = 'Default Web Site'
            Ensure    = 'Absent'
            DependsOn = '[WindowsFeature]IIS'
        }

        # Copy B2C into Inetpub
        File fldB2C
        {
            DestinationPath = 'C:\inetpub'
            SourcePath      = 'C:\Source'
            Recurse         = $true
            Ensure          = 'Present'
            DependsOn       = '[xWebSite]WebDefault','[Script]GetChocoContent'
        }

        # Create Website - B2C
        xWebSite WebB2C
        {
            Name = 'Litware B2C'
            BindingInfo = MSFT_xWebBindingInformation
                {
                    Protocol = 'https'
                    Port     = 443
                    CertificateThumbprint = $prmThumbprint
                    CertificateStoreName = 'WebHosting'
                    HostName = 'store.team'+$prmTeam+'.litware.com'
                }
            PhysicalPath = 'C:\inetpub\LitwareB2C'
            Ensure = 'Present'
            DependsOn = '[xWebSite]WebDefault','[File]fldB2C','[xPfxImport]CertB2C'
        }
    }
}