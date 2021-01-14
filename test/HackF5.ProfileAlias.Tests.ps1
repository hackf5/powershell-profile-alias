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

    It "Can set a profile group" {
        Set-ProfileAliasGroup "foo"
        Get-ProfileAliasGroup | Should -Be "foo"
    }
}

Describe "Profile Alias: Aliases" {
    BeforeEach {
        Set-ProfileAliasGroup "test"
    }
    
    AfterEach {
        Remove-ProfileAliasGroup "test"
    }

    It "Set alias" {
        Set-ProfileAlias -Name np -Command notepad.exe
        (Get-ProfileAlias np).Command | Should -Be "notepad.exe"
    }
}