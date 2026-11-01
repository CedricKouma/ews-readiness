# Vérification rapide EWS (gratuite) · EWS Quick Check (free) · v0.1.0-beta
*Rigoutech inc. · Lecture seule / Read-only · PowerShell 7.2+ · Module `ExchangeOnlineManagement`*

**FR.** Microsoft désactive EWS dans Exchange Online : la désactivation a commencé en octobre 2026, et EWS sera complètement coupé en avril 2027 ([Microsoft Learn](https://learn.microsoft.com/en-us/exchange/clients-and-mobile-in-exchange-online/deprecation-of-ews-exchange-online)). Ce script gratuit lit **2 réglages** de votre locataire (`EwsEnabled` et `EwsAllowedAppIDs`) et vous dit si vos applications EWS risquent d'être bloquées.

```powershell
Install-Module ExchangeOnlineManagement -Scope CurrentUser   # si besoin
pwsh -File ./Test-EwsTenantState.ps1 -UserPrincipalName lecteur@votredomaine.ca
```
- Commandes appelées : `Connect-ExchangeOnline`, `Get-OrganizationConfig`, `Disconnect-ExchangeOnline`. **Rien d'autre.** Rôle requis : Entra « Global Reader » prévu comme suffisant, **non confirmé** sur un vrai locataire.
- Mode hors ligne : `-OrgJsonPath fichier.json` (voir `tests/`). Serveur sans navigateur : ajoutez `-Device` (connexion par code d'appareil).
- Autotest sans réseau : `pwsh -NoProfile -File tests/Run-LiteTests.ps1` (16 tests).
- **Ce que ce script ne fait pas :** il ne dit pas **quelles** applications risquent de casser. La trousse complète (payante) croise le rapport « EWS usage » du Centre d'administration avec les permissions Entra, repère les tâches rares, puis produit un rapport en français et en anglais et une **proposition** de liste d'autorisation (jamais appliquée). Aucun verdict n'a encore été produit sur une vraie application EWS. Lien : [LIEN DE LA TROUSSE COMPLÈTE — à ajouter à la publication].

**EN.** Microsoft is disabling EWS in Exchange Online (disablement started in October 2026; EWS will be fully disabled in April 2027). This free script reads **2 tenant settings** (`EwsEnabled`, `EwsAllowedAppIDs`) and tells you whether your EWS apps are at risk of being blocked.
- Cmdlets called: `Connect-ExchangeOnline`, `Get-OrganizationConfig`, `Disconnect-ExchangeOnline`. **Nothing else.** Required role: Entra "Global Reader" is expected to be enough, **not confirmed** on a real tenant.
- No browser on the machine? Add `-Device` (device-code sign-in).
- It does **not** tell you which apps are at risk of breaking; the full (paid) kit does (no verdict has yet been produced on a real EWS app). Link: [FULL KIT LINK — to add at publication].
- **Not yet tested against a real tenant** (tested offline and with mocked cmdlets only).

Licence: `LICENSE.txt` (beta). General information, not legal advice.
