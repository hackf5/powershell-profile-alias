BeforeAll {
    Import-Module $PSScriptRoot/../src/HackF5.ProfileAlias/HackF5.ProfileAlias.psm1 -Force -Global
}

AfterAll {
    Remove-Module HackF5.ProfileAlias -Force
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

    It "Removing the current group removes all aliases in that group" {
        Set-ProfileAliasGroup "test1"
        Set-ProfileAlias myalias1 echo
        Set-ProfileAlias myalias2 echo

        Remove-ProfileAliasGroup "test1"
        Get-Alias myalias1
        $Error.Count | Should -BeGreaterThan 0
        Get-Alias myalias2
        $Error.Count | Should -BeGreaterThan 0
    }

    It "Changing groups removes aliases in current group and adds aliases in new group" {
        Set-ProfileAliasGroup "test1"
        Set-ProfileAlias myalias1 echo

        Set-ProfileAliasGroup "test2"
        Set-ProfileAlias myalias2 echo

        Set-ProfileAliasGroup "test1"
        Get-Alias myalias2
        $Error.Count | Should -BeGreaterThan 0
        myalias1 foo | Should -Be "foo"

        Set-ProfileAliasGroup "test2"
        Get-Alias myalias1
        $Error.Count | Should -BeGreaterThan 0
        myalias2 foo | Should -Be "foo"

        Remove-ProfileAliasGroup "test1"
        Remove-ProfileAliasGroup "test2"
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
        Set-ProfileAlias -Name myalias1 -Command echo
        (Get-ProfileAlias | Where-Object Name -eq "myalias1").Command | Should -Be "echo"
        myalias1 foo | Should -Be "foo"
    }

    It "Can remove a PowerShell style alias" {
        Set-ProfileAlias -Name myalias1 -Command echo
        Remove-ProfileAlias myalias1
        Get-Alias myalias1
        $Error.Count | Should -BeGreaterThan 0
    }

    It "Cannot overwrite an existing alias without Force switch" {
        Set-Alias myalias1 echo -Scope Global
        Set-ProfileAlias myalias1 date
        $Error.Count | Should -BeGreaterThan 0
    }

    It "Can overwrite an existing alias with Force switch" {
        Set-Alias myalias1 date -Scope Global
        Set-ProfileAlias myalias1 echo -Force
        myalias1 hello | Should -Be "hello"
    }
}

Describe "Profile Alias: Bash style Aliases" {
    BeforeEach {
        Set-ProfileAliasGroup "test"
    }
    
    AfterEach {
        Remove-ProfileAliasGroup "test"
    }

    It "Can set a Bash style alias" {
        Set-ProfileAlias -Name myalias1 -Command 'echo "hello world"' -Bash
        myalias1 | Should -Be "hello world"
    }

    It "Can set a Bash style alias with args" {
        Set-ProfileAlias -Name myalias1 -Command 'echo "hello $(#{0}) world"' -Bash
        myalias1 lovely | Should -Be "hello lovely world"
    }

    It "Can set a Bash style alias with args and remaining args" {
        Set-ProfileAlias -Name myalias1 -Command 'echo "$(#{1}) hello $(#{0}) world $(#{:*})"' -Bash
        myalias1 lovely and nice to meet you | Should -Be "and hello lovely world nice to meet you"
    }

    It "Can set a Bash style alias with star args" {
        Set-ProfileAlias -Name myalias1 -Command 'echo "hello $(#{*}) world"' -Bash
        myalias1 lovely shiny | Should -Be "hello lovely shiny world"
    }
}