' Lance exporter_windows.ps1 sans aucune fenêtre (utilisé par la tâche planifiée « MiniBlocs - export »).
' installer_tache.ps1 copie ce fichier dans Documents\MiniBlocs-export\ : le script lancé est celui
' de la copie dédiée à l'export, Documents\MiniBlocs-export\source. Tout est écrit dans export.log.
' Les arguments (ex. -SiChangement) sont transmis au script.
Option Explicit
Dim sh, fso, dossier, script, args, i
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
dossier = fso.GetParentFolderName(WScript.ScriptFullName)
script = dossier & "\source\tools\export\exporter_windows.ps1"

' Git ne doit jamais attendre une réponse (« Should I try again? (y/n) »).
sh.Environment("Process")("GIT_ASK_YESNO") = "false"
sh.Environment("Process")("GIT_TERMINAL_PROMPT") = "0"

args = ""
For i = 0 To WScript.Arguments.Count - 1
    args = args & " " & WScript.Arguments(i)
Next

' 0 = fenêtre cachée, True = attendre la fin (la tâche reste « en cours » pendant l'export).
WScript.Quit sh.Run("powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File """ & script & """" & args, 0, True)
