﻿<#
.SYNOPSIS
This tool is checking IP address which you inputted is in Azure.

.PARAMETER IpAddress
IP address which you want to check.

.EXAMPLE
Check-AzureIpAddress.ps1 -IpAddress 13.78.0.1, 13.78.0.2

.NOTES
    Name    : Check-AzureIpAddress.ps1
    GitHub  : https://github.com/ShuheiUda/Check-AzureIpAddress
    Version : 1.2.0
    Author  : Syuhei Uda
#>
Param(
    [Parameter(Mandatory=$true)][array]$IpAddresses

)

function Validate-StringIPv4Address{
Param(
    [Parameter(Mandatory=$true)]$IPv4Addresses
)
    $IPv4Addresses | foreach{
        [int[]]$SplitIPv4Address = $_.Split(".")
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
$Version = "1.2.0"
$LatestVersionUrl = "https://raw.githubusercontent.com/ShuheiUda/Check-AzureIpAddress/master/LatestVersion.txt"
$IsAzureIp = $false
$Region = $null
$AzModule = $false

$LatestVersion = (Invoke-WebRequest $LatestVersionUrl -ErrorAction SilentlyContinue).Content
if($Version -lt $LatestVersion){
    Write-Warning "New version is available. ($LatestVersion)`nhttps://github.com/ShuheiUda/Check-AzureIpAddress"
}

Write-Debug "$(Get-Date) IpAddress: $IpAddresses"

# Module Check
if (Get-Module -ListAvailable -Name Az.Network){
    $AzModule = $true
}else{
    Write-Warning "Please install Az.Network module. (Link: https://github.com/Azure/azure-powershell/releases)"
}

# Address check
if((Validate-StringIPv4Address $IpAddresses) -eq $false){
    Write-Error "Please input source address correctly. (Example: 192.168.0.0)"
    Return
}

# Get IP address range and service tags from Download Center
$downloadUri = "https://www.microsoft.com/en-in/download/confirmation.aspx?id=56519"
$downloadPage = Invoke-WebRequest -Uri $downloadUri -UseBasicParsing 
$jsonFileUri = ($downloadPage.RawContent.Split('"') -like "https://*ServiceTags*")[0]
$response = Invoke-WebRequest -Uri $jsonFileUri
$jsonResponse = [System.Text.Encoding]::UTF8.GetString($response.Content) | ConvertFrom-Json

# Generate Service Tag Int Table
$SetviceTagTable = @()
$jsonResponse.values | foreach{
    $Tag = $_.Name
    $_.properties.addressPrefixes | foreach{
        # Check IP address
        $SetviceTagTable += [PSCustomObject]@{
            "Tag" = $Tag
            "StartAddress" = (ConvertTo-UInt32IPv4StartAddress $_)
            "EndAddress" = (ConvertTo-UInt32IPv4EndAddress $_)
        }
    }
}

# Generate BGP Community Int Table
if($AzModule){
    # Az.Network module needed
    $BgpCommunity = Get-AzBgpServiceCommunity
    $BgpCommunityTable = @()
    $BgpCommunity.BgpCommunities | foreach{
        $CommunityName = $_.CommunityName
        $CommunityValue = $_.CommunityValue
        $_.CommunityPrefixes | foreach{
            # Check IP address
            $BgpCommunityTable += [PSCustomObject]@{
                "CommunityName" = $CommunityName
                "CommunityValue" = $CommunityValue
                "StartAddress" = (ConvertTo-UInt32IPv4StartAddress $_)
                "EndAddress" = (ConvertTo-UInt32IPv4EndAddress $_)
            }
        }
    }
}

# Check Service Tag and BGP Community
foreach($IpAddress in $IpAddresses){
    $IsAzureIp = $false
    $TargetAddress = ConvertTo-UInt32IPv4Address $IpAddress
    $SetviceTagTable | foreach{
        # Check IP address
        if(Check-UInt32IPv4AddressRange -UInt32TargetIPv4Address $TargetAddress -UInt32StartIPv4Address $_.StartAddress -UInt32EndIPv4Address $_.EndAddress){
            Write-Host "$IpAddress is in $($_.Tag) service tags." -ForegroundColor Green
            $IsAzureIp = $true
        }
    }

    # Az.Network module needed
    if($AzModule){
        $BgpCommunityTable | foreach{
            # Check IP address
            if(Check-UInt32IPv4AddressRange -UInt32TargetIPv4Address $TargetAddress -UInt32StartIPv4Address $_.StartAddress -UInt32EndIPv4Address $_.EndAddress){
                Write-Host "$IpAddress is in $($_.CommunityName) ($($_.CommunityValue)) BGP community." -ForegroundColor Green
                $IsAzureIp = $true
            }
        }
    }

    if(!$IsAzureIp){
        Write-Host "$IpAddress is not in Azure." -ForegroundColor Red
        Start-Process "https://db-ip.com/$IpAddress"
    }
}
