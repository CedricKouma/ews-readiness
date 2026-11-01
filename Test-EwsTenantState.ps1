#Requires -Version 7.2
<#
.SYNOPSIS
    EWS Quick Check (free, read-only) / Vérification rapide EWS (gratuite, lecture seule) - Rigoutech inc. - v0.1.0-beta
    Reads 2 tenant-level settings in Exchange Online (EwsEnabled, EwsAllowedAppIDs) and says, in French and English,
    whether EWS apps are at risk of being blocked. It does NOT list which apps use EWS: that is what the full kit does.
    Lit 2 réglages du locataire Exchange Online (EwsEnabled, EwsAllowedAppIDs) et dit, en français et en anglais,
    si les applications EWS risquent d'être bloquées. Elle ne liste PAS les applications qui utilisent EWS : c'est le rôle de la trousse complète.
.DESCRIPTION
    Cmdlets called / commandes appelées : Connect-ExchangeOnline, Get-OrganizationConfig, Disconnect-ExchangeOnline. Nothing else.
    Role / rôle : Entra "Global Reader" (Exchange "View-Only Organization Management") expected to be enough, not confirmed /
    prévu comme suffisant, non confirmé.
    Offline mode / mode hors ligne : -OrgJsonPath reads a saved org.json instead of connecting.
    -Device : device-code sign-in (Connect-ExchangeOnline -Device), for servers without a browser / connexion par code d'appareil.
.EXAMPLE
    pwsh -File ./Test-EwsTenantState.ps1 -UserPrincipalName reader@contoso.com
.EXAMPLE
    pwsh -File ./Test-EwsTenantState.ps1 -OrgJsonPath ./tests/org-null.json
#>
[CmdletBinding()]
param(
    [string]$UserPrincipalName,
    [string]$OrgJsonPath,
    [switch]$Device,
    [ValidateSet('fr', 'en', 'both')][string]$Language = 'both',
    [datetime]$AsOf = (Get-Date)
)
Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
$cutoff = [datetime]'2027-04-01'   # EWS fully disabled (Microsoft Learn, deprecation-of-ews-exchange-online)
$days = [int][math]::Ceiling(($cutoff.Date - $AsOf.Date).TotalDays)

if ($OrgJsonPath) {
    $o = Get-Content -LiteralPath $OrgJsonPath -Raw | ConvertFrom-Json
    $ewsEnabled = $o.EwsEnabled
    $listRead = [bool]$o.EwsAllowedAppIDsRead
    $ids = @($o.EwsAllowedAppIDs | Where-Object { $_ })
} else {
    $p = @{ ShowBanner = $false }
    if ($UserPrincipalName) { $p.UserPrincipalName = $UserPrincipalName }
    if ($Device) { $p.Device = $true }   # device-code sign-in, for servers without a browser
    Connect-ExchangeOnline @p
    try {
        $org = Get-OrganizationConfig
        $ewsEnabled = $org.EwsEnabled
        $listRead = $true; $ids = @()
        try {
            $raw = (Get-OrganizationConfig -RetrieveEwsOperationAccessPolicy).EwsAllowedAppIDs
            $ids = @(((@($raw) | ForEach-Object { [string]$_ }) -join ',') -split '[,;]' | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ } | Select-Object -Unique)
        } catch { $listRead = $false }
    } finally { Disconnect-ExchangeOnline -Confirm:$false }
}

$state = if ($null -eq $ewsEnabled) { 'NullDefault' }
         elseif (-not [bool]$ewsEnabled) { 'Disabled' }
         elseif (-not $listRead) { 'EnabledListUnknown' }
         elseif ($ids.Count -eq 0) { 'EnabledEmptyList' }
         else { 'EnabledWithList' }

$fr = @{
    NullDefault        = "RISQUE ÉLEVÉ si des applications utilisent encore EWS : EwsEnabled n'est pas défini (Null). Microsoft le passe à False pendant le déploiement d'octobre 2026, ce qui bloque EWS pour toutes les applications."
    Disabled           = "EWS est désactivé (EwsEnabled = False) : toute application qui dépend encore d'EWS est déjà bloquée."
    EnabledListUnknown = "EWS est activé, mais la liste EwsAllowedAppIDs n'a pas pu être lue (droits ou version du module). Impossible de conclure."
    EnabledEmptyList   = "RISQUE ÉLEVÉ si des applications utilisent encore EWS : EWS est activé, mais la liste EwsAllowedAppIDs est vide. Depuis le 10 octobre 2026, seules les applications de cette liste peuvent utiliser EWS."
    EnabledWithList    = "EWS est activé avec $($ids.Count) application(s) dans EwsAllowedAppIDs. Reste à vérifier qu'aucune application utilisée n'y manque."
}
$en = @{
    NullDefault        = "HIGH RISK if apps still use EWS: EwsEnabled is not set (Null). Microsoft switches it to False during the October 2026 rollout, which blocks EWS for every app."
    Disabled           = "EWS is disabled (EwsEnabled = False): any app that still depends on EWS is already blocked."
    EnabledListUnknown = "EWS is enabled, but EwsAllowedAppIDs could not be read (permissions or module version). No conclusion possible."
    EnabledEmptyList   = "HIGH RISK if apps still use EWS: EWS is enabled but EwsAllowedAppIDs is empty. Since October 10, 2026, only apps on that list can use EWS."
    EnabledWithList    = "EWS is enabled with $($ids.Count) app(s) in EwsAllowedAppIDs. You still need to check that no app in use is missing."
}
$out = [System.Collections.Generic.List[string]]::new()
if ($Language -in 'fr', 'both') {
    $out.Add("== Vérification rapide EWS (gratuite, lecture seule) ==")
    $out.Add("État : $state")
    $out.Add($fr[$state])
    $out.Add("Jours avant la coupure complète d'EWS (1er avril 2027) : $days")
    $out.Add("Cette vérification ne dit pas QUELLES applications risquent de casser. La trousse complète croise le rapport « EWS usage » et les permissions Entra, en lecture seule.")
}
if ($Language -in 'en', 'both') {
    $out.Add("== EWS Quick Check (free, read-only) ==")
    $out.Add("State: $state")
    $out.Add($en[$state])
    $out.Add("Days until EWS is fully disabled (April 1, 2027): $days")
    $out.Add("This check does not tell you WHICH apps are at risk of breaking. The full kit joins the 'EWS usage' report with Entra permissions, read-only.")
}
$out.Add("Nothing was changed in your tenant / Rien n'a été modifié dans votre locataire.")
$out
