<#
.SYNOPSIS
  Crée (ou retire avec -Retirer) la tâche planifiée Windows « MiniBlocs - export » qui relance
  exporter_windows.ps1 -SiChangement toutes les 30 minutes et à l'ouverture de session :
  dès que main change sur GitHub, Documents\MiniBlocs est réexporté tout seul.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\export\installer_tache.ps1
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\export\installer_tache.ps1 -Retirer
#>
param([int]$Minutes = 30, [switch]$Retirer)

$ErrorActionPreference = "Stop"
$nom = "MiniBlocs - export"
if ($Retirer) {
    Unregister-ScheduledTask -TaskName $nom -Confirm:$false
    Write-Host "Tâche « $nom » retirée."
    exit 0
}
# Le script lancé par la tâche est celui de la copie dédiée à l'export, toujours à jour avec main.
$script = "$env:USERPROFILE\Documents\MiniBlocs-export\source\tools\export\exporter_windows.ps1"
if (-not (Test-Path $script)) { throw "Lance d'abord une fois exporter_windows.ps1 (il crée $script)." }

# Lancement par un petit VBS : powershell -WindowStyle Hidden fait quand même apparaître une console.
# Le VBS est copié hors de la copie du dépôt, pour qu'un reset de celle-ci ne puisse pas le retirer.
$lanceur = "$env:USERPROFILE\Documents\MiniBlocs-export\lancer_export.vbs"
Copy-Item (Join-Path $PSScriptRoot "lancer_sans_fenetre.vbs") $lanceur -Force
$action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "//B //Nologo `"$lanceur`" -SiChangement"
$declencheurs = @(
    (New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes $Minutes)),
    (New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME)
)
$reglages = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopIfGoingOnBatteries -AllowStartIfOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Hours 1) -MultipleInstances IgnoreNew -Hidden
Register-ScheduledTask -TaskName $nom -Action $action -Trigger $declencheurs -Settings $reglages `
    -Description "Réexporte MiniBlocs dans Documents\MiniBlocs quand main change (journal : Documents\MiniBlocs-export\export.log)" -Force | Out-Null
Write-Host "Tâche « $nom » installée : vérification toutes les $Minutes min et à l'ouverture de session."
