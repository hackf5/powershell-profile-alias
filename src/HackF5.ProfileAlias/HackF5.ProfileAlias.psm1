New-Variable GeneratedProfielAliasModuleName -Visibility Private -Option Constant `
    -Value "HackF5.ProfileAlias.Generated"

New-Variable ProfileAliasJsonName -Visibility Private -Option Constant `
    -Value "HackF5.ProfileAlias.json"

New-Variable ProfileAliasDataDirectory -Visibility Private -Option Constant `
    -Value (Join-Path -ChildPath "pshw\alias" `
        -Path ([System.Environment]::GetFolderPath(
        [System.Environment+SpecialFolder]::LocalApplicationData,
        [System.Environment+SpecialFolderOption]::Create)))

New-Variable DefaultProfileAliasGroup -Visibility Private -Option Constant -Value "default"

$script:ProfileAliasGroup = $DefaultProfileAliasGroup

function Get-ProfileAliasDataDirectory {
    param (
        [Parameter()] [String] $Group
    )

    $Group = -not [string]::IsNullOrWhiteSpace($Group) ? $Group : $ProfileAliasGroup
    $path = Join-Path -Path $ProfileAliasDataDirectory -ChildPath $Group
    
    return New-Item -ItemType Directory -Force -Path  $path -Confirm:$false
}

function Get-ProfileAliasGroup {
    return $script:ProfileAliasGroup
}

function Set-ProfileAliasGroup {
    param (
        [Parameter()] [String] $Group
    )

    $value = -not [string]::IsNullOrWhiteSpace($Group) ? $Group : $DefaultProfileAliasGroup
    $script:ProfileAliasGroup = $value

    Update-ProfileAliasModule
}

function Remove-ProfileAliasGroup {
    param (
        [Parameter(Mandatory=$true)] [String] $Group
    )

    if ($Group -eq $DefaultProfileAliasGroup)
    {
        Write-Error "You cannot remove the default group."
        return
    }

    $path = Get-ProfileAliasDataDirectory $Group
    if (Test-Path $path)
    {
        $null = Remove-Item -Force $path -Recurse 
    }

    if ($script:ProfileAliasGroup -eq $Group)
    {
        Write-Information "Reverting to default profile alias group."
        $null = Set-ProfileAliasGroup $DefaultProfileAliasGroup
    }
}

function Get-ProfileAliasJsonPath {
    return Join-Path -Path (Get-ProfileAliasDataDirectory) -ChildPath $ProfileAliasJsonName
}

function Save-ProfileAlias {
    param (
        [Parameter(Mandatory = $true)] [AllowEmptyCollection()] [Array] $Aliases
    )

    ConvertTo-Json $Aliases -AsArray -Depth 8 | Set-Content (Get-ProfileAliasJsonPath) -Force -Confirm:$false
    Update-ProfileAliasModule
}

function Get-ProfileAliasModulePath {
    return Join-Path -Path (Get-ProfileAliasDataDirectory) -ChildPath "$GeneratedProfielAliasModuleName.psm1"
}

function Get-CommandFunctionBody {
    param (
        [Parameter(Mandatory=$true)] [string] $Command
    )

    $pattern = '#{1}\{(\d+)\}'

    $maxIndex = -1
    foreach ($m in [regex]::Matches($Command, $pattern)) {
        $index = [System.Convert]::ToInt32($m.Groups[1].Value)
        if ($index -gt $maxIndex) {
            $maxIndex = $index
        }
    }
    
    $maxIndex += 1

    return  $Command -replace $pattern, '$args[$1]' -replace '#{1}\{\*\}', '$args' -replace '#{1}\{:\*\}', "`$args[$maxIndex..10000]"
}

function Update-ProfileAliasModule {
    $moduleBuilder = New-Object System.Text.StringBuilder("# auto-generated by HackF5.ProfileAlias")
    $onRemoveBuilder = New-Object System.Text.StringBuilder("`$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {")

    foreach ($alias in Get-ProfileAlias) {   
        $null = $moduleBuilder.AppendLine();
        $null = $moduleBuilder.AppendLine();

        if ($alias.Bash) {
            $functionName = "Publish-ProfileAliasGenerated_$($alias.name)"
            $null = $moduleBuilder.AppendLine("function $functionName { $($alias.body) }");
            $null = $moduleBuilder.AppendLine("Set-Alias -Name $($alias.name) -Value $functionName -Scope Global -Option ReadOnly -Force");
        }
        else {
            $null = $moduleBuilder.AppendLine("Set-Alias -Name $($alias.name) -Value $($alias.command) -Scope Global -Option ReadOnly -Force");
        }

        $null = $onRemoveBuilder.AppendLine();
        $null = $onRemoveBuilder.AppendLine("Remove-Alias -Name $($alias.name) -Force -ErrorAction SilentlyContinue");
    }

    $null = $onRemoveBuilder.AppendLine("}");
    $null = $moduleBuilder.AppendLine();
    $null = $moduleBuilder.AppendLine();
    $null = $moduleBuilder.Append($onRemoveBuilder);

    $modulePath = Get-ProfileAliasModulePath
    $null = Set-Content -Path $modulePath -Value $moduleBuilder.ToString() -Force -Confirm:$false
    $null = Import-Module $modulePath -Global -Force
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

        .PARAMETER Bash
            This is a bash style alias.

        .PARAMETER Force
            Any existing alias with the same name will be overwritten.

        .PARAMETER Confirm
            Prompts you for confirmation before setting the alias.

        .PARAMETER Verbose
            Displays detailed output.

        .EXAMPLE
            Set-ProfileAlias -Name setp -Command Set-ProfileAlias

            Create an alias to the Set-ProfileAlias method so that you can now
            use `setp -Name foo -Command Get-Item`. But seriously don't do this.

            A better use is to create an alias for an executable that is not currently
            on your path and where you don't want to add the entire directory. There is
            a registry hack that supposedly purports to do this, but good luck with
            that.

            Set-ProfileAlias -Name laws -Command "docker run --network mynet --rm -it -v `$env:userprofile\.aws\localstack:/root/.aws amazon/aws-cli --endpoint-url=http://localstack:4566" -Bash

            Creates the alias `laws` that allows you run the dockerized aws-cli against your 
            dockerized localstack (yes, this is the posterboy for why PowerShell needs bash style aliases).

            So you can execute: laws sns list-topics
            And you will list all of the sns topics in your local stack.

        .LINK
            https://github.com/hackf5/powershell-profile-alias
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)] [String] $Name,
        [Parameter(Mandatory = $true)] [String] $Command,
        [switch] $Bash,
        [switch] $Force
    )

    $systemAlias = Get-Alias | Where-Object { $_.Name -eq $Name }
    if (($null -ne $systemAlias) -and (-not $Force)) {
        Write-Error "Alias '$Name' already exists, to overwrite use the -Force flag."
        return
    }

    $body = $Bash ? (Get-CommandFunctionBody $Command) : [string]::Empty

    $aliases = @(Get-ProfileAlias | Where-Object { $_.name -ne $Name })

    $alias = [PSCustomObject]@{ name = $Name; command = $Command; body= $body; bash = $Bash.IsPresent }
    $aliases += $alias

    if ($PSCmdlet.ShouldProcess($jsonPath , "Set profile alias $Name in ")) {
        Save-ProfileAlias $aliases
        Write-Verbose "Set profile alias $Name to $Command"
        return $alias
    }
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

        .LINK
            https://github.com/hackf5/powershell-profile-alias
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName, ValueFromPipeline)] [String] $Name
    )

    if ($null -eq (Get-Alias | Where-Object { $_.Name -eq $Name })) {
        Write-Error "Alias '$Name' does not exist."
        return
    }

    $aliases = Get-ProfileAlias
    if ($null -eq ($aliases | Where-Object { $_.name -eq $Name })) {
        Write-Error "Alias '$Name' is not a profile alias. Use Remove-Alias instead."
        return
    }

    $aliases = @($aliases | Where-Object { $_.name -ne $Name })

    if ($PSCmdlet.ShouldProcess($jsonPath, "Remove profile alias $Name from ")) {
        Save-ProfileAlias $aliases
        Write-Verbose "Removed profile alias $Name"
    }
}

function Get-ProfileAlias {
    <#
        .SYNOPSIS
            Lists all of the profile aliases that are currently active.

        .OUTPUTS
            An array of { name, command, bash } where
                - name: the name of the alias
                - command: the command that is executed when the alias is invoked
                - bash: a value indicating whether this is a bash style alias

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
            These are identified by bash=true.

            A PowerShell style alias, by comparison, is a rather limited beast that essentially
            allows a command, executable, etc... to be referred to by another name. They provide
            some utility, but are rather limited.

        .LINK
            https://github.com/hackf5/powershell-profile-alias
    #>
    
    $path = Get-ProfileAliasJsonPath
    return (Test-Path -Path $path) ? (Get-Content $path | ConvertFrom-Json) : @()
}

function Get-ProfileAliasRegisterCommand {
    $builder = New-Object System.Text.StringBuilder("")
    $null = $builder.AppendLine("# region profile alias initialize")
    $null = $builder.AppendLine("Import-Module -Name HackF5.ProfileAlias -Force -Global -ErrorAction SilentlyContinue")
    $null = $builder.AppendLine("# end region")

    return $builder.ToString().Trim()
}

function Register-ProfileAliasInProfile {
    <#
        .SYNOPSIS 
            Registers the HackF5.ProfileAlias module into a PowerShell profile.

        .DESCRIPTION
            Your aliases are registered by this module when the module first loads, however
            PowerShell's auto-loading strategy is lazy, meaning that the module is not
            loaded until it is first used. Since you want your aliases always available
            then it is necessary to explicitly load the module as part of profile initialization.

            Invoking this command appends an explicit load request to your profile.

        .PARAMETER Path
            The path to your profile.
            
            When not set this defaults to the currently loaded profile, which is probably what
            you want.

        .PARAMETER Verbose
            Displays detailed output.

        .PARAMETER Confirm
            Prompts you for confirmation before registering the module in your profile.

        .EXAMPLE
            Register-ProfileAliasInProfile
                Adds an explicit load module request to your current profile.

        .NOTES
            This function is idempotent, so calling it multiple times will not result in multiple registrations.

        .LINK
            https://github.com/hackf5/powershell-profile-alias
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter()] [String] $Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        $Path = $profile
    }

    $profileContent = (Test-Path $Path) ? (Get-Content -Path $Path -Raw) ?? [string]::Empty : [sring]::Empty
    $command = Get-ProfileAliasRegisterCommand
    if ($profileContent.Contains($command)) {
        Write-Verbose -Message "The HackF5.ProfileAlias module has already been registered in profile: $Path"
        return
    }

    $profileContent = $profileContent.TrimEnd()

    $builder = New-Object System.Text.StringBuilder($profileContent)
    if ($builder.Length -gt 0) {
        $null = $builder.AppendLine()
        $null = $builder.AppendLine()
    }

    $null = $builder.AppendLine($command)
    
    if ($PSCmdlet.ShouldProcess("$Path" , "Register HackF5.ProfileAlias in ")) {
        Set-Content -Path $Path -Value $builder.ToString().TrimEnd() -NoNewline -Confirm:$false
        Write-Verbose -Message "Registered HackF5.ProfileAlias in profile: $Path"
    }
}

function Unregister-ProfileAliasInProfile {
    <#
        .SYNOPSIS 
            Unregisters the HackF5.ProfileAlias module from a PowerShell profile.

        .DESCRIPTION
            Invoking this command removes the code appended to your profile by Register-ProfileAliasInProfile.

        .PARAMETER Path
            The path to your profile.
            
            When not set this defaults to the currently loaded profile, which is probably what
            you want.

        .PARAMETER Verbose
            Displays detailed output.

        .PARAMETER Confirm
            Prompts you for confirmation before unregistering the module from your profile.

        .EXAMPLE
            Unregister-ProfileAliasInProfile
                Removes the code appended to your profile by Register-ProfileAliasInProfile.

        .NOTES
            This function is idempotent, so calling it multiple times will not result in multiple unregistrations.

        .LINK
            https://github.com/hackf5/powershell-profile-alias
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter()] [string] $Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        $Path = $profile
    }

    if (-not (Test-Path $Path)) {
        Write-Verbose -Message "The profile $Path does not exists."
        return
    }

    $command = Get-ProfileAliasRegisterCommand
    $profileContent = (Get-Content -Path $Path -Raw).Replace($command, [string]::Empty).TrimEnd()

    if ($PSCmdlet.ShouldProcess("$Path" , "Register HackF5.ProfileAlias in ")) {
        Set-Content -Path $profile -Value  $profileContent -NoNewline -Confirm:$false
        Write-Verbose -Message "Unregistered HackF5.ProfileAlias in profile: $Path"
    }
}

$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    Remove-Module $GeneratedProfielAliasModuleName -Force -Confirm:$false -ErrorAction SilentlyContinue
}

Export-ModuleMember Get-ProfileAliasDataDirectory
Export-ModuleMember Set-ProfileAliasDataDirectory
Export-ModuleMember Get-ProfileAlias
Export-ModuleMember Set-ProfileAlias
Export-ModuleMember Remove-ProfileAlias
Export-ModuleMember Register-ProfileAliasInProfile
Export-ModuleMember Unregister-ProfileAliasInProfile
Export-ModuleMember Get-ProfileAliasGroup
Export-ModuleMember Set-ProfileAliasGroup
Export-ModuleMember Remove-ProfileAliasGroup

Update-ProfileAliasModule