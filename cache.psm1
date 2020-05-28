function contains-element {
  param (
    $bundleElements,
    $bundleSoftwareType,
    $bundleElementVersion,
    $imageType
  )

  $match = $false

  foreach ($bundleElement in $bundleElements){

    $match = ($bundleElement.bundleSoftwareType -eq $bundleSoftwareType)

    if ($match -ne $false -and $bundleElementVersion -ne "" ){
      $match = ($bundleElement.bundleElementVersion.IndexOf($bundleElementVersion) -gt -1)
    }
  
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
    [string]$bundleElementVersion,
    [string]$bundleSoftwareType,
    [string]$imageType
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

    if ($match -ne $false){
      $match = contains-element -bundleElements $cachedManifest.bundleElements -bundleSoftwareType $bundleSoftwareType -bundleElementVersion $bundleElementVersion -imageType $imageType

    }
    if ($true -eq $match){
      $matchedResults += $cachedManifest
    }
  }

  return $matchedResults
}

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

Export-ModuleMember -Function 'search-cache', get-bundleSoftwareTypes