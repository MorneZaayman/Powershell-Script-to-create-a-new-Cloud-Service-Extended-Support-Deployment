# Set the location
$location = "southafricanorth";

# Sign In To Azure
Connect-AzAccount

# Set Context
Set-AzContext -Tenant "e7677071-26f6-4aa8-967f-8405db4a6718"

# Create the Resource Group
$resourceGroup = New-AzResourceGroup -Name "MzansiBytes" -Location $location

# Create the Storage Account
$storageAccount = New-AzStorageAccount -ResourceGroupName $resourceGroup.ResourceGroupName -AccountName "mzansibytes" -Location $location -SkuName "Standard_LRS" -Kind "StorageV2" -AccessTier "Hot" -AllowBlobPublicAccess $true

# Create the Virtual Network
$subnet = New-AzVirtualNetworkSubnetConfig -Name "MzansiBytes" -AddressPrefix "10.1.0.0/24"
New-AzVirtualNetwork -Name "MzansiBytes" -ResourceGroupName $resourceGroup.ResourceGroupName -Location $location -AddressPrefix "10.1.0.0/16" -Subnet $subnet

# Create the Public IP Address
New-AzPublicIpAddress -ResourceGroupName $resourceGroup.ResourceGroupName -Name "MzansiBytes" -AllocationMethod Static -DomainNameLabel "mzansibytes" -Location $location -Sku "Basic"

# Create the Key Vault
$keyVault = New-AzKeyVault -ResourceGroupName $resourceGroup.resourceGroupName -VaultName "MzansiBytes" -Location $location -enabledForDeployment -enabledForTemplateDeployment
$password = ConvertTo-SecureString -String "Password123!" -Force -AsPlainText
Import-AzKeyVaultCertificate -VaultName $keyVault.VaultName -Name "MzansiBytes" -FilePath "$PSScriptRoot\MzansiBytes.pfx" -Password $password

# Package the project
$msBuildFilePath = "C:\Program Files\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\MSBuild.exe"
.$msBuildFilePath "$PSScriptRoot\MzansiBytes\MzansiBytes.ccproj" `
    /p:Configuration=Release `
    /p:PublishDir="$PSScriptRoot\Temp\CloudPackage" `
    /p:TargetProfile="Cloud" `
    /p:Platform=AnyCpu `
    /t:Publish

# Create the Cloud Service Resource
New-AzCloudService `
    -Name "MzansiBytes-1" `
    -ResourceGroupName $resourceGroup.ResourceGroupName `
    -Location $location `
    -DefinitionFile "$PSScriptRoot\MzansiBytes\ServiceDefinition.csdef" `
    -ConfigurationFile "$PSScriptRoot\Temp\CloudPackage\ServiceConfiguration.Cloud.cscfg" `
    -PackageFile "$PSScriptRoot\Temp\CloudPackage\MzansiBytes.cspkg" `
    -KeyVaultName $keyVault.VaultName `
    -StorageAccount $storageAccount.StorageAccountName

# Cleanup
Remove-Item "$PSScriptRoot\Temp" -Recurse -Force