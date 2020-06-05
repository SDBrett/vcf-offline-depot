function contains-element {
  param (
    $bundleElements,
    $bundleSoftwareType,
    $imageType
  )

  $match = $false

  foreach ($bundleElement in $bundleElements){

    $match = ($bundleElement.bundleSoftwareType -eq $bundleSoftwareType)

    if ($match -ne $false -and $imageType -ne ""){
      $match = ($bundleElement.imageType -eq $imageType)
    }

    if ($match -eq $true){
      return $true
    }
  }
  return $false 
}


function search-cache {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [string]$cacheFile,
    [string]$vcfProductVersion,
    [string]$severity,
    [string]$bundleSoftwareType,
    [string]$imageType,
    [switch]$searchBundleElement
  )
  

  if (!(Test-Path $cacheFile)) 
  {
    
    Write-Error "Cache file not found"
    exit
  }

  $matchedResults = @()
  $cachedManifests = Get-Content -Path $cacheFile | ConvertFrom-Json
  if (!($cachedManifests -is [array]))
  {
    $cachedManifests = @($cachedManifests)
  }

  foreach ($cachedManifest in $cachedManifests){

    if ($null -ne $cachedManifest.productVersion){    
      $match = ($cachedManifest.productVersion.indexOf($vcfProductVersion) -gt -1)
    }else{
      $match = $false
    }
    
    if ($match -ne $false -and $severity -ne ""){
      $match = ($cachedManifest.severity -eq $severity)
      
    }

    
    if ($match -ne $false -and $searchElement){
      $match = contains-element -bundleElements $cachedManifest.bundleElements -bundleSoftwareType $bundleSoftwareType -imageType $imageType
    }
    if ($match -eq $true){
      $matchedResults += $cachedManifest
    }
  }

  return $matchedResults
}
Export-ModuleMember -Function search-cache

function remove-duplicates {
  param (
    $array
  )
  $newArray = @()

  foreach ($item in $array){
    if ($newArray.IndexOf($item) -lt -0){
      $newArray += $item
    }
  }
  return $newArray
}

function get-UniqueBundleElementNames {
  param (
    $bundleElements
  )

  $bundleNames = @()
  foreach ($bundle in $bundleElements){
    $bundleNames += $bundle.bundleSoftwareType
  }  
  
  return remove-duplicates($bundleNames)
}

function get-bundleSoftwareTypes {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [string]$cacheFile,
    [string]$vcfProductVersion
  )
  

  if (!(Test-Path $cacheFile)) 
  {
    
    Write-Error "Cache file not found"
    exit
  }

  $bundleElements = @()
  $cachedManifests = Get-Content -Path $cacheFile | ConvertFrom-Json
  if (!($cachedManifests -is [array]))
  {
    $cachedManifests = @($cachedManifests)
  }

 

  foreach ($cachedManifest in $cachedManifests){
    if ($null -ne $cachedManifest.productVersion){    
      
      if ($cachedManifest.productVersion.indexOf($vcfProductVersion) -gt -1){
       
        foreach ($bundle in $cachedManifest.bundleElements){
          
          $bundleElements += $bundle
        }
      }
    }
  }

  return get-UniqueBundleElementNames($bundleElements)
}

Export-ModuleMember get-bundleSoftwareTypes

function get-DownloadUrls {
  param (
    [parameter(Position=1, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
    [psobject[]]$bundles
  )
  
  BEGIN{}
  PROCESS{
    $manifestUrlPrefix = "https://depot.vmware.com/PROD2/evo/vmw/manifests/"
    $bundleUrlPrefix = "https://depot.vmware.com/PROD2/evo/vmw/bundles/"

    
    $bundleNumber = $bundles.tarfile.Split(".")[0]
    
    $manifestUrl = $manifestUrlPrefix + $bundleNumber + ".manifest"
    $sigUrl = $manifestUrl + ".sig"
    $bundleUrl = $bundleUrlPrefix + $bundleNumber + ".tar"

    #$bundleURL not returned for testing only download functionality
    return @($manifestUrl, $sigUrl)#, $bundleUrl)
    
  }
  END{}
}
Export-ModuleMember get-bundleSoftwareTypes

function download-bundle {
  param (
    [parameter(Position=1, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
    [psobject[]]$bundles,
    [System.Management.Automation.PSCredential]
    $Credential = $(Get-Credential -Message "Enter your my.vmware.com credentials" ),
    [string]$destination,
    [string]$ProxyAuthentication,
    [string[]]$ProxyBypass,
    [System.Management.Automation.PSCredential]
    $ProxyCredential,
    [Uri[]]$ProxyList,
    [string]$ProxyUsage
  )
    
  BEGIN{}
  PROCESS{
    $urls = $bundles | get-DownloadUrls
    foreach($url in $urls){
      write-host $url
      Start-BitsTransfer -Credential $Credential -TransferType Download -Authentication Basic -Destination $destination -Source $url `
        -ProxyAuthentication $ProxyAuthentication -ProxyBypass $ProxyBypass -ProxyList $ProxyList -ProxyCredential $ProxyCredential -ProxyUsage $ProxyUsage
    }
  }
  END{}
}
Export-ModuleMember download-bundle