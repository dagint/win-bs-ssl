# Settings
$bucket = "ginterm-utility" #S3 bucket name
$key = "ssl.facepunch.me.pfx" #S3 object key
$file = "C:\ssl.facepunch.me.pfx" #local file path
$pwd = ConvertTo-SecureString -String  "1234" -Force -AsPlainText  #pfx password (should store this more securely)

# Get certificate from S3
Read-S3Object -BucketName $bucket -Key $key -File $file

Import-Module WebAdministration
Import-PfxCertificate -FilePath $file -CertStoreLocation cert:\localmachine\my -Password $pwd
$Cert = dir cert:\localmachine\my | Where-Object {$_.Subject -like "*facepunch.me*" }
$Thumb = $Cert.Thumbprint.ToString()
Push-Location IIS:\SslBindings
New-WebBinding -Name "Default Web Site" -IP "*" -Port 443 -Protocol https
Get-Item cert:\localmachine\my\$Thumb | new-item 0.0.0.0!443
Pop-Location

