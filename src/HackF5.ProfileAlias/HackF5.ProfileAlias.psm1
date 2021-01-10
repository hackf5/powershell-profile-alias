function Get-ProfileAliasDataDirectory {
    $path = [System.Environment]::GetFolderPath(
        [System.Environment+SpecialFolder]::LocalApplicationData,
        [System.Environment+SpecialFolderOption]::Create)
    $path = Join-Path -Path $path -ChildPath "pshw\alias"
    New-Item -ItemType Directory -Force -Path  $path 
}

function Get-ProfileAliasJsonPath {
    $path = Join-Path -Path (Get-ProfileAliasDataDirectory) -ChildPath "profile-alias.json"

    if (-not (Test-Path -Path $path)) {
        Set-Content -Path $path -Value "{ `"aliases`": [] }"
    }

    return $path
}

function Get-ProfileAliasModulePath {
    return Join-Path -Path (Get-ProfileAliasDataDirectory) -ChildPath "profile-alias-generated.psm1"
}

function Remove-ProfileAliasModule {
    if ($null -ne (Get-Module 'profile-alias-generated'))
    {
        Remove-Module 'profile-alias-generated'
    }
}

function Import-ProfileAliasModule {
    $jsonPath = Get-ProfileAliasJsonPath
    $modulePath = Get-ProfileAliasModulePath

    $json = Get-Content $jsonPath | ConvertFrom-Json

    $module = ""
    foreach ($alias in $json.aliases) 
    {   
        if (-not $alias.Extended) {
            Set-Alias -Name $($alias.name) -Value $($alias.command) -Scope Global -Option ReadOnly
            continue
        }

        $functionName = "Publish-ProfileAlias_$($alias.name)"
        $module += "function $functionName { $($alias.command) `$args }`n"
        $module += "Set-Alias -Name $($alias.name) -Value $functionName -Scope Global -Option ReadOnly"
    }

    Set-Content -Path $modulePath -Value $module
    Import-Module $modulePath -Global -Force
}

function Set-ProfileAlias {
    <#
        .SYNOPSIS
            Sets an alias that is loaded as part of your profile.

        .PARAMETER Name
            The name of the alias

        .PARAMETER Command
            The command to alias.
            
            This can either be any valid input to a standard PowerShell alias.

            Or it can be a string containing an executable object along with a predefined
            set of arguments.

        .PARAMETER Extended
            A switch that defaults to false.
            
            When false a standard PowerShell alias will be registered.

            When true a bash style alias will be created.

        .PARAMETER Force
            A switch that defaults to false.

            When false if an alias with that name already exists then an error will be raised.

            When true the alias will always be created or overwritten if it can be.

        .EXAMPLE
            Set-ProfileAlias -Name setp -Command Set-ProfileAlias

            Create an alias to the Set-ProfileAlias method so that you can now
            use `setp -Name foo -Command Get-Item`. But seriously don't do this.

            A better use is to create an alias for an executable that is not currently
            on your path and where you don't want to add the entire directory. There is
            a registry hack that supposedly purports to do this, but good luck with
            that.

            Set-ProfileAlias -Name laws -Command "docker run --network mynet --rm -it -v $env:userprofile\.aws\localstack:/root/.aws amazon/aws-cli --endpoint-url=http://localstack:4566" -Extended

            Creates the alias `laws` that allows you run the dockerized aws-cli against your 
            dockerized localstack (yes, this is the posterboy for why PowerShell needs bash style aliases).

            So you can execute: laws sns list-topics
            And you will list all of the sns topics in your local stack.

        .LINK
            https://github.com/hackf5/powershell-profile-alias

    #>
    param (
        [Parameter(Mandatory=$true)] [String] $Name,
        [Parameter(Mandatory=$true)] [String] $Command,
        [switch] $Extended,
        [switch] $Force
    )

    $systemAlias = Get-Alias | Where-Object {$_.Name -eq $Name}
    if (($null -ne $systemAlias) -and (-not $Force))
    {
        Write-Error "Alias '$Name' already exists, to overwrite use the -Force flag."
        Write-Output $systemAlias
        return
    }

    $jsonPath = Get-ProfileAliasJsonPath
    $json = Get-Content $jsonPath | ConvertFrom-Json
    $json.aliases = @($json.aliases | Where-Object {$_.name -ne $Name})

    $alias = "" | Select-Object name, command, extended
    $alias.name = $Name
    $alias.command = $Command
    $alias.extended = $Extended.IsPresent

    $json.aliases += $alias

    ConvertTo-Json $json -Depth 10 | Set-Content $jsonPath -Force

    Import-ProfileAliasModule

    Write-Output $alias
}

function Remove-ProfileAlias {
    <#
        .SYNOPSIS
            Removes a profile alias.

        .PARAMETER Name
            The name of the profile alias to remove.

        .EXAMPLE
            Remove-ProfileAlias -Name alias1

        .NOTES
            If no profile alias with this name exists then an error is raised. 
    #>
    param (
        [Parameter(Mandatory=$true)] [String] $Name
    )

    $jsonPath = Get-ProfileAliasJsonPath
    $json = Get-Content $jsonPath | ConvertFrom-Json
    if ($null -eq ( Get-Alias | Where-Object {$_.Name -eq $Name}))
    {
        Write-Error "Alias '$Name' does not exist."
        return
    }

    if ($null -eq ($json.aliases | Where-Object {$_.name -eq $Name})) {
        Write-Error "Alias '$Name' is an alias, but not a profile alias. Use Remove-Alias instead."
        return
    }

    Remove-Alias -Name $Name -Force

    $json.aliases = @($json.aliases | Where-Object {$_.name -ne $Name})

    ConvertTo-Json $json | Set-Content $jsonPath -Force

    Import-ProfileAliasModule
}

function Get-ProfileAlias {
    <#
        .SYNOPSIS
            Lists all of the profile aliases that are currently active.

        .OUTPUTS
            An array of { name, command, extended } where
                - name: the name of the alias
                - command: the command that is executed when the alias is invoked
                - extended: a value indicating whether this is a bash style alias

        .EXAMPLE
            Get-ProfileAlias
                Gets all currently registered aliases

            Get-ProfileAlias | Where-Object {$_.name -eq "alias1"}
                Gets the alias with name "alias1" or returns null if no such alias exists.

        .NOTES
            The profile alias module can be used for easily registering persistent PowerShell 
            style aliases, or for registering persistent bash style aliases.

            They are persistent in the sense that they are loaded as part of your profile,
            so are available between sessions.

            A bash style alias is one that takes an arbitrary string as it's alias which is
            then executed, along with any additional arguments, when the alias is invoked.
            These are identified by extended=true.

            A PowerShell style alias, by comparison, is a rather limited beast that essentially
            allows a command, executable, etc... to be referred to by another name. They provide
            some utility, but are rather limited.
    #>
    
    $jsonPath = Get-ProfileAliasJsonPath
    $json = Get-Content $jsonPath | ConvertFrom-Json
    Write-Output $json.aliases
}

Export-ModuleMember Set-ProfileAlias
Export-ModuleMember Remove-ProfileAlias
Export-ModuleMember Get-ProfileAlias

Import-ProfileAliasModule