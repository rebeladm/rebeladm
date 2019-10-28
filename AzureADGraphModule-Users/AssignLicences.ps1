#######Script to Assign Licences to Synced Users from On-Permises AD#############

Import-Module AzureAD

Connect-AzureAD

###Filter Synced Users who doesnt have licence assigned#######

$ADusers = Get-AzureADUser -All $true -Filter 'DirSyncEnabled eq true'

$notlicenced = Get-AzureADUser -All $true | Where-Object {$ADusers.AssignedLicenses -ne $null} | select ObjectId | Out-File -FilePath C:\users.txt

#####Set UsageLocation value to sync users#########

(Get-Content "C:\users.txt" | select-object -skip 3) | ForEach { Set-AzureADUser -ObjectId $_ -UsageLocation "US" }

#####Set User Licecnes############

$newlicence = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicense

$newlicenceadd = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicenses

$newlicence.SkuId = (Get-AzureADSubscribedSku | Where-Object -Property SkuPartNumber -Value "ENTERPRISEPREMIUM" -EQ).SkuId

$newlicenceadd.AddLicenses = $newlicence

(Get-Content "C:\users.txt" | select-object -skip 3) | ForEach { Set-AzureADUserLicense -ObjectId $_ -AssignedLicenses $newlicenceadd }