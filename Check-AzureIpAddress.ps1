<#
.SYNOPSIS
This tool is checking IP address which you inputted is in Azure.

.PARAMETER IpAddress
IP address which you want to check.

.EXAMPLE
Check-AzureIpAddress.ps1 -IpAddress 13.78.0.1

.NOTES
    Name    : Check-AzureIpAddress.ps1
    GitHub  : https://github.com/ShuheiUda/Check-AzureIpAddress
    Version : 1.0.0
    Author  : Syuhei Uda
#>
Param(
    [Parameter(Mandatory=$true)][string]$IpAddress

)

function Validate-StringIPv4Address{
Param(
    [Parameter(Mandatory=$true)]$IPv4Address
)
    [int[]]$SplitIPv4Address = $IPv4Address.Split(".")
    if($SplitIPv4Address.Count -ne 4){
        Return $false
    }else{
        for($octet = 0; $octet -lt 4; $octet++){
            if(($SplitIPv4Address[$octet] -ge 0) -and ($SplitIPv4Address[$octet] -le 256)){
            }else{
                Return $false
            }
        }
    }
}

function ConvertTo-UInt32IPv4Address{
Param(
    [Parameter(Mandatory=$true)]$IPv4Address
)

    [uint32]$UInt32IPv4Address = 0
    [int[]]$SplitIPv4Address = $IPv4Address.Split(".")
    if($SplitIPv4Address.Count -ne 4){
        Return $false
    }else{
        for($octet = 0; $octet -lt 4; $octet++){
            if(($SplitIPv4Address[$octet] -ge 0) -and ($SplitIPv4Address[$octet] -le 256)){
                $UInt32IPv4Address += ($SplitIPv4Address[$octet]*([math]::Pow(256,3-$octet)))
            }else{
                Return $false
            }
        }
    }
    Return $UInt32IPv4Address
}

function ConvertTo-UInt32IPv4StartAddress{
Param(
    [Parameter(Mandatory=$true)]$IPv4AddressRange
)

    [uint32]$UInt32IPv4Address = 0
    $SplitIPv4AddressRange = $IPv4AddressRange.Split("/")
    [int]$SplitIPv4AddressPrefix = $SplitIPv4AddressRange[1]

    if(($SplitIPv4AddressPrefix -ge 0) -and ($SplitIPv4AddressPrefix -le 32)){
        Return (ConvertTo-UInt32IPv4Address $SplitIPv4AddressRange[0])
    }else{
        Write-Error "IPv4 Address Range is not correctly."
        Return -1
    }
}

function ConvertTo-UInt32IPv4EndAddress{
Param(
    [Parameter(Mandatory=$true)]$IPv4AddressRange
)

    [uint32]$UInt32IPv4Address = 0
    $SplitIPv4AddressRange = $IPv4AddressRange.Split("/")
    [int]$SplitIPv4AddressPrefix = $SplitIPv4AddressRange[1]

    if(($SplitIPv4AddressPrefix -ge 0) -and ($SplitIPv4AddressPrefix -le 32)){
        Return ((ConvertTo-UInt32IPv4Address $SplitIPv4AddressRange[0]) + [math]::Pow(2, 32 - $SplitIPv4AddressPrefix) - 1)
    }else{
        Write-Error "IPv4 Address Range is not correctly."
        Return -1
    }
}

function Check-UInt32IPv4AddressRange{
Param(
    [uint32][Parameter(Mandatory=$true)]$UInt32TargetIPv4Address,
    [uint32][Parameter(Mandatory=$true)]$UInt32StartIPv4Address,
    [uint32][Parameter(Mandatory=$true)]$UInt32EndIPv4Address
)
    if(($UInt32TargetIPv4Address -ge $UInt32StartIPv4Address) -and ($UInt32TargetIPv4Address -le $UInt32EndIPv4Address)){
        Return $true
    }else{
        Return $false
    }
}

### Main method

# Header
$Version = "1.0.0"
$LatestVersionUrl = "https://raw.githubusercontent.com/ShuheiUda/Check-AzureIpAddress/master/LatestVersion.txt"
$IsAzureIp = $false
$Region = $null

$LatestVersion = (Invoke-WebRequest $LatestVersionUrl -ErrorAction SilentlyContinue).Content
if($Version -lt $LatestVersion){
    Write-Warning "New version is available. ($LatestVersion)`nhttps://github.com/ShuheiUda/Check-AzureIpAddress"
}

Write-Debug "$(Get-Date) IpAddress: $IpAddress"

# Address check
if((Validate-StringIPv4Address $IpAddress) -eq $false){
    Write-Error "Please input source address correctly. (Example: 192.168.0.0)"
    Return
}

# Get IP address range from Download Center
$downloadUri = "https://www.microsoft.com/en-in/download/confirmation.aspx?id=41653"
$downloadPage = Invoke-WebRequest -Uri $downloadUri -UseBasicParsing 
$xmlFileUri = ($downloadPage.RawContent.Split('"') -like "https://*PublicIps*")[0]
$OriginalFileName = Split-Path $xmlFileUri -Leaf
$response = Invoke-WebRequest -Uri $xmlFileUri
[xml]$xmlResponse = [System.Text.Encoding]::UTF8.GetString($response.Content)

# Check IP address
$xmlResponse.AzurePublicIpAddresses.Region | foreach{
    $Region = $_.Name
    $_.IpRange | foreach{
        # Check IP address
        if(Check-UInt32IPv4AddressRange -UInt32TargetIPv4Address (ConvertTo-UInt32IPv4Address $IpAddress) -UInt32StartIPv4Address (ConvertTo-UInt32IPv4StartAddress $_.Subnet) -UInt32EndIPv4Address (ConvertTo-UInt32IPv4EndAddress $_.Subnet)){
            Write-Host "$IpAddress is in Azure $Region region." -ForegroundColor Green
            break
        }
    }
}
Write-Host "$IpAddress is not in Azure." -ForegroundColor Red
Start-Process "https://db-ip.com/$IpAddress"