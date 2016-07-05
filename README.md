# Introduction:
Enable end to end SSL encryption for IIS Elastic beanstalk environments.  This process will provide https (port 443) passthrough on the ELB.

## Requirements:
1.  A certifcate which has been uploaded s3 bucket in .pfx format (typically requires a password)
2.  Use EC2 role to allow access to the s3 bucket where you have stored the .pfx file

## Included Files
The following files will be needed in your .ebextensions folder:
00-commands.config
https-instance-securitygroup.config
https-lb-passthrough.config
https-lb-sg.config

## Installing
- Update 00-commands.config $bucket, $key, $file and <CERTNAME> with appropriate info

### 00-commands.config content
```
files:
  "c:/ssl.ps1":
    content: |
      # Settings
      $bucket = "<S3 Bucket Name>" #S3 bucket name
      $key = "<PFX filename>.pfx" #S3 object key
      $file = "C:\<PFX filename>.pfx" #local file path
      $pwd = ConvertTo-SecureString -String  "<PFX File password>" -Force -AsPlainText  #pfx password (should store this more securely)

      # Get certificate from S3
      Read-S3Object -BucketName $bucket -Key $key -File $file

      Import-Module WebAdministration
      Import-PfxCertificate -FilePath $file -CertStoreLocation cert:\localmachine\my -Password $pwd
      $Cert = dir cert:\localmachine\my | Where-Object {$_.Subject -like "*<CERTNAME>*" }
      $Thumb = $Cert.Thumbprint.ToString()
      Push-Location IIS:\SslBindings
      New-WebBinding -Name "Default Web Site" -IP "*" -Port 443 -Protocol https
      Get-Item cert:\localmachine\my\$Thumb | new-item 0.0.0.0!443
      Pop-Location
commands:
  install_ssl:
    command: PowerShell -ExecutionPolicy Bypass -File "c:/ssl.ps1"
    waitAfterCompletion: 0
```

### https-instance-securitygroup.config content:
```
Resources:
  443inboundfromloadbalancer:
    Type: AWS::EC2::SecurityGroupIngress
    Properties:
      GroupId: {"Fn::GetAtt" : ["AWSEBSecurityGroup", "GroupId"]}
      IpProtocol: tcp
      ToPort: 443
      FromPort: 443
      SourceSecurityGroupName: { "Fn::GetAtt": ["AWSEBLoadBalancer", "SourceSecurityGroup.GroupName"] }
```

### https-lb-passthrough.config content:
```
option_settings:
  aws:elb:listener:443:
    ListenerProtocol: TCP
    InstancePort: 443
    InstanceProtocol: TCP
```

### https-lb-sg.config content:
This file is only needed if you would like to only allow port 443 access to your elb.  If you are planning on putting a redirect from port 80 -> 443 in you application then this config file can be removed.

```
Resources:
    ELBSecurityGroup:
        Type: AWS::EC2::SecurityGroup
        Properties:
            GroupDescription: ELB SecurityGroup for ElasticBeanstalk environment.
            SecurityGroupIngress:
                - FromPort: 443
                  ToPort: 443
                  IpProtocol: tcp
                  CidrIp : 0.0.0.0/0
    AWSEBLoadBalancer:
        Type: "AWS::ElasticLoadBalancing::LoadBalancer"
        Properties:
            SecurityGroups:
                - Fn::GetAtt:
                    - ELBSecurityGroup
                    - GroupId
```
