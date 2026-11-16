<#
.SYNOPSIS
  Exporte MiniBlocs pour Windows (MiniBlocs.exe + MiniBlocs.pck), lançable d'un double-clic sans Godot.

.DESCRIPTION
  1. Met à jour une copie du dépôt réservée à l'export (par défaut Documents\MiniBlocs-export\source ; pas dans %LOCALAPPDATA%,
     que l'app Claude redirige vers son propre dossier, invisible pour la tâche planifiée),
     sur la dernière version de origin/main. Ton dossier de travail n'est jamais touché.
  2. Écrit build_info.json (version, commit, date et heure) : l'écran titre l'affiche.
  3. Importe les ressources puis exporte avec le preset « Windows Desktop » (export_presets.cfg).
     Si les modèles d'export de Godot ne sont pas installés, il exporte seulement le .pck et
     copie le moteur Godot à côté sous le nom MiniBlocs.exe : le jeu se lance pareil.
  4. Remplace le contenu du dossier de destination (par défaut Documents\MiniBlocs).
     Les sauvegardes ne sont pas dans ce dossier (elles sont dans %APPDATA%\Godot\app_userdata\MiniBlocs).

.PARAMETER Demo
  Exporte l'édition démo (Steam Next Fest) avec le preset « Windows Demo » : MiniBlocsDemo.exe +
  MiniBlocsDemo.pck, dans Documents\MiniBlocs-Demo par défaut (sauvegardes à part, dossier « MiniBlocs Demo »).

.PARAMETER SiChangement
  N'exporte que si main a changé depuis le dernier export (pratique pour la tâche planifiée).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\export\exporter_windows.ps1
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\export\exporter_windows.ps1 -SiChangement
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\export\exporter_windows.ps1 -Demo
#>
param(
    [string]$Godot = $(if ($env:MINIBLOCS_GODOT) { $env:MINIBLOCS_GODOT } else { "$env:USERPROFILE\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" }),
    [string]$Destination = "",
    [string]$Source = "$env:USERPROFILE\Documents\MiniBlocs-export\source",
    [string]$Depot = "https://github.com/macgama/miniblocs.git",
    [string]$Branche = "main",
    [switch]$SiChangement,
    [switch]$Demo
)

# Édition démo (Steam Next Fest) : autre preset, autre nom d'exécutable, autre dossier.
$Preset = if ($Demo) { "Windows Demo" } else { "Windows Desktop" }
$Nom = if ($Demo) { "MiniBlocsDemo" } else { "MiniBlocs" }
if (-not $Destination) {
    $Destination = if ($Demo) { "$env:USERPROFILE\Documents\MiniBlocs-Demo" } else { "$env:USERPROFILE\Documents\MiniBlocs" }
}

$ErrorActionPreference = "Stop"
$Journal = Join-Path (Split-Path $Source -Parent) "export.log"
New-Item -ItemType Directory -Force (Split-Path $Source -Parent) | Out-Null

function Ecrire([string]$m) {
    $l = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $m
    Write-Host $l
    Add-Content -Path $Journal -Value $l -Encoding UTF8
}

function Lancer-Git { & git -C $Source @args; if ($LASTEXITCODE -ne 0) { throw "git $args a échoué ($LASTEXITCODE)" } }

# Godot écrit sur stderr : sous PowerShell 5.1 avec « Stop », ça lèverait une erreur. On journalise tout.
function Lancer-Godot {
    $ErrorActionPreference = "Continue"
    & $Godot --headless --path $Source @args 2>&1 | ForEach-Object { "$_" } | Out-File -Append -Encoding UTF8 $Journal
    return $LASTEXITCODE
}

if (-not (Test-Path $Godot)) { throw "Godot introuvable : $Godot (passe -Godot <chemin du .exe console> ou définis MINIBLOCS_GODOT)" }

# --- 1. Copie du dépôt dédiée à l'export -------------------------------------------------------
if (-not (Test-Path (Join-Path $Source ".git"))) {
    Ecrire "Clonage de $Depot dans $Source"
    $ErrorActionPreference = "Continue"
    & git clone --quiet --branch $Branche $Depot $Source 2>&1 | Out-Null
    $ErrorActionPreference = "Stop"
    if (-not (Test-Path (Join-Path $Source ".git"))) { throw "git clone a échoué" }
}
Lancer-Git fetch --quiet origin $Branche
$commit = (& git -C $Source rev-parse --short "origin/$Branche").Trim()

$infoDest = Join-Path $Destination "build_info.json"
if ($SiChangement -and (Test-Path $infoDest)) {
    $ancien = (Get-Content $infoDest -Raw -Encoding UTF8 | ConvertFrom-Json).commit
    if ($ancien -eq $commit -and (Test-Path (Join-Path $Destination "$Nom.exe"))) {
        Ecrire "main n'a pas changé ($commit) : rien à faire."
        exit 0
    }
}
Lancer-Git reset --quiet --hard "origin/$Branche"
Lancer-Git clean --quiet -fdx -e .godot

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
$sortie = Join-Path $Source $(if ($Demo) { "build\windows-demo" } else { "build\windows" })
if (Test-Path $sortie) { Remove-Item -Recurse -Force $sortie }
New-Item -ItemType Directory -Force $sortie | Out-Null

Ecrire "Import des ressources (la première fois, ça prend quelques minutes)"
$null = Lancer-Godot --import

$verGodot = (& $Godot --version).Trim()                       # ex. 4.7.2.stable.official.ed1daf0bf
$dossierModeles = Join-Path $env:APPDATA ("Godot\export_templates\" + (($verGodot -split '\.')[0..3] -join '.'))
$avecModeles = Test-Path (Join-Path $dossierModeles "windows_release_x86_64.exe")

if ($avecModeles) {
    Ecrire "Export complet avec les modèles de $dossierModeles"
    $null = Lancer-Godot --export-release $Preset (Join-Path $sortie "$Nom.exe")
} else {
    Ecrire "Modèles d'export absents ($dossierModeles) : export du .pck + moteur Godot renommé"
    $null = Lancer-Godot --export-pack $Preset (Join-Path $sortie "$Nom.pck")
    $moteur = Join-Path (Split-Path $Godot -Parent) ((Split-Path $Godot -Leaf) -replace '_console\.exe$', '.exe')
    if (-not (Test-Path $moteur)) { throw "Moteur Godot (sans _console) introuvable : $moteur" }
    Copy-Item $moteur (Join-Path $sortie "$Nom.exe")
}
foreach ($f in "$Nom.exe", "$Nom.pck") {
    if (-not (Test-Path (Join-Path $sortie $f))) { throw "L'export n'a pas produit $f (voir $Journal)" }
}
Copy-Item (Join-Path $Source "build_info.json") $sortie

# --- 4. Installation dans le dossier de destination -------------------------------------------
if (Get-Process -Name $Nom -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$Destination*" }) {
    throw "MiniBlocs est ouvert depuis $Destination : ferme le jeu puis relance l'export."
}
New-Item -ItemType Directory -Force $Destination | Out-Null
Get-ChildItem $Destination -Filter "$Nom.*" | Remove-Item -Force
Copy-Item (Join-Path $sortie "*") $Destination -Force
try {
@"
$(if ($Demo) { "MiniBlocs - édition démo (Steam Next Fest)" } else { "MiniBlocs" }) $version ($commit), build du $date
Lancer : double-clic sur $Nom.exe
Refaire l'export : powershell -ExecutionPolicy Bypass -File "$PSCommandPath"$(if ($Demo) { " -Demo" })
"@ | Set-Content -Encoding UTF8 (Join-Path $Destination "LISEZMOI.txt") -ErrorAction Stop
} catch { Ecrire "LISEZMOI.txt non mis à jour (fichier ouvert ?) : $($_.Exception.Message)" }
Ecrire "OK : $Destination\$Nom.exe ($version, $(if ($avecModeles) { 'modèles officiels' } else { 'moteur renommé' }))"
