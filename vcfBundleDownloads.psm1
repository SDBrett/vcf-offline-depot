function Test-ContainsElement {
  param (
    $BundleElements,
    $BundleSoftwareType,
    $ImageType
  )

  $Match = $false

  foreach ($BundleElement in $BundleElements){

    $Match = ($BundleElement.bundleSoftwareType -eq $BundleSoftwareType)

    if ($Match -ne $false -and $ImageType -ne ""){
      $Match = ($BundleElement.imageType -eq $ImageType)
    }

    if ($Match -eq $true){
      return $true
    }
  }
  return $false 
}


function Remove-Duplicates {
  param (
    $Array
  )
  $NewArray = @()

  foreach ($Item in $Array){
    if ($NewArray.IndexOf($Item) -lt -0){
      $NewArray += $Item
    }
  }
  return $NewArray
}


function Get-UniqueBundleElementNames {
  param (
    $BundleElements
  )

  $BundleNames = @()
  foreach ($Bundle in $BundleElements){
    $BundleNames += $Bundle.bundleSoftwareType
  }  
  
  return Remove-Duplicates($BundleNames)
}


function Get-NewBundleNames {
  param (
    $Manifests,
    $NewIDs
  )

  $BundleNames = @()

  foreach ($Manifest in $Manifests){
    $BundleID = Get-BundleID -manifest $Manifest
    if ($NewIDs.IndexOf($BundleID) -ge 0){
      $BundleName = Get-BundleName -manifest $Manifest
      $BundleNames += $BundleName
    }
  }
  return $BundleNames
}


function Get-BundleName {
  param (
    $Manifest
  )
  
  $Pos = $Manifest.IndexOf("bundle")
  $RightPart = $Manifest.Substring($Pos)
  return $RightPart.Trim()
}


function Get-BundleNames {
  param (
    $Manifests
  )

  $BundleNames = @()

  foreach ($Manifest in $Manifests){
    $BundleNames += Get-BundleName -manifest $Manifest
  }
  return $BundleNames
}


function Get-BundleIDs {
  param (
    $Manifests
  )

  $BundleIDs = @()

  foreach ($Manifest in $Manifests){
    $BundleIDs += Get-BundleID($Manifest)
  }
  return $BundleIDs
}


function Get-BundleID {
  param (
    $Manifest
  )

  $Pos = $Manifest.IndexOf("bundle")
  $Leftpart = $Manifest.Substring(0, ($Pos-1))
  return $Leftpart.Trim() 
}


function Get-CachedBundleIDs {
  param (
  $CachedManifests
)

  $BundleIDs = @()
  foreach ($Manifest in $CachedManifests){
    $BundleIDs += $Manifest.bundleId
  }
  return $BundleIDs
}

function Get-NewBundleIDs {
  param (
    $Manifests,
    $CachedManifests
  )

  $CachedBundleIDs = Get-CachedBundleIDs -cachedManifests $CachedManifests
  $RemoteBundleIDs = Get-BundleIDs -manifests $Manifests
  $NewIDs = Compare-Object -ReferenceObject $CachedBundleIDs -DifferenceObject $RemoteBundleIDs -PassThru
  return $NewIDs
}


function Build-Cache {
  <#
  .SYNOPSIS
    Provides functionality to cache and download VCF bundle manifests

  .DESCRIPTION
    Writes manifest content from the VMware bundle depot site to a local file which can then be used by the 'search-cache' function.
    'my.vmware.com' credential are required to access the bundle depot site.

  .PARAMETER Credentials
    Your 'my.vmware.com' credentials

  .PARAMETER CacheFilePath
    Cache file path, if the a cache file will be created if it does not already exist.

  .PARAMETER SpecifyProxy
    Use to specify if you are providing additional proxy information

  .PARAMETER Proxy 
    Specifies a proxy server for the request, rather than connecting directly to the internet resource. Enter the URI of a network proxy server.

  .PARAMETER ProxyUseDefaultCredentials
    Specifies a user account that has permission to use the proxy server that is specified by the Proxy parameter. The default is the current user.

  .PARAMETER ProxyCredential
    Indicates that the cmdlet uses the credentials of the current user to access the proxy server that is specified by the Proxy parameter.
    This parameter is valid only when the Proxy parameter is also used in the command. You can't use the ProxyCredential and ProxyUseDefaultCredentials parameters in the same command.

  .EXAMPLE
    # Build / Update 
    $Cred = get-credentials
    Build-Cache -credentials $Cred -cachefile c:\manifests.json
   
  #>
  [CmdletBinding()]
  param(
    [System.Management.Automation.PSCredential]
    $Credential = $(Get-Credential -Message "Enter your my.vmware.com credentials" ),
    [Parameter(Mandatory=$true)]
    [string]$CacheFile,
    [switch]$SpecifyProxy,
    [System.Management.Automation.PSCredential]$ProxyCredential,
    [switch]$ProxyUseDefaultCredentials,
    [Uri]$Proxy
  )
  
  $indexUrl = "https://depot.vmware.com/PROD2/evo/vmw/index.v3"
  $ManifestUrl = "https://depot.vmware.com/PROD2/evo/vmw/manifests/"
  $indexResponse = Invoke-WebRequest -Uri $indexUrl -Credential $Credential -SessionVariable 'Session'
  $Manifests = $indexResponse.content -split "`n" | % { $_.trim() }

  if (!(Test-Path $CacheFile)){
    write-host "creating cache file"
    New-Item $CacheFile -ItemType File
    $NewManifestNames = Get-BundleNames -manifests $Manifests
    $CachedManifests = @()
  }
  else{ # Get content from file
    $CachedManifests = Get-Content -Path $CacheFile | ConvertFrom-Json
    
    if ($Null -eq $CachedManifests) # Handle if file is empty
    {
      $CachedManifests = @() 
      $NewManifestNames = Get-BundleNames -manifests $Manifests
    }
    else 
    {
      $NewManifestIDs = Get-NewBundleIDs -manifests $Manifests -cachedManifests $CachedManifests
      if ($Null -eq $NewManifestIDs)
      {
        Write-Host "No new bundles found"
        Exit
      }
      $NewManifestNames = Get-NewBundleNames -manifests $Manifests -newIds $NewManifestIDs
    }
  }

  if (!($CachedManifests -is [array])){
    $CachedManifests = @($CachedManifests)
  }

  $i = 1
  foreach ($BundleName in $NewManifestNames){
    $uri = $ManifestUrl + $BundleName
    Write-Progress -Id 1 -Activity "Total Entries Found: $($NewManifestNames.Count)" -PercentComplete (($i/$NewManifestNames.Count)*100) -Status 'Getting Manifests'
    
    try{
     if($SpecifyProxy){
      $Response = Invoke-WebRequest -Uri $uri -Credential $Credential -SessionVariable $Session `
      -ProxyUseDefaultCredentials $ProxyUseDefaultCredentials -Proxy $Proxy -ProxyCredential $ProxyCredential
     }else{
      Response = Invoke-WebRequest -Uri $uri -Credential $Credential -SessionVariable $Session
     }
    $Obj = ConvertFrom-Json $Response.content

    $CachedManifests += $Obj 
    Set-Content -Path $CacheFile -Value (ConvertTo-Json $CachedManifests -Depth 5)
    $i ++
    }catch{
      
    }
  }

}
Export-ModuleMember -Function Build-Cache

function Get-BundleSoftwareTypes {
  <#
.SYNOPSIS
  Get bundle types available for a VCF version

.DESCRIPTION
  Returns a list of software types for the specified VCF version

.PARAMETER CacheFilePath
  Path to the cache file to search.

.PARAMETER VcfProductVersion
  Specify the vcfProductionVersion to search. This is a fuzzy search, so providing '3.9' will return results for 3.9.1
 
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [string]$CacheFile,
  [string]$VcfProductVersion
)


if (!(Test-Path $CacheFile)) 
{
  Write-Error "Cache file not found"
  exit
}

$BundleElements = @()
$CachedManifests = Get-Content -Path $CacheFile | ConvertFrom-Json
if (!($CachedManifests -is [array]))
{
  $CachedManifests = @($CachedManifests)
}

foreach ($CachedManifest in $CachedManifests){
  if ($Null -ne $CachedManifest.productVersion){    
    
    if ($CachedManifest.productVersion.indexOf($VcfProductVersion) -gt -1){
     
      foreach ($Bundle in $CachedManifest.bundleElements){
        
        $BundleElements += $Bundle
      }
    }
  }
}
return Get-UniqueBundleElementNames($BundleElements)
}

Export-ModuleMember -Function Get-BundleSoftwareTypes


function Get-DownloadUrls {
param (
  [parameter(Position=1, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
  [psobject[]]$Bundles
)

BEGIN{}
PROCESS{
  $ManifestUrlPrefix = "https://depot.vmware.com/PROD2/evo/vmw/manifests/"
  $BundleUrlPrefix = "https://depot.vmware.com/PROD2/evo/vmw/bundles/"

  
  $BundleNumber = $Bundles.tarfile.Split(".")[0]
  
  $ManifestUrl = $ManifestUrlPrefix + $BundleNumber + ".manifest"
  $SigUrl = $ManifestUrl + ".sig"
  $BundleUrl = $BundleUrlPrefix + $BundleNumber + ".tar"

  #$BundleURL not returned for testing only download functionality
  return @($ManifestUrl, $SigUrl)#, $BundleUrl)
  
}
END{}
}
Export-ModuleMember Get-BundleSoftwareTypes


function Start-BundleDownload {
<#
.SYNOPSIS
  Download VCF update and installation bundles

.DESCRIPTION
  Downloads VCF update and installation bundles from the VCF bundle depot, download includes manifest, manifest.sig and bundle .tar files.
  'my.vmware.com' credential are required to access the bundle depot site.

.PARAMETER Credentials
  Your 'my.vmware.com' credentials

.PARAMETER CacheFilePath
  Cache file path, if the a cache file will be created if it does not already exist.

.PARAMETER SpecifyProxy
  Use to specify if you are providing additional proxy information

.PARAMETER ProxyAuthentication 
  Specifies the authentication mechanism to use at the Web proxy.

.PARAMETER ProxyBypass
  Specifies a list of host names to use for a direct connection. The hosts in the list are tried in order until a successful connection is achieved. If you specify this parameter the cmdlet bypasses the proxy. If this parameter is used, the ProxyUsage parameter must be set to Override; otherwise, an error occurs.

.PARAMETER ProxyCredential
  Specifies the credentials to use to authenticate the user at the proxy. You can use the Get-Credential cmdlet to create a value for this parameter.

.PARAMETER ProxyList
  Specifies a list of proxies to use. The proxies in the list are tried in order until a successful connection is achieved. If this parameter is specified and ProxyUsage is set to a value other than Override, the cmdlet generates an error.

.PARAMETER ProxyUsage
  Specifies the proxy usage settings

.EXAMPLE
  # Download bundles
  $Cred = get-credentials
  Start-BundleDownload -Bundles $bundles -credentials $Cred -cachefile c:\manifests.json -Destination C:\vcf\bundles
 
#>
param (
  
  [parameter(Position=1, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)][psobject[]]$Bundles,
  [System.Management.Automation.PSCredential]$Credential = $(Get-Credential -Message "Enter your my.vmware.com credentials" ),
  [string]$Destination,
  [switch]$SpecifyProxy,
  [string]$ProxyAuthentication,
  [string[]]$ProxyBypass,
  [System.Management.Automation.PSCredential]$ProxyCredential,
  [Uri[]]$ProxyList,
  [string]$ProxyUsage
)
  
BEGIN{ 
  $DestArray = @()
}
PROCESS{
  $urls = $Bundles | Get-DownloadUrls
}
END{
  for ($i = 0; $i -lt $urls.Count; $i++){
    $DestArray += $Destination
  }

  if($SpecifyProxy){
    Start-BitsTransfer -Credential $Credential -TransferType Download -Authentication Basic -Destination $DestArray -Source $Urls `
    -ProxyAuthentication $ProxyAuthentication -ProxyBypass $ProxyBypass -ProxyList $ProxyList -ProxyCredential $ProxyCredential -ProxyUsage $ProxyUsage
  }else{
    Start-BitsTransfer -Credential $Credential -TransferType Download -Authentication Basic -Destination $DestArray -Source $Urls
  }
}
}
Export-ModuleMember Start-BundleDownload


function Search-Cache {
<#
.SYNOPSIS
  Search for bundle information in the manifest cache downloaded with 'Build-Cache'

.DESCRIPTION
  Search for bundle information in the manifest cache downloaded with 'Build-Cache'

.PARAMETER CacheFilePath
  Path to the cache file to search.

.PARAMETER VcfProductVersion
  Specify the vcfProductionVersion to search. This is a fuzzy search, so providing '3.9' will return results for 3.9.1

.PARAMETER Severity 
  Search for bundles matching this severity level

.PARAMETER BundleSoftwareType
  Search bundle elements for a specific software such as 'VCENTER' or 'NSXT'

.PARAMETER ImageType
  Specify the image type of 'Installation' or 'Update'

.PARAMETER SearchBundleElement
  Search for results within a bundle elements
 
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [string]$CacheFile,
  [string]$VcfProductVersion,
  [string]$Severity,
  [string]$BundleSoftwareType,
  [string]$ImageType,
  [switch]$SearchBundleElement
)


if (!(Test-Path $CacheFile)) 
{
  
  Write-Error "Cache file not found"
  exit
}

$MatchedResults = @()
$CachedManifests = Get-Content -Path $CacheFile | ConvertFrom-Json
if (!($CachedManifests -is [array]))
{
  $CachedManifests = @($CachedManifests)
}

foreach ($CachedManifest in $CachedManifests){

  if ($Null -ne $CachedManifest.productVersion){    
    $Match = ($CachedManifest.productVersion.indexOf($VcfProductVersion) -gt -1)
  }else{
    $Match = $false
  }
  
  if ($Match -ne $false -and $Severity -ne ""){
    $Match = ($CachedManifest.severity -eq $Severity)
    
  }
  
  if ($Match -ne $false -and $SearchElement){
    $Match = Test-ContainsElement -bundleElements $CachedManifest.bundleElements -bundleSoftwareType $BundleSoftwareType -imageType $ImageType
  }
  if ($Match -eq $true){
    $MatchedResults += $CachedManifest
  }
}

return $MatchedResults
}
Export-ModuleMember -Function Search-Cache


Function Convert-FromUnixDate ($UnixDate) {
[timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddMilliseconds($UnixDate))
}
Export-ModuleMember Convert-FromUnixDate