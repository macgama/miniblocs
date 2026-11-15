<#
.SYNOPSIS
  Exporte MiniBlocs pour Windows (MiniBlocs.exe + MiniBlocs.pck), lançable d'un double-clic sans Godot.

.DESCRIPTION
  1. Met à jour une copie du dépôt réservée à l'export (par défaut %LOCALAPPDATA%\MiniBlocs\source),
     sur la dernière version de origin/main. Ton dossier de travail n'est jamais touché.
  2. Écrit build_info.json (version, commit, date et heure) : l'écran titre l'affiche.
  3. Importe les ressources puis exporte avec le preset « Windows Desktop » (export_presets.cfg).
     Si les modèles d'export de Godot ne sont pas installés, il exporte seulement le .pck et
     copie le moteur Godot à côté sous le nom MiniBlocs.exe : le jeu se lance pareil.
  4. Remplace le contenu du dossier de destination (par défaut Documents\MiniBlocs).
     Les sauvegardes ne sont pas dans ce dossier (elles sont dans %APPDATA%\Godot\app_userdata\MiniBlocs).

.PARAMETER SiChangement
  N'exporte que si main a changé depuis le dernier export (pratique pour la tâche planifiée).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\export\exporter_windows.ps1
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\export\exporter_windows.ps1 -SiChangement
#>
param(
    [string]$Godot = $(if ($env:MINIBLOCS_GODOT) { $env:MINIBLOCS_GODOT } else { "$env:USERPROFILE\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" }),
    [string]$Destination = "$env:USERPROFILE\Documents\MiniBlocs",
    [string]$Source = "$env:LOCALAPPDATA\MiniBlocs\source",
    [string]$Depot = "https://github.com/macgama/miniblocs.git",
    [string]$Branche = "main",
    [switch]$SiChangement
)

$ErrorActionPreference = "Stop"
$Journal = Join-Path (Split-Path $Source -Parent) "export.log"
New-Item -ItemType Directory -Force (Split-Path $Source -Parent) | Out-Null

function Ecrire([string]$m) {
    $l = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $m
    Write-Host $l
    Add-Content -Path $Journal -Value $l -Encoding UTF8
}

function Git { & git -C $Source @args; if ($LASTEXITCODE -ne 0) { throw "git $args a échoué ($LASTEXITCODE)" } }

if (-not (Test-Path $Godot)) { throw "Godot introuvable : $Godot (passe -Godot <chemin du .exe console> ou définis MINIBLOCS_GODOT)" }

# --- 1. Copie du dépôt dédiée à l'export -------------------------------------------------------
if (-not (Test-Path (Join-Path $Source ".git"))) {
    Ecrire "Clonage de $Depot dans $Source"
    & git clone --quiet --branch $Branche $Depot $Source
    if ($LASTEXITCODE -ne 0) { throw "git clone a échoué" }
}
Git fetch --quiet origin $Branche
$commit = (& git -C $Source rev-parse --short "origin/$Branche").Trim()

$infoDest = Join-Path $Destination "build_info.json"
if ($SiChangement -and (Test-Path $infoDest)) {
    $ancien = (Get-Content $infoDest -Raw -Encoding UTF8 | ConvertFrom-Json).commit
    if ($ancien -eq $commit -and (Test-Path (Join-Path $Destination "MiniBlocs.exe"))) {
        Ecrire "main n'a pas changé ($commit) : rien à faire."
        exit 0
    }
}
Git reset --quiet --hard "origin/$Branche"
Git clean --quiet -fdx -e .godot

# --- 2. Infos de build ------------------------------------------------------------------------
$verProjet = (Select-String -Path (Join-Path $Source "project.godot") -Pattern '^config/version="(.*)"' | Select-Object -First 1).Matches.Groups[1].Value
if (-not $verProjet) { $verProjet = "0" }
$nbCommits = (& git -C $Source rev-list --count HEAD).Trim()
$version = "$verProjet.$nbCommits"
$date = Get-Date -Format "dd.MM.yyyy 'à' HH:mm"
$info = [ordered]@{ version = $version; commit = $commit; date = $date; branche = $Branche }
$json = $info | ConvertTo-Json
[IO.File]::WriteAllText((Join-Path $Source "build_info.json"), $json, (New-Object Text.UTF8Encoding $false))
Ecrire "Build $version ($commit) du $date"

# --- 3. Import puis export --------------------------------------------------------------------
$sortie = Join-Path $Source "build\windows"
if (Test-Path $sortie) { Remove-Item -Recurse -Force $sortie }
New-Item -ItemType Directory -Force $sortie | Out-Null

Ecrire "Import des ressources (la première fois, ça prend quelques minutes)"
& $Godot --headless --path $Source --import 2>&1 | Out-File -Append -Encoding UTF8 $Journal

$verGodot = (& $Godot --version).Trim()                       # ex. 4.7.2.stable.official.ed1daf0bf
$dossierModeles = Join-Path $env:APPDATA ("Godot\export_templates\" + (($verGodot -split '\.')[0..3] -join '.'))
$avecModeles = Test-Path (Join-Path $dossierModeles "windows_release_x86_64.exe")

if ($avecModeles) {
    Ecrire "Export complet avec les modèles de $dossierModeles"
    & $Godot --headless --path $Source --export-release "Windows Desktop" (Join-Path $sortie "MiniBlocs.exe") 2>&1 | Out-File -Append -Encoding UTF8 $Journal
} else {
    Ecrire "Modèles d'export absents ($dossierModeles) : export du .pck + moteur Godot renommé"
    & $Godot --headless --path $Source --export-pack "Windows Desktop" (Join-Path $sortie "MiniBlocs.pck") 2>&1 | Out-File -Append -Encoding UTF8 $Journal
    $moteur = Join-Path (Split-Path $Godot -Parent) ((Split-Path $Godot -Leaf) -replace '_console\.exe$', '.exe')
    if (-not (Test-Path $moteur)) { throw "Moteur Godot (sans _console) introuvable : $moteur" }
    Copy-Item $moteur (Join-Path $sortie "MiniBlocs.exe")
}
foreach ($f in "MiniBlocs.exe", "MiniBlocs.pck") {
    if (-not (Test-Path (Join-Path $sortie $f))) { throw "L'export n'a pas produit $f (voir $Journal)" }
}
Copy-Item (Join-Path $Source "build_info.json") $sortie

# --- 4. Installation dans le dossier de destination -------------------------------------------
if (Get-Process -Name MiniBlocs -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$Destination*" }) {
    throw "MiniBlocs est ouvert depuis $Destination : ferme le jeu puis relance l'export."
}
New-Item -ItemType Directory -Force $Destination | Out-Null
Get-ChildItem $Destination -Filter "MiniBlocs*" | Remove-Item -Force
Copy-Item (Join-Path $sortie "*") $Destination -Force
@"
MiniBlocs $version ($commit), build du $date
Lancer : double-clic sur MiniBlocs.exe
Refaire l'export : powershell -ExecutionPolicy Bypass -File "$PSCommandPath"
"@ | Set-Content -Encoding UTF8 (Join-Path $Destination "LISEZMOI.txt")
Ecrire "OK : $Destination\MiniBlocs.exe ($version, $(if ($avecModeles) { 'modèles officiels' } else { 'moteur renommé' }))"
