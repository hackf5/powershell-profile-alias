BeforeAll {
    Import-Module $PSScriptRoot/../src/HackF5.ProfileAlias/HackF5.ProfileAlias.psm1 -Force -Global
}

AfterAll {
    Remove-Module HackF5.ProfileAlias
}

Describe "Profile Alias: Groups" {
    It "Cannot remove default group" {
        Remove-ProfileAliasGroup "default"
        $Error.Count | Should -BeGreaterThan 0
    }

    It "Can set a profile group" {
        Set-ProfileAliasGroup "foo"
        Get-ProfileAliasGroup | Should -Be "foo"
    }

    It "Removing the current group reverts to the default group" {
        Set-ProfileAliasGroup "foo"
        Remove-ProfileAliasGroup "foo"
        Get-ProfileAliasGroup | Should -Be "default"
    }
}

Describe "Profile Alias: PowerShell style Aliases" {
    BeforeEach {
        Set-ProfileAliasGroup "test"
    }
    
    AfterEach {
        Remove-ProfileAliasGroup "test"
    }

    It "Can set a PowerShell style alias" {
        Set-ProfileAlias -Name e -Command echo
        (Get-ProfileAlias e).Command | Should -Be "echo"
        e foo | Should -Be "foo"
    }

    It "Can remove a PowerShell style alias" {
        Set-ProfileAlias -Name e -Command echo
        Remove-ProfileAlias e
        Get-Alias e
        $Error.Count | Should -BeGreaterThan 0
    }

    It "Cannot overwrite an existing alias without Force switch" {
        Set-Alias myalias echo
        Set-ProfileAlias myalias date
        $Error.Count | Should -BeGreaterThan 0
        Remove-Alias myalias
    }

    It "Can overwrite an existing alias with Force switch" {
        Set-Alias myalias date
        Set-ProfileAlias myalias echo -Force
        myalias hello | Should -Be "hello"
    }
}

Describe "Profile Alias: Bash style Aliases" {
    BeforeEach {
        Set-ProfileAliasGroup "test"
    }
    
    AfterEach {
        Remove-ProfileAliasGroup "test"
    }
}