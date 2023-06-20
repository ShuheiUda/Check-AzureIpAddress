<#
.SYNOPSIS
This tool is checking IP address which you inputted is in Azure.

.PARAMETER IpAddress
IP address which you want to check.

.EXAMPLE
Check-AzureIpAddress.ps1 -IpAddress 13.78.0.1, 13.78.0.2

.NOTES
    Name    : Check-AzureIpAddress.ps1
    GitHub  : https://github.com/ShuheiUda/Check-AzureIpAddress
    Version : 1.3.0
    Author  : Syuhei Uda
#>
Param(
    [Parameter(Mandatory=$true)][array]$IpAddresses,
    [switch]$UseOnlineCache

)

function Validate-StringIpAddress{
Param(
    [Parameter(Mandatory=$true)]$IPv4Addresses
)
    # IPv4
    if($_ -ne $null -and !$_.Contains(":")){
        $IPv4Addresses | foreach{
            $SplitIPv4AddressPrefix = $_.Split("/")
            [int[]]$SplitIPv4Address = $SplitIPv4AddressPrefix[0].Split(".")
            if($SplitIPv4Address.Count -ne 4){
                Return $false
            }else{
                for($octet = 0; $octet -lt 4; $octet++){
                    if(($SplitIPv4Address[$octet] -ge 0) -and ($SplitIPv4Address[$octet] -le 255)){
                    }else{
                        Return $false
                    }
                }
            }
        }
    }

    # IPv6
    else
    {
        ### need a fix for IPv6 ###
        Return $false
    }
    Return $true
}

function ConvertTo-UInt32IPv4Address{
Param(
    [Parameter(Mandatory=$true)]$IPv4Address
)

    [uint32]$UInt32IPv4Address = 0
    [uint32[]]$SplitIPv4Address = $IPv4Address.Split(".")
    if($SplitIPv4Address.Count -ne 4){
        Return $false
    }else{
        for($octet = 0; $octet -lt 4; $octet++){
            if(($SplitIPv4Address[$octet] -ge 0) -and ($SplitIPv4Address[$octet] -le 255)){
                $UInt32IPv4Address += ($SplitIPv4Address[$octet]*([math]::Pow(256,3-$octet)))
                #$UInt32IPv4Address += ($SplitIPv4Address[$octet] -shl 8*(3-$octet))
            }else{
                Return $false
            }
        }
    }
    Return $UInt32IPv4Address
}

function ConvertTo-UInt32IPv4FirstAddress{
Param(
    [Parameter(Mandatory=$true)]$IPv4AddressRange
)

    $SplitIPv4AddressRange = $IPv4AddressRange.Split("/")
    [int]$SplitIPv4AddressPrefix = $SplitIPv4AddressRange[1]

    if(($SplitIPv4AddressPrefix -ge 0) -and ($SplitIPv4AddressPrefix -le 32)){
        Return (ConvertTo-UInt32IPv4Address $SplitIPv4AddressRange[0])
    }else{
        Write-Error "IPv4 Address Range is not correctly."
        Return -1
    }
}

function ConvertTo-UInt32IPv4LastAddress{
Param(
    [Parameter(Mandatory=$true)]$IPv4AddressRange
)

    $SplitIPv4AddressRange = $IPv4AddressRange.Split("/")
    [int]$SplitIPv4AddressPrefix = $SplitIPv4AddressRange[1]

    if(($SplitIPv4AddressRange[1] -ne $null) -and ($SplitIPv4AddressPrefix -ge 0) -and ($SplitIPv4AddressPrefix -le 32)){
        Return ((ConvertTo-UInt32IPv4Address $SplitIPv4AddressRange[0]) + [math]::Pow(2, 32 - $SplitIPv4AddressPrefix) - 1)
    }else{
        Write-Error "IPv4 Address Range is not correctly."
        Return -1
    }
}

function ConvertTo-StringIPv4LastAddress{
Param(
    [Parameter(Mandatory=$true)]$IPv4AddressRange
)

    $IPv4LastAddress = ConvertTo-UInt32IPv4LastAddress $IPv4AddressRange
    if($IPv4LastAddress -ne -1){
        Return ((($IPv4LastAddress -shr 24) % 256), (($IPv4LastAddress -shr 16) % 256), (($IPv4LastAddress -shr 8) % 256), ($IPv4LastAddress % 256)) -join "."
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
$Version = "1.3.0"
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
<#
### need a fix for IPv6 ###
if((Validate-StringIpAddress $IpAddresses) -eq $false){
    Write-Error "Please input source address correctly. (Example: 192.168.0.0)"
    Return
}#>


$AzurePrefixTable = @()

# Use Online Cache
if($UseOnlineCache){
    $AzurePrefixTableUrl = "https://azureiprange.blob.core.windows.net/checkip/AzurePrefixTable.csv"
    $AzurePrefixTableResponse = Invoke-WebRequest -Uri $AzurePrefixTableUrl -UseBasicParsing
    $AzurePrefixTable = [System.Text.Encoding]::UTF8.GetString($AzurePrefixTableResponse.Content) | ConvertFrom-Csv

}else{
    # Get IP address range and service tags from Download Center
    $downloadUri = "https://www.microsoft.com/en-in/download/confirmation.aspx?id=56519"
    $downloadPage = Invoke-WebRequest -Uri $downloadUri -UseBasicParsing 
    $jsonFileUri = ($downloadPage.RawContent.Split('"') -like "https://*ServiceTags*")[0]
    $response = Invoke-WebRequest -Uri $jsonFileUri
    $jsonResponse = [System.Text.Encoding]::UTF8.GetString($response.Content) | ConvertFrom-Json

    # Generate Service Tag Int Table
    $jsonResponse.values | foreach{
        $Tag = $_.Name
        $_.properties.addressPrefixes | foreach{
            # IPv4
            if(Validate-StringIpAddress $_){
                $AzurePrefixTable += [PSCustomObject]@{
                    "Type" = "ServiceTag"
                    "Tag" = $Tag
                    "CommunityName" = $null
                    "CommunityValue" = $null
                    "Prefix" = $_
                    "FirstAddress" = (ConvertTo-UInt32IPv4FirstAddress $_)
                    "LastAddress" = (ConvertTo-UInt32IPv4LastAddress $_)
                }
            }
            # IPv6
            else
            {
                ### need a fix for IPv6 ###
            }
        }
    }

    # Generate BGP Community Int Table
    if($AzModule){
        # Az.Network module needed
        $BgpCommunity = Get-AzBgpServiceCommunity
        $BgpCommunity.BgpCommunities | foreach{
            $CommunityName = $_.CommunityName
            $CommunityValue = $_.CommunityValue
            $_.CommunityPrefixes | foreach{
                # IPv4
                if(Validate-StringIpAddress $_){
                    $AzurePrefixTable += [PSCustomObject]@{
                        "Type" = "BgpCommunity"
                        "Tag" = $null
                        "CommunityName" = $CommunityName
                        "CommunityValue" = $CommunityValue
                        "Prefix" = $_
                        "FirstAddress" = (ConvertTo-UInt32IPv4FirstAddress $_)
                        "LastAddress" = (ConvertTo-UInt32IPv4LastAddress $_)
                    }
                }
                # IPv6
                else
                {
                    ### need a fix for IPv6 ###
                }
            }
        }
    }
}

# Check Service Tag and BGP Community
$ResultTable = @()
foreach($IpAddress in $IpAddresses){
    $IsAzureIp = $false
    $TargetAddress = ConvertTo-UInt32IPv4Address $IpAddress
    $AzurePrefixTable | where Type -eq "ServiceTag" | foreach{
        # Check IP address
        if(Check-UInt32IPv4AddressRange -UInt32TargetIPv4Address $TargetAddress -UInt32StartIPv4Address $_.FirstAddress -UInt32EndIPv4Address $_.LastAddress){
            Write-Host "$IpAddress is in $($_.Tag) service tags." -ForegroundColor Green
            $ResultTable += [PSCustomObject]@{
                "QueryAddress    " = $IpAddress
                "Type            " = $_.Type
                "Tag             " = $_.Tag
                "CommunityName   " = $null
                "CommunityValue  " = $null
                "Prefix          " = $_.Prefix
                "LastAddress      " = ConvertTo-StringIPv4LastAddress $_.Prefix
            }
            $IsAzureIp = $true
        }
    }

    # Az.Network module needed
    if($AzModule -or $UseOnlineCache){
        $AzurePrefixTable | where Type -eq "BgpCommunity" | foreach{
            # Check IP address
            if(Check-UInt32IPv4AddressRange -UInt32TargetIPv4Address $TargetAddress -UInt32StartIPv4Address $_.FirstAddress -UInt32EndIPv4Address $_.LastAddress){
                Write-Host "$IpAddress is in $($_.CommunityName) ($($_.CommunityValue)) BGP community." -ForegroundColor Green
                $ResultTable += [PSCustomObject]@{
                    "QueryAddress    " = $IpAddress
                    "Type            " = $_.Type
                    "Tag             " = $null
                    "CommunityName   " = $_.CommunityName
                    "CommunityValue  " = $_.CommunityValue
                    "Prefix          " = $_.Prefix
                    "LastAddress      " = ConvertTo-StringIPv4LastAddress $_.Prefix
                }
                $IsAzureIp = $true
            }
        }
    }

    if(!$IsAzureIp){
        Write-Host "$IpAddress is not in Azure." -ForegroundColor Red
        Start-Process "https://db-ip.com/$IpAddress"
    }
}
$ResultTable | Format-Table
