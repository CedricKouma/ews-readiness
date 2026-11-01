#Requires -Version 7.2
# Offline self-test for the free EWS Quick Check. No network, no tenant.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$script:pass = 0; $script:fail = 0
function Assert([bool]$c, [string]$m) { if ($c) { $script:pass++; Write-Host "  PASS $m" } else { $script:fail++; Write-Host "  FAIL $m" } }
$s = Join-Path $root 'Test-EwsTenantState.ps1'
$asOf = [datetime]'2026-10-31'

Write-Host '[1] Static read-only check (same AST rules as the full kit)'
$tok = $null; $err = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($s, [ref]$tok, [ref]$err)
Assert ($err.Count -eq 0) 'script parses without syntax error'
$names = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true) | ForEach-Object { $_.GetCommandName() })
$writeVerbs = '^(Set|New|Remove|Add|Update|Enable|Disable|Grant|Revoke|Clear|Install|Uninstall|Invoke|Send|Start|Stop|Restart|Register|Unregister|Move|Rename|Reset|Restore|Suspend|Resume|Approve|Deny|Publish|Request|Submit|Sync|Upgrade)-'
$allowed = 'Connect-ExchangeOnline','Get-OrganizationConfig','Disconnect-ExchangeOnline','Get-Content','ConvertFrom-Json','Where-Object','ForEach-Object','Select-Object','Get-Date','Set-StrictMode'
Assert (@($names | Where-Object { -not $_ }).Count -eq 0) 'no dynamic command invocation'
Assert (@($names | Where-Object { $_ -and $_ -ne 'Set-StrictMode' -and $_ -match $writeVerbs }).Count -eq 0) 'no write verb (Set-StrictMode is local parser strictness only)'
Assert (@($names | Where-Object { $_ -and $_ -notin $allowed }).Count -eq 0) "every command is on the allow-list ($(($names | Select-Object -Unique) -join ', '))"

Write-Host '[2] Offline verdicts'
$cases = @{ 'org-null.json' = 'NullDefault'; 'org-false.json' = 'Disabled'; 'org-empty.json' = 'EnabledEmptyList'; 'org-list.json' = 'EnabledWithList'; 'org-unknown.json' = 'EnabledListUnknown' }
foreach ($k in $cases.Keys) {
    $o = @(& $s -OrgJsonPath (Join-Path $PSScriptRoot $k) -AsOf $asOf)
    Assert (($o -join "`n") -match "State: $($cases[$k])" -and ($o -join "`n") -match "État : $($cases[$k])") "$k -> $($cases[$k]) (FR + EN)"
}
$o = (& $s -OrgJsonPath (Join-Path $PSScriptRoot 'org-list.json') -AsOf $asOf) -join "`n"
Assert ($o -match '2 application\(s\)' -and $o -match '2 app\(s\)') 'allow-list count shown'
Assert ($o -match "Jours avant la coupure complète d'EWS \(1er avril 2027\) : 152" -and $o -match '\(April 1, 2027\): 152') 'days left from 2026-10-31 = 152'
$fo = (& $s -OrgJsonPath (Join-Path $PSScriptRoot 'org-null.json') -AsOf $asOf -Language fr) -join "`n"
Assert ($fo -match 'RISQUE ÉLEVÉ' -and $fo -notmatch 'HIGH RISK') '-Language fr prints French only'

Write-Host '[3] Live path against MOCKED cmdlets'
$global:LiteCalls = [System.Collections.Generic.List[string]]::new()
function global:Connect-ExchangeOnline { param($ShowBanner, $UserPrincipalName) $global:LiteCalls.Add('Connect-ExchangeOnline') }
function global:Disconnect-ExchangeOnline { param([switch]$Confirm) $global:LiteCalls.Add('Disconnect-ExchangeOnline') }
function global:Get-OrganizationConfig { param([switch]$RetrieveEwsOperationAccessPolicy)
    $global:LiteCalls.Add("Get-OrganizationConfig:$RetrieveEwsOperationAccessPolicy")
    if ($RetrieveEwsOperationAccessPolicy) { [pscustomobject]@{ EwsAllowedAppIDs = 'D3590ED6-52B3-4102-AEFF-AAD2292AB01C; 11111111-1111-4111-8111-111111111111' } }
    else { [pscustomobject]@{ EwsEnabled = $true } } }
foreach ($t in 'Set-OrganizationConfig', 'Set-CASMailbox') { Set-Item "function:global:$t" ([scriptblock]::Create("`$global:LiteCalls.Add('WRITE:$t'); throw 'write attempted'")) }
$o = (& $s -AsOf $asOf) -join "`n"
$c = @($global:LiteCalls)
Assert (-not ($c -match '^WRITE:')) 'no write cmdlet called'
Assert (@($c | Where-Object { $_ -notmatch '^(Get-|Connect-|Disconnect-)' }).Count -eq 0) "only Get/Connect/Disconnect called ($($c.Count) calls)"
Assert ($c[-1] -eq 'Disconnect-ExchangeOnline') 'session always disconnected'
Assert ($o -match 'State: EnabledWithList' -and $o -match '2 app\(s\)') 'live list parsed (semicolon, uppercase normalized)'

Write-Host ""
Write-Host "RESULT: $($script:pass) passed, $($script:fail) failed"
if ($script:fail) { exit 1 }
