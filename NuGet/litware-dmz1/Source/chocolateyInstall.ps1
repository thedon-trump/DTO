$script_path = $(Split-Path -parent $MyInvocation.MyCommand.Definition)

# Create C:\Source
New-Item -Path C:\Source -ItemType Directory -Force

# Extract LitwareB2C.zip to Source
$shell = New-Object -ComObject Shell.Application
$zip = $shell.NameSpace($script_path+'\LitwareB2C.zip')
foreach ($item in $zip.Items())
{
    $shell.Namespace('C:\Source').CopyHere($item)
}

# Copy all PFX files into Source (DSC will use the correct one)
Copy-Item $script_path'\*.pfx' -Destination C:\Source