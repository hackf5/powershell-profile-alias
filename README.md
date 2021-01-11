# PowerShell Profile Alias

[![powershellgallery](https://img.shields.io/powershellgallery/v/HackF5.ProfileAlias)](https://www.powershellgallery.com/packages/HackF5.ProfileAlias)
[![downloads](https://img.shields.io/powershellgallery/dt/HackF5.ProfileAlias.svg?label=downloads)](https://www.powershellgallery.com/packages/PowerShellForGitHub)
[![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/hackf5/powershell-profile-alias)](https://github.com/hackf5/powershell-profile-alias)
[![downloads](https://img.shields.io/badge/license-MIT-green)](https://github.com/hackf5/powershell-profile-alias/blob/master/LICENSE)

Haven't you ever wanted to write [bash aliases](https://opensource.com/article/19/7/bash-aliases) in PowerShell? You know, like all the cool kids do on their overpriced Mac books with the stickers on them that say things like *Reagan Bush '84*? That sticker's supposed to be ironic, but I know that if I had that sticker, I'd be showing it with pride (good straight Republican man pride).

Just imagine if you could do this?

```powershell
> Set-ProfileAlias laws "docker run --network crypto_crypto-net --rm -it -v `$env:userprofile\.aws\\localstack:/root/.aws amazon/aws-cli --endpoint-url=http://localstack:4566" -Bash
> laws sqs list-queues
    QueueUrls:
    - http://localhost:4566/000000000000/my_queue
    - http://localhost:4566/000000000000/queue1
```

How awesome would it be? The possibilities would be truly endless. Well imagine no longer, because now you can have them.

## Installation

The module is available from the [PowerShell Gallery](https://www.powershellgallery.com/packages/HackF5.ProfileAlias), so all you need to do is install it through PowerShell and register it into your  `$profile`.

```powershell
> Import-Module HackF5.ProfileAlias
> Register-ProfileAliasInProfile
```

You need to register it because the aliases are only available while the module is loaded, however since PowerShell lazy loads its modules, if the module isn't loaded as part of the  `$profile` it wouldn't be available until you'd called one of it's functions.

All the registration does is add an explicit module load to your `$profile`. The `Register-ProfileAliasInProfile` is idempotent, so don't worry if you accidentally call it twice.

## Operations

The module supports the standard operations you would expect:

- Create and Update via `Set-ProfileAlias`
- Remove via `Remove-ProfileAlias`
- Get via `Get-ProfileAlias`

## Create and Update

PowerShell has `New-Alias` and `Set-Alias`, which they do exactly the same thing with some nuance around the behavior of `-Force`. This module only has a `Set-` function.

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
- `Bash` - a switch that indicates this is a `bash`-like alias.
- `Force` - overwrites an existing alias if one is present.
- `Confirm` - prompts for confirmation before creating the alias.
- `Verbose` - outputs verbose messages.

### Examples

Creating a PowerShell-like alias.

```powershell
Set-ProfileAlias wget Invoke-WebRequest
wget http://hackf5.io
```
