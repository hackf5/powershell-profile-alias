# PowerShell Profile Alias

[![powershellgallery](https://img.shields.io/powershellgallery/v/HackF5.ProfileAlias)](https://www.powershellgallery.com/packages/HackF5.ProfileAlias)
[![downloads](https://img.shields.io/powershellgallery/dt/HackF5.ProfileAlias.svg?label=downloads)](https://www.powershellgallery.com/packages/PowerShellForGitHub)
[![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/hackf5/powershell-profile-alias)](https://github.com/hackf5/powershell-profile-alias)
[![downloads](https://img.shields.io/badge/license-MIT-green)](https://github.com/hackf5/powershell-profile-alias/blob/master/LICENSE)

Haven't you ever wanted to write [bash aliases](https://opensource.com/article/19/7/bash-aliases) in PowerShell? You know, like all the cool kids do on their overpriced Mac books with the stickers on them that say things like *Reagan Bush '84*?

Just imagine if you could do this?

```powershell
> Set-ProfileAlias laws -Command (-join(
    'docker run --network crypto_crypto-net --rm -it ',
    '-v $env:userprofile\.aws\\localstack:/root/.aws amazon/aws-cli ',
    '--endpoint-url=http://localstack:4566 #{*}')) -Bash
> laws sqs list-queues
    QueueUrls:
    - http://localhost:4566/000000000000/my_queue
    - http://localhost:4566/000000000000/queue1
```

How awesome would it be? The possibilities are truly endless.

## Installation

The module is available from the [PowerShell Gallery](https://www.powershellgallery.com/packages/HackF5.ProfileAlias). Once installed it needs to be registered with your  `$profile`.

```powershell
> Install-Module HackF5.ProfileAlias
> Register-ProfileAliasInProfile
```

All the registration does is add an explicit `Import-Module` to your `$profile`. This is necessary because the aliases are only available while the module is loaded. Since PowerShell lazy loads its modules, this is the only way to ensure that the aliases are always available.

## Operations

The module supports the standard operations you would expect:

- Create and Update via `Set-ProfileAlias`
- Remove via `Remove-ProfileAlias`
- Get via `Get-ProfileAlias`

## Create and Update

PowerShell has `New-Alias` and `Set-Alias`, which do the same thing with some nuance around the behavior of `-Force`. This module only has a `Set-` function.

After creating or updating an alias it is persisted between sessions.

If your module is registered with more than one `$profile` then the alias will be available to those other profiles too.

### Function

```powershell
Set-Alias
    [-Name] <string>
    [-Command] <string>
    [-Bash]
    [-Force]
    [-Confirm]
    [-Verbose]
```

- `Name` - the name of the alias.
- `Command` - either something that you would pass to `Set-Alias -Value`, or a something more `bash`-like.
- `Bash` - a switch that indicates whether this is a `bash`-style alias.
- `Force` - overwrites an existing alias if one is present.
- `Confirm` - prompts for confirmation before creating the alias.
- `Verbose` - outputs verbose messages.

### Arguments

In order for the `bash`-style aliases to be really useful you need to be able to inject arguments into them. This is done using the following placeholders:

- `#{N}` - Injects argument `N` into the command. The first argument is `#{0}`.
- `#{*}` - Injects all of the arguments into the command.
- `#{:*}` - Injects all remaining arguments into the command. So if `#{0}` and `#{1}` are referenced in the command then this will inject arguments `#{2}, #{3}` and so on. Note that if you only reference `#{0}` and `#{2}` and forget `#{1}` this will inject `#{3}, #{4}` and so on. It won't warn you, it isn't very sophisticated.

Currently there is no way of escaping these arguments, so if you have a command where you actually need this syntax you are currently out of luck. Raise an issue stating why this is a problem for you and I will take a look at adding some escape mechanism. Better still, send me a pull request with the fix.

If you want to use these arguments inside a string, then you need to use double quoted `""` strings and wrap them inside a `$()` statement. For example:

```powershell
> Set-ProfileAlias echoecho 'echo "$(#{0})$(#{0})"' -Bash
> echoecho foo

foofoo
```

### Examples

Create a PowerShell-style alias.

```powershell
> Set-ProfileAlias wget Invoke-WebRequest
> wget http://hackf5.io
```

Create a bash-style alias without any arguments.

```powershell
> Set-ProfileAlias sayhello 'echo "hello world!"' -Bash
> sayhello

hello world!
```

Create a bash-style alias with a single argument.

```powershell
> Set-ProfileAlias e 'echo #{0}' -Bash
> e foo

foo
```

Create a bash-style alias with multiple arguments.

```powershell
> Set-ProfileAlias arr '@(#{0}, #{1}, #{2})' -Bash
> arr foo bar moo

foo
bar
moo
```

Create a bash style alias that uses remaining arguments.

```powershell
> Set-ProfileAlias snip '#{:*} | where { $_ -ne #{0} }' -Bash
> snip foo bar moo foo bar moo foo

bar
moo
bar
moo
```

Create a bash style alias that uses all of the arguments in one place.

```powershell
> Set-ProfileAlias echoall '#{*} | echo' -Bash
> echoall foo bar moo

foo
bar
moo
```

## How it works

In order for the `bash`-style aliases to work, the command needs to be wrapped in a function. For example in the original `docker` alias at the top of the readme, the function could look something like this:

```powershell
function Invoke-AwsDocker {
    docker run --network crypto_crypto-net --rm -it `
        -v $env:userprofile\.aws\\localstack:/root/.aws amazon/aws-cli `
        --endpoint-url=http://localstack:4566 $args
}
```

Note the use of the catch all `$args` variable that is an array containing all of the arguments that the function was called with.

Now I can create an alias to this function.

```powershell
Set-Alias laws Invoke-AwsDocker
```

And that's about it.

The problem of course is that defining one line functions and aliasing them in your modules folder is actually a real pain. It certainly isn't something you can do directly from the command line without significant effort.

What this module does is save the commands it is given, modifying them slightly to inject the `$args` variable in such a way that it is available in nested script-blocks. Then from this saved list it builds a module that contains functions that wrap the commands along with all of the aliases against which these commands are registered. When the module is removed it removes all of the aliases that it has registered.

Each time `Set-ProfileAlias` or `Remove-ProfileAlias` is called the old module is removed and a new one is built and loaded.
