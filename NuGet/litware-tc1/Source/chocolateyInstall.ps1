$script_path = $(Split-Path -parent $MyInvocation.MyCommand.Definition)

# Create C:\Source
New-Item -Path C:\Source -ItemType Directory -Force

# Extract LitwareTimecard.zip to Source
#Copy-Item $script_path'\LitwareTimecard.zip' -Destination C:\Source
$shell = New-Object -ComObject Shell.Application
$zip = $shell.NameSpace($script_path+'\LitwareTimecard.zip')
foreach ($item in $zip.Items())
{
    $shell.Namespace('C:\Source').CopyHere($item)
}