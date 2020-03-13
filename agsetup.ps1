Add-WindowsFeature Web-Server
Remove-item C:\inetpub\wwwroot\iisstart.htm
Add-Content -Path "C:\inetpub\wwwroot\Default.htm" -Value $($env:computername)
New-Item -ItemType directory -Path "C:\inetpub\wwwroot\music"
New-Item -ItemType directory -Path "C:\inetpub\wwwroot\video"
$musicvalue = "Music: " + $($env:computername)
Add-Content -Path "C:\inetpub\wwwroot\music\test.htm" -Value $musicvalue
$videovalue = "Video: " + $($env:computername)
Add-Content -Path "C:\inetpub\wwwroot\video\test.htm" -Value $videovalue