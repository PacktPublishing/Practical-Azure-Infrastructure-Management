# Install IIS
Install-WindowsFeature -Name Web-Server -IncludeManagementTools

# Create website
$websiteName = "bookapp"
$websitePath = "C:\inetpub\wwwroot\$websiteName"
$indexFilePath = "$websitePath\index.html"

New-Item -ItemType Directory -Path $websitePath
Set-Content -Path $indexFilePath -Value "<html><body><h1>Welcome to BookApp!</h1><p>This Web VM1.</p></body></html>"

New-Website -Name $websiteName -PhysicalPath $websitePath -Port 80 -Force
