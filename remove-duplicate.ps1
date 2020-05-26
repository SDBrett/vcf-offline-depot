$cachedManifests = Get-Content -Path $cacheFile | ConvertFrom-Json

$uniqureManifests = @()
foreach ($manifest in $cachedManifests){

  $duplicate = $false

    foreach($uniqureManifest in $uniqureManifests){
      if ($manifest.bundleId -eq $uniqureManifest.bundleId){
        write-host -ForegroundColor yellow $manifest.bundleId
        write-host -ForegroundColor green $uniqureManifest.bundleId
        $duplicate = $true
      }
    }
  


    if ($duplicate -eq $false){
    $uniqureManifests += $manifest
    }
}



Set-Content -Path $caclefile2 -Value (ConvertTo-Json $uniqureManifests -Depth 5)