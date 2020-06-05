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


function Search-Cache {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [string]$CacheFile,
    [string]$VcfProductVersion,
    [string]$severity,
    [string]$BundleSoftwareType,
    [string]$ImageType,
    [switch]$searchBundleElement
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
    
    if ($Match -ne $false -and $severity -ne ""){
      $Match = ($CachedManifest.severity -eq $severity)
      
    }

    
    if ($Match -ne $false -and $searchElement){
      $Match = Test-ContainsElement -bundleElements $CachedManifest.bundleElements -bundleSoftwareType $BundleSoftwareType -imageType $ImageType
    }
    if ($Match -eq $true){
      $MatchedResults += $CachedManifest
    }
  }

  return $MatchedResults
}
Export-ModuleMember -Function Search-Cache


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


function Get-BundleSoftwareTypes {
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

Export-ModuleMember Get-BundleSoftwareTypes


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
  param (
    [parameter(Position=1, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
    [psobject[]]$Bundles,
    [System.Management.Automation.PSCredential]
    $Credential = $(Get-Credential -Message "Enter your my.vmware.com credentials" ),
    [string]$Destination,
    [string]$ProxyAuthentication,
    [string[]]$ProxyBypass,
    [System.Management.Automation.PSCredential]
    $ProxyCredential,
    [Uri[]]$ProxyList,
    [string]$ProxyUsage
  )
    
  BEGIN{}
  PROCESS{
    $urls = $Bundles | Get-DownloadUrls
    foreach($url in $urls){
      write-host $url
      Start-BitsTransfer -Credential $Credential -TransferType Download -Authentication Basic -Destination $Destination -Source $url `
        -ProxyAuthentication $ProxyAuthentication -ProxyBypass $ProxyBypass -ProxyList $ProxyList -ProxyCredential $ProxyCredential -ProxyUsage $ProxyUsage
    }
  }
  END{}
}
Export-ModuleMember Start-BundleDownload