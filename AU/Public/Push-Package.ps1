function Push-Package() {
    param(
        [switch] $All
    )
    $api_key =  if (Test-Path api_key) { Get-Content api_key }
                elseif (Test-Path (Join-Path '..' 'api_key')) { Get-Content (Join-Path '..' 'api_key') }
                elseif ($Env:api_key) { $Env:api_key }
    $Nexus_ApiKey = if (Test-Path Nexus_ApiKey) { Get-Content Nexus_ApiKey }
                elseif (Test-Path (Join-Path '..' 'Nexus_ApiKey')) { Get-Content (Join-Path '..' 'Nexus_ApiKey') }
                elseif ($Env:Nexus_ApiKey) { $Env:Nexus_ApiKey }

    $push_url =  if ($Env:au_PushUrl) { $Env:au_PushUrl } else { 'https://push.chocolatey.org' }
                     
    $force_push = if ($Env:au_ForcePush) { '--force' } else { '' }

    $packages = Get-ChildItem *.nupkg | Sort-Object -Property CreationTime -Descending

    if (!$All) { $packages = $packages | Sort-Object CreationTime -Descending | Select-Object -First 1 }
    if (!$packages) { throw 'There is no nupkg file in the directory'}
    if ($api_key) {
        $packages | ForEach-Object { choco push $_.Name --api-key $api_key --source $push_url $force_push }
    } else {
        $packages | ForEach-Object { choco push $_.Name --source $push_url $force_push }
    }

    $Nexus_PushUrl = if ($Env:Nexus_PushUrl) { $Env:Nexus_PushUrl }
    if ($Nexus_ApiKey) {
        $packages | ForEach-Object { choco push $_.Name --api-key $Nexus_ApiKey --source $Nexus_PushUrl $force_push}
    } else {
        $packages | ForEach-Object { choco push $_.Name --source $Nexus_PushUrl $force_push }
    }
}