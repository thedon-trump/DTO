$script_path = $(Split-Path -parent $MyInvocation.MyCommand.Definition)

# Create C:\Source
New-Item -Path C:\Source -ItemType Directory -Force

# Copy b2cusers
Copy-Item $script_path'\b2cusers.txt' -Destination C:\Source

# Download MySQL Community 5.7.16.0
Get-ChocolateyWebFile -packageName 'mysql' -fileFullPath 'C:\Source\mysql-installer-community-5.7.16.0.msi' -url "https://dev.mysql.com/get/Downloads/MySQLInstaller/mysql-installer-community-5.7.16.0.msi"

# Run MySQL Installer
& cmd /c "msiexec.exe /i c:\source\mysql-installer-community-5.7.16.0.msi /quiet"
& cmd /c "`"C:\Program Files (x86)\MySQL\MySQL Installer for Windows\MySQLInstallerConsole.exe`" community install server;8.0.0;x64:*:type=config;openfirewall=true;generallog=true;binlog=true;serverid=1;enable_tcpip=true;port=3306;rootpasswd=secret:type=user;username=root;password=secret;role=DBManager -silent"
$env:MYSQL_PWD = "secret"
& "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -e "CREATE DATABASE users;"
& "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -e "USE users;CREATE TABLE accounts(firstname VARCHAR(50), lastname VARCHAR(50), email VARCHAR(50), password VARCHAR(50), phone VARCHAR(50));"
& "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -e "USE users;Load data local infile 'c:/source/b2cusers.txt' into table accounts;"
& "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -e "USE users;Grant all on users.* to b2cservice@'%' identified by 'simir!';"

# Delete b2cusers
Remove-Item -Path 'C:\Source\b2cusers.txt' -Force