Configuration Litware-DC1
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
    $crdDomainAdmin = New-Object System.Management.Automation.PSCredential('LabAdmin',$strPassword)
    $crdSafeMode = New-Object System.Management.Automation.PSCredential('safemode',$strPassword)

    # User Arrays (Top first and last names of 2011)
    $FirstNames = "Jacob","Isabella","Ethan","Sophia","Michael","Emma","Jayden","Olivia","William","Ava","Alexander","Emily","Noah","Abigail","Daniel","Madison","Aiden","Chloe","Anthony","Mia","Ryan","Gregory","Kyle","Deron","Josey","Joseph","Kevin","Robert","Michelle","Mandi","Amanda","Ella"
    $LastNames = "Smith","Johnson","Williams","Jones","Brown","Davis","Miller","Wilson","Moore","Taylor","Anderson","Thomas","Jackson","White","Harris","Martin","Thompson","Garcia","Martinez","Robinson","Clark","Rodriguez","Lewis","Lee","Dennis"

    # Import our DSC Resources
    Import-DscResource -Module PSDesiredStateConfiguration, xActiveDirectory, xDnsServer
  
    #Node for DC1
    Node localhost
    {
        # Configure LCM for Reboot
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
        }

        # Install Domain Services
        WindowsFeature ADDSInstall
        {
            Name   = 'AD-Domain-Services'
            Ensure = 'Present'
        }

        # Configure new forest as litware.com
        xADDomain FirstDS
        {
            DomainName                    = 'team'+$prmTeam+'.litware.com'
            DomainNetBIOSName             = 'LITWARE'
            DomainAdministratorCredential = $crdDomainAdmin
            SafemodeAdministratorPassword = $crdSafeMode
            DatabasePath                  = 'C:\NTDS'
            SysvolPath                    = 'C:\SYSVOL'
            DependsOn                     = '[WindowsFeature]ADDSInstall'
        }

        # Wait for Forest
        xWaitForADDomain DscForestWait
        {
            DomainName       = 'team'+$prmTeam+'.litware.com'
            RetryCount       = 60
            RetryIntervalSec = 60
            DependsOn        = '[xADDomain]FirstDS'
        }

        # Install AD Management Tools
        WindowsFeature RSATADDSTools
        {
            Name   = 'RSAT-ADDS-Tools'
            Ensure = 'Present'
        }

        # Add LabAdmin user
        xADUser User_LabAdmin
        {
            DomainName = 'team'+$prmTeam+'.litware.com'
            UserName   = 'LabAdmin'
            Password   = $crdDomainAdmin
            Ensure     = 'Present'
            DependsOn  = '[xWaitForADDomain]DscForestWait'
        }

        # Put LabAdmin user in 'Domain Admins'
        xADGroup DA_LabAdmin
        {
            GroupName        = 'Domain Admins'
            MembersToInclude = 'LabAdmin'
            Ensure           = 'Present'
            DependsOn        = '[xADUser]User_LabAdmin'
        }

        # Put LabAdmin user in 'Enterprise Admins'
        xADGroup EA_LabAdmin
        {
            GroupName        = 'Enterprise Admins'
            GroupScope       = 'Universal'  #Not setting this to what it already is breaks DSC since default is 'Global' and you can't change this one. 
            MembersToInclude = 'LabAdmin'
            Ensure           = 'Present'
            DependsOn        = '[xADUser]User_LabAdmin'
        }

        # Create 10 Generic Users
        Script ADUsers
        {
            GetScript  = { (Get-AdUser -Filter *).Count }
            TestScript = { (Get-AdUser -Filter *).Count -gt 10 }
            SetScript  = {
                for ($i=0; $i -lt 10; $i++) {
                    $usrPassword = ConvertTo-SecureString '5!MakeItReal#' -AsPlainText -Force
                    $fname = $using:FirstNames | Get-Random
                    $lname = $using:LastNames | Get-Random
                    $samAccountName = $fname.Substring(0,1)+$lname
                    $name = $fname + " " + $lname
                    $description = $usrPassword
                    $path = 'cn=Users,DC=team'+$using:prmTeam+',DC=litware,DC=com'
                    $upn = "$samAccountName@litware.com"
                    if ((Get-AdUser -Filter {SamAccountName -eq $samAccountName} | Measure-Object).Count -eq 0) {
                        New-ADUser -SamAccountName $samAccountName -UserPrincipalName $upn -Name $name -GivenName $fname -Surname $lname -AccountPassword $usrPassword -Description $description -Path $path -Enabled $true -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null
                    }
                }
            }
            DependsOn = '[xADGroup]EA_LabAdmin'
        }

        # Configure DNS CNAME for TimeCard app
        xDnsRecord DNSTimeCard
        {
            Name   = 'timecard'
            Target = 'litware-tc1.team'+$prmTeam+'.litware.com'
            Zone   = 'team'+$prmTeam+'.litware.com'
            Type   = 'CName'
            Ensure = 'Present'
        }
    }
}