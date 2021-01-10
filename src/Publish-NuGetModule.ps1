function Step-Version {
    param (
        [Parameter(Mandatory = $true)]
        [System.Version]
        $version
    )

    $major = $version.Major
    $minor = $version.Minor + 1
    New-Object System.Version($major, $minor, 0, 0)
}

function Publish-NuGetModule {
    $moduleName = "HackF5.ProfileAlias"
    $modulePath = "$PSScriptRoot/$moduleName"

    Import-Module $modulePath -Force
    $module = Get-Module HackF5.ProfileAlias
    Remove-Module $moduleName
    Update-ModuleManifest -Path "$modulePath/HackF5.ProfileAlias.psd1" -ModuleVersion (Step-Version $module.Version)
    
    $apiKey = Get-Content -Path "$PSScriptRoot/../.secret/hackf5-powershell-api.key" -Raw
    Publish-Module -Path $modulePath -NuGetApiKey $apiKey
}

Publish-NuGetModule