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
   $Cred = get-credentials
   Build-Cache -credentials $Cred -cachefile c:\manifests.cache
   
#>


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


function Get-BundleDetails {
  param (
    $BundleNames,
    $ManifestUrl,
    [System.Management.Automation.PSCredential]$Credentials
  )

  $Manifests = @()
  foreach ($BundleName in $BundleNames){
    $uri = $ManifestUrl + $BundleName
    $Response = Invoke-WebRequest -Uri $uri -Credential $Credentials
    $Manifests += $Response.content
  }
  return $Manifests
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
  [CmdletBinding()]
  param(
    [System.Management.Automation.PSCredential]
    $Credential = $(Get-Credential -Message "Enter your my.vmware.com credentials" ),
    [Parameter(Mandatory=$true)]
    [string]$CacheFile
  )
  
  $indexUrl = "https://depot.vmware.com/PROD2/evo/vmw/index.v3"
  $ManifestUrl = "https://depot.vmware.com/PROD2/evo/vmw/manifests/"
  $indexResponse = Invoke-WebRequest -Uri $indexUrl -Credential $Credential
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
    $Response = Invoke-WebRequest -Uri $uri -Credential $Credential
    $Obj = ConvertFrom-Json $Response.content

    $CachedManifests += $Obj 
    Set-Content -Path $CacheFile -Value (ConvertTo-Json $CachedManifests -Depth 5)
    $i ++
    }catch{
      
    }
  }

}
Export-ModuleMember -Function 'Build-Cache'