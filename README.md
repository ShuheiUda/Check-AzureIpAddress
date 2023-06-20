# Check-AzureIpAddress

## Description

This tool is checking IP address which you inputted is in Azure.

## Usage

1. Run PowerShell console
1. Run Check-AzureIpAddress script (ex. Check-AzureIpAddress.ps1 -IpAddresses 13.78.0.1)

## Parameter

* Required
  * IpAddresses

* Optional
  * UseOnlineCache

## Sample

```
.\Check-AzureIpAddress -IpAddresses  8.8.8.8, 13.78.0.1 -UseOnlineCache

8.8.8.8 is not in Azure.
13.78.0.1 is in AzureCloud.japaneast service tags.
13.78.0.1 is in AzureCloud service tags.
13.78.0.1 is in Azure Japan East (12076:51012) BGP community.

QueryAddress     Type             Tag                  CommunityName    CommunityValue   Prefix           LastAddress
---------------- ---------------- ----------------     ---------------- ---------------- ---------------- -----------------
13.78.0.1        ServiceTag       AzureCloud.japaneast                                   13.78.0.0/17     13.78.127.255
13.78.0.1        ServiceTag       AzureCloud                                             13.78.0.0/17     13.78.127.255
13.78.0.1        BgpCommunity                          Azure Japan East 12076:51012      13.78.0.0/18     13.78.63.255
```

## Lincense

Copyright (c) 2017 Syuhei Uda
Released under the [MIT license](http://opensource.org/licenses/mit-license.php )

## Release Notes

* 2023/06/20 Ver.1.3.0 : Add UseOnlineCache flag, temporary IPv6 error avoidance
* 2019/07/10 Ver.1.2.0 : Add BGP community, Optimization
* 2019/02/01 Ver.1.1.0 : Add Service Tags
* 2018/09/16 Ver.1.0.0 : Add dbip function
* 2017/05/01 Ver.0.9.0 (Preview Release) : 1st Release