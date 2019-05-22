Configuration Litware-FS01
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
    Import-DscResource -Module PSDesiredStateConfiguration, xComputerManagement, xSmbShare, xDFS
  
    # Node for FS01
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

        # Install DFS
        WindowsFeature FSDFSNamespace
        {
            Name      = 'FS-DFS-Namespace'
            Ensure    = 'Present'
            DependsOn = '[xComputer]AD_LITWARE'
        }

        # Install DFS Management Console
        WindowsFeature RSATDFSMgmtConInstall
        {
            Name   = 'RSAT-DFS-Mgmt-Con'
            Ensure = 'Present'
        }

        # Create Folder - C:\DFSRoots
        File FldDFSRoots
        {
            DestinationPath = 'C:\DFSRoots'
            Type            = 'Directory'
            Ensure          = 'Present'
        }

        # Create Folder - C:\DFSRoots\Files
        File FldDFSRootsFiles
        {
            DestinationPath = 'C:\DFSRoots\Files'
            Type            = 'Directory'
            Ensure          = 'Present'
            DependsOn       = '[File]FldDFSRoots'
        }

        # Create Folder - C:\Shares
        File FldShares
        {
            DestinationPath = 'C:\Shares'
            Type            = 'Directory'
            Ensure          = 'Present'
        }

        # Create Folder - C:\Shares\Marketing
        File FldSharesMarketing
        {
            DestinationPath = 'C:\Shares\Marketing'
            Type            = 'Directory'
            Ensure          = 'Present'
            DependsOn       = '[File]FldShares'
        }

        # Create Folder - C:\Shares\Research
        File FldSharesResearch
        {
            DestinationPath = 'C:\Shares\Research'
            Type            = 'Directory'
            Ensure          = 'Present'
            DependsOn       = '[File]FldShares'
        }

        # Create Folder - C:\Shares\Sales
        File FldSharesSales
        {
            DestinationPath = 'C:\Shares\Sales'
            Type            = 'Directory'
            Ensure          = 'Present'
            DependsOn       = '[File]FldShares'
        }

        # Create SMB Share - C:\DFSRoots\Files
        xSmbShare SMBDFSRootsFiles
        {
            Name        = 'Files'
            Path        = 'C:\DFSRoots\Files'
            Description = 'DFS Roots Files Share'
            FullAccess  = 'LITWARE\LabAdmin'
            Ensure      = 'Present'
            DependsOn   = '[File]FldDFSRootsFiles'
        }

        # Create SMB Share - C:\Shares\Marketing
        xSmbShare SMBSharesMarketing
        {
            Name        = 'Marketing'
            Path        = 'C:\Shares\Marketing'
            Description = 'Marketing Share'
            FullAccess  = 'LITWARE\LabAdmin'
            Ensure      = 'Present'
            DependsOn   = '[File]FldSharesMarketing'
        }

        # Create SMB Share - C:\Shares\Research
        xSmbShare SMBSharesResearch
        {
            Name        = 'Research'
            Path        = 'C:\Shares\Research'
            Description = 'Research Share'
            FullAccess  = 'LITWARE\LabAdmin'
            Ensure      = 'Present'
            DependsOn   = '[File]FldSharesResearch'
        }

        # Create SMB Share - C:\Shares\Sales
        xSmbShare SMBSharesSales
        {
            Name        = 'Sales'
            Path        = 'C:\Shares\Sales'
            Description = 'Sales Share'
            FullAccess  = 'LITWARE\LabAdmin'
            Ensure      = 'Present'
            DependsOn   = '[File]FldSharesSales'
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
            TestScript = { (Get-Package | Where-Object {$_.Name -eq 'litware-fs01'}).Count -eq 1 }
            SetScript  = 'Install-Package litware-fs01 -Source CreeperHub -ProviderName chocolatey -Force'
            DependsOn  = '[Script]CreeperHubSource'
        }

        # Copy file from source - ge_turbo-encabulator.pdf
        File FileOne
        {
            SourcePath      = 'C:\Source\ge_turbo-encabulator.pdf'
            DestinationPath = 'C:\Shares\Marketing\ge_turbo-encabulator.pdf'
            Type            = 'File'
            Ensure          = 'Present'
            DependsOn       = '[Script]GetChocoContent','[File]FldSharesMarketing'
        }

        # Copy file from source - ge_turbo-encabulator.pdf
        File FileTwo
        {
            SourcePath      = 'C:\Source\1995_q1_29.pdf'
            DestinationPath = 'C:\Shares\Research\1995_q1_29.pdf'
            Type            = 'File'
            Ensure          = 'Present'
            DependsOn       = '[Script]GetChocoContent','[File]FldSharesResearch'
        }

        # Copy file from source - CustomerInfo.xlsx
        File FileThree
        {
            SourcePath      = 'C:\Source\CustomerInfo.xlsx'
            DestinationPath = 'C:\Shares\Sales\CustomerInfo.xlsx'
            Type            = 'File'
            Ensure          = 'Present'
            DependsOn       = '[Script]GetChocoContent','[File]FldSharesSales'
        }

        # Copy file from source - xyz.pdf
        File FileFour
        {
            SourcePath      = 'C:\Source\xyz.pdf'
            DestinationPath = 'C:\Shares\Research\xyz.pdf'
            Type            = 'File'
            Ensure          = 'Present'
            DependsOn       = '[Script]GetChocoContent','[File]FldSharesResearch'
        }

        # Copy file from source - Work-Health-and-Safety.pdf
        File FileFive
        {
            SourcePath      = 'C:\Source\Work-Health-and-Safety.pdf'
            DestinationPath = 'C:\Shares\Research\Work-Health-and-Safety.pdf'
            Type            = 'File'
            Ensure          = 'Present'
            DependsOn       = '[Script]GetChocoContent','[File]FldSharesResearch'
        }
      
        # Create DFS Root (using deprecated Resource)
        xDFSNamespaceRoot DFSFiles
        {
            Path                 = '\\team'+$prmTeam+'.litware.com\Files'
            TargetPath           = '\\LITWARE-FS01\Files'
            Type                 = 'DomainV2'
            Description          = 'DFS Root for Litware'
            TimeToLiveSec        = 600
            PsDscRunAsCredential = $crdDomainAdmin
            Ensure               = 'Present'
        }

        # Create DFS Folder - Marketing (using deprecated Resource)
        xDFSNamespaceFolder DFSMarketing
        {
            Path                 = '\\team'+$prmTeam+'.litware.com\Files\Marketing'
            TargetPath           = '\\LITWARE-FS01\Marketing'
            Description          = 'DFS Folder for Marketing'
            TimeToLiveSec        = 600
            PsDscRunAsCredential = $crdDomainAdmin
            Ensure               = 'Present'
            DependsOn            = '[xDFSNamespaceRoot]DFSFiles'
        }
        
        # Create DFS Folder - Research (using deprecated Resource)
        xDFSNamespaceFolder DFSResearch
        {
            Path                 = '\\team'+$prmTeam+'.litware.com\Files\Research'
            TargetPath           = '\\LITWARE-FS01\Research'
            Description          = 'DFS Folder for Research'
            TimeToLiveSec        = 600
            PsDscRunAsCredential = $crdDomainAdmin
            Ensure               = 'Present'
            DependsOn            = '[xDFSNamespaceRoot]DFSFiles'
        }

        # Create DFS Folder - Sales (using deprecated Resource)
        xDFSNamespaceFolder DFSSales
        {
            Path                 = '\\team'+$prmTeam+'.litware.com\Files\Sales'
            TargetPath           = '\\LITWARE-FS01\Sales'
            Description          = 'DFS Folder for Sales'
            TimeToLiveSec        = 600
            PsDscRunAsCredential = $crdDomainAdmin
            Ensure               = 'Present'
            DependsOn            = '[xDFSNamespaceRoot]DFSFiles'
        }
    }
}