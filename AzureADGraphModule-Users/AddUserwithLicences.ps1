########A Script to create new users and assign Azure AD licences#######

Import-Module AzureAD

Connect-AzureAD

###########Create New Users using CSV ###################

$Userpassword = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile

$Userpassword.Password = "London@1234"

Import-Csv -Path C:\newuser.csv | foreach {New-AzureADUser -UserPrincipalName $_.UserPrincipalName -DisplayName $_.DisplayName -MailNickName $_.MailNickName -PasswordProfile $Userpassword -UsageLocation "US" -AccountEnabled $true} | select ObjectId | Out-File -FilePath C:\users.txt

###########Assign Licences#################

$newlicence = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicense

$newlicenceadd = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicenses

$newlicence.SkuId = (Get-AzureADSubscribedSku | Where-Object -Property SkuPartNumber -Value "ENTERPRISEPREMIUM" -EQ).SkuId

$newlicenceadd.AddLicenses = $newlicence

(Get-Content "C:\users.txt" | select-object -skip 3) | ForEach { Set-AzureADUserLicense -ObjectId $_ -AssignedLicenses $newlicenceadd }