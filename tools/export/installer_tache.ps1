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
$script = "$env:LOCALAPPDATA\MiniBlocs\source\tools\export\exporter_windows.ps1"
if (-not (Test-Path $script)) { throw "Lance d'abord une fois exporter_windows.ps1 (il crée $script)." }

$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`" -SiChangement"
$declencheurs = @(
    (New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes $Minutes)),
    (New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME)
)
$reglages = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopIfGoingOnBatteries -AllowStartIfOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Hours 1) -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName $nom -Action $action -Trigger $declencheurs -Settings $reglages `
    -Description "Réexporte MiniBlocs dans Documents\MiniBlocs quand main change (journal : %LOCALAPPDATA%\MiniBlocs\export.log)" -Force | Out-Null
Write-Host "Tâche « $nom » installée : vérification toutes les $Minutes min et à l'ouverture de session."
