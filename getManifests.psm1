<#
 .Synopsis
  Provides functionality to cache and download VCF bundle manifests

 .Description
  Provides functionality to cache and download VCF bundle manifests

 .Parameter Credentials
  Your my.vmware.com credentials

 .Parameter CacheFilePath
  Path of existing file to use as cache, if file does not exist it will be created


 .Example
   # Build / Update 
   $cred = get-credentials
   build-cache -credentials $cred -cachefile c:\manifests.cache
   
#>

function Get-NewBundleNames {
  param (
    $manifests,
    $newIDs
  )

  $bundleNames = @()

  foreach ($manifest in $manifests){
    $bundleID = Get-BundleID -manifest $manifest
    if ($newIDs.IndexOf($bundleID) -ge 0){
      $bundleName = Get-BundleName -manifest $manifest
      $bundleNames += $bundleName
    }
  }
  return $bundleNames
}

function Get-BundleName {
  param (
    $manifest
  )
  
  $pos = $manifest.IndexOf("bundle")
  $rightPart = $manifest.Substring($pos)
  return $rightPart.Trim()

}

function Get-BundleNames {
  param (
    $manifests
  )

  $bundleNames = @()

  foreach ($manifest in $manifests){
    $bundleNames += Get-BundleName -manifest $manifest
  }
  return $bundleNames
}

function Get-BundleIDs {
  param (
    $manifests
  )

  $bundleIDs = @()

  foreach ($manifest in $manifests){
    $bundleIDs += Get-BundleID($manifest)
  }

  return $bundleIDs

}

function Get-BundleID {
  param (
    $manifest
  )

  $pos = $manifest.IndexOf("bundle")
  $leftpart = $manifest.Substring(0, ($pos-1))
  return $leftpart.Trim()
  
}

function Get-BundleDetails {
  param (
    $bundleNames,
    $manifestUrl,
    [System.Management.Automation.PSCredential]$credentials
  )

  $manifests = @()
  foreach ($bundleName in $bundleNames){
    $uri = $manifestUrl + $bundleName
    $response = Invoke-WebRequest -Uri $uri -Credential $credentials
    $manifests += $response.content
  }
  return $manifests
}

function Get-CachedBundleIDs {
  param (
  $cachedManifests
)

  $bundleIDs = @()
  foreach ($manifest in $cachedManifests){
    $bundleIDs += $manifest.bundleId
  }

  return $bundleIDs

}

function Get-NewBundleIDs {
  param (
    $manifests,
    $cachedManifests
  )

  $cachedBundleIDs = Get-CachedBundleIDs -cachedManifests $cachedManifests
  $remoteBundleIDs = Get-BundleIDs -manifests $manifests

  $newIDs = Compare-Object -ReferenceObject $cachedBundleIDs -DifferenceObject $remoteBundleIDs -PassThru

 return $newIDs
  
}


function build-cache {
  [CmdletBinding()]
  param(
    [System.Management.Automation.PSCredential]
    $Credential = $(Get-Credential -Message "Enter your my.vmware.com credentials" ),
    [Parameter(Mandatory=$true)]
    [string]$cacheFile
  )
  
  $indexUrl = "https://depot.vmware.com/PROD2/evo/vmw/index.v3"
  $manifestUrl = "https://depot.vmware.com/PROD2/evo/vmw/manifests/"
  $indexResponse = Invoke-WebRequest -Uri $indexUrl -Credential $Credential
  $manifests = $indexResponse.content -split "`n" | % { $_.trim() }

  if (!(Test-Path $cacheFile)) 
  {
    write-host "creating cache file"
    New-Item $cacheFile -ItemType File
    $newManifestNames = Get-BundleNames -manifests $manifests
    $cachedManifests = @()
  }
  else # Get content from file
  {
    $cachedManifests = Get-Content -Path $cacheFile | ConvertFrom-Json
    
    if ($null -eq $cachedManifests) # Handle if file is empty
    {
      $cachedManifests = @() 
      $newManifestNames = Get-BundleNames -manifests $manifests
    }
    else 
    {
      $newManifestIDs = Get-NewBundleIDs -manifests $manifests -cachedManifests $cachedManifests
      if ($null -eq $newManifestIDs)
      {
        Write-Host "No new bundles found"
        Exit
      }
      $newManifestNames = Get-NewBundleNames -manifests $manifests -newIds $newManifestIDs
    }
  }

  if (!($cachedManifests -is [array]))
  {
    $cachedManifests = @($cachedManifests)
  }

  $i = 1
  foreach ($bundleName in $newManifestNames){
    $uri = $manifestUrl + $bundleName
    Write-Progress -Id 1 -Activity "Total Entries Found: $($newManifestNames.Count)" -PercentComplete (($i/$newManifestNames.Count)*100) -Status 'Getting Manifests'
    
    try{
    $response = Invoke-WebRequest -Uri $uri -Credential $credential
    $obj = ConvertFrom-Json $response.content

    $cachedManifests += $obj 
    Set-Content -Path $cacheFile -Value (ConvertTo-Json $cachedManifests -Depth 5)
    $i ++
    }catch{
      
    }
  }

}

Export-ModuleMember -Function 'build-cache'