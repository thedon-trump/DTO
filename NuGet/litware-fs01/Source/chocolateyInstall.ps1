$script_path = $(Split-Path -parent $MyInvocation.MyCommand.Definition)

# Create C:\Source
New-Item -Path C:\Source -ItemType Directory -Force

# Copy files 
Copy-Item $script_path'\1995_q1_29.pdf' -Destination C:\Source
Copy-Item $script_path'\CustomerInfo.xlsx' -Destination C:\Source
Copy-Item $script_path'\ge_turbo-encabulator.pdf' -Destination C:\Source
Copy-Item $script_path'\Work-Health-and-Safety.pdf' -Destination C:\Source
Copy-Item $script_path'\XYZ.pdf' -Destination C:\Source