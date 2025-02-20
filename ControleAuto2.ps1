﻿# Script contrôle sur OS Linux Debian dans via SSH
# Pour sudo sans mot de passe :  "sudo visudo"  ajouter  "prof ALL=(ALL) NOPASSWD: ALL"

# Variables
$remoteUser ="prof" #"utilisateur" #
$password = "frop"#"didalab" #
$privateKeyPath = "C:\Path\To\Your\PrivateKey"
$PasswordSecur = ConvertTo-SecureString $password -AsPlainText -Force
$Creds = New-Object System.Management.Automation.PSCredential ($remoteUser , $PasswordSecur)

$timeout =40 # Timeout de connexion
$intervalSeconds = 10  # Intervalle entre chaque itération en secondes

#Liste des Machine à controler
$remoteHosts = @("192.168.1.100","192.168.1.38","192.168.1.39")
# Importer le module Posh-SSH


# Liste VM
$VM = @()



# Créer le dossier s'il n'existe pas
if (-not (Test-Path $ModulePath)) {
    New-Item -ItemType Directory -Path $ModulePath -Force
}

# Ajouter le chemin aux modules PowerShell
$env:PSModulePath = "$ModulePath;$env:PSModulePath"
$FilteredPaths = $CurrentPaths | Where-Object {$_ -notmatch "OneDrive"}
# Réappliquer les nouveaux chemins sans OneDrive
$env:PSModulePath = $FilteredPaths -join ";"

# Vérifier si le module Posh-SSH est installé
if (-not (Get-Module -ListAvailable -Name Posh-SSH)) {
    Write-Host "Le module Posh-SSH n'est pas installé. Installation en cours..." -ForegroundColor Yellow
    
    # Installer le module
    try {
        
        #Install-Module -Name Posh-SSH -Force -Scope CurrentUser
        Install-Module -Name Posh-SSH -Force -Scope CurrentUser -Verbose -ErrorAction Stop

    
        #Install-Module -Name Posh-SSH -Force -Scope CurrentUser -Repository PSGallery -SkipPublisherCheck -Des $ModulePath

        Write-Host "Installation réussie !" -ForegroundColor Green
    } catch {
        Write-Host "Erreur lors de l'installation de Posh-SSH : $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Le module Posh-SSH est déjà installé." -ForegroundColor Green
}

# Importer le module dans la session actuelle
Import-Module Posh-SSH -ErrorAction Stop
Write-Host "Module Posh-SSH chargé avec succès." -ForegroundColor Cyan





# Lire le fichier CSV des machines et étudiants
# Récupérer le dossier où se trouve le script
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$csvPath = Join-Path $scriptPath "IPEtudiants.csv"

# Vérifier si le fichier existe
if (-Not (Test-Path $csvPath)) {
    Write-Host "❌ Le fichier $csvPath n'existe pas dans le dossier du script !" -ForegroundColor Red
    exit
}
else {
    Write-Host "✅ Fichier $csvPath chargé" -ForegroundColor Green
}

# Lire le fichier CSV
$data = Import-Csv $csvPath

# Remplir les tableaux
foreach ($row in $data) {
    $VM+= @( New-Object PSObject -Property @{ ip = $row.iP; nom = $row.nomEtudiant } )
}

# Ajouter colonne Note
foreach ($item in $VM) {
   $item | Add-Member -MemberType NoteProperty -Name "NOTE" -Value "0"
}
# Ajouter colonne ping
foreach ($item in $VM) {
   $item | Add-Member -MemberType NoteProperty -Name "ping" -Value ""
}
# Ajouter colonne connect
foreach ($item in $VM) {
   $item | Add-Member -MemberType NoteProperty -Name "connect" -Value ""
}




# Lire le fichier CSV des controles
# Récupérer le dossier où se trouve le script
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$csvPath = Join-Path $scriptPath "controle.csv"

# Vérifier si le fichier existe
if (-Not (Test-Path $csvPath)) {
    Write-Host "❌ Le fichier $csvPath n'existe pas dans le dossier du script !" -ForegroundColor Red
    exit
}
else {
    Write-Host "✅ Fichier $csvPath chargé" -ForegroundColor Green
}

# Lire le fichier CSV
$data = Import-Csv $csvPath

# Initialiser les tableaux
$controleNames = @()
$commands = @()
$expectedValues = @()

# Remplir les tableaux
foreach ($row in $data) {
    $controleNames += $row.ControleName
    $commands += $row.Command
    $expectedValues += $row.Expected
    foreach ($item in $VM) {
        $item | Add-Member -MemberType NoteProperty -Name $row.ControleName -Value ""
    }

}




#Test initial de connectivité PING
$jobs = @()
foreach ($item in $VM) {
    $jobs += Start-Job -ScriptBlock {
        param ($ip) Test-Connection -ComputerName $ip -Count 1 -Quiet
    } -ArgumentList $item.iP
}

# Attente des résultats
$jobs | Wait-Job
$results = $jobs | Receive-Job

# Mise à jour du tableau
for ($i = 0; $i -lt $VM.Count; $i++) {
    $VM[$i].ping = $results[$i]
}

# Nettoyage des jobs
$jobs | Remove-Job


$VM | Format-Table -AutoSize 


#Ouverture des sessions
Write-Host "Ouverture des sessions"
# Ouvrir toutes les sessions SSH 
for ($i = 0; $i -lt $VM.Count; $i++) 
 {
    if ($VM[$i].ping)
    {
        $session = New-SSHSession -ComputerName $VM[$i].ip -Credential $Creds -AcceptKey -ConnectionTimeout $timeout
        $VM[$i].connect=$session

        if ($session.Connected) {
            Write-Host "  ✅ Connexion réussie :" $VM[$i].ip -ForegroundColor Green
            #$VM[$i].connect="True"
        } else {
            Write-Host "  ❌ Échec de connexion :" $VM[$i].ip -ForegroundColor Red
            #$VM[$i].connect="False"
        }
    }
}

Write-Host "Fin ouverture sessions"
Write-Host ""

$VM | Format-Table -AutoSize 

# Fonction pour tenter de joindre et connecté la VM 
function Reconnect {
    param (
        [array]$vm, $i
    )

    if (Test-Connection -ComputerName $vm[$i].ip -Count 1 -Quiet) 
    {
       Write-Host "   ✅ " $vm[$i].ip "ping OK" -ForegroundColor Green
       $vm[$i].ping=$true
       $session = New-SSHSession -ComputerName $vm[$i].ip -Credential $Creds -AcceptKey -ConnectionTimeout $timeout
       $VM[$i].connect=$session
       if ($session.Connected) {
            Write-Host "   ✅ " $vm[$i].ip "session établie"  -ForegroundColor Green
       } else {
           Write-Host "  ❌ " $vm[$i].ip "session échec de connexion !" -ForegroundColor Red
       }
    }
    else
    {
        Write-Host "   ❌ " $ $vm[$i].ip "ping NOK !" -ForegroundColor Red
        $vm[$i].ping=$false
    }
 }

# Fonction pour exécuter les tests sur une session
function Execute-Tests {
    param (
        [object]$session
    )
        # Vérifier si la session est valide
    if (-not $session -or -not $session.Connected) {
        Write-Host "   ❌ Session SSH invalide ou non connectée." -ForegroundColor Red
        return $null
    }

    # Tableau pour stocker les résultats
    $results = @()

    # Exécuter les commandes et stocker les résultats
    for ($i = 0; $i -lt $commands.Length; $i++) {
        $command = $commands[$i]
        $expectedValue = $expectedValues[$i]
        $result = Invoke-SSHCommand -SSHSession $session -Command $command
        $results += [PSCustomObject]@{
            Command       = $command
            Output        = $result.Output
            ExpectedValue = $expectedValue
            Match         = [bool]($result.Output -match $expectedValue)
        }
            $res=$result.Output
            Write-Host "  - Executing tests on host: $res" -ForegroundColor Green
    }
    return $results
}

# Boucle pour répéter les tests périodiquement
while ($true) {

   for ($i = 0; $i -lt $VM.Count; $i++) 
   {
     if ($VM[$i].ping)
     {
       if ($VM[$i].connect.Connected)
        {

        Write-Host "Executing tests on host: $($VM[$i].connect.Host)"

        $testResults = Execute-Tests -session $VM[$i].connect

        # Réaliser les tests 
        $note=0;

        for ($j = 0; $j -lt $commands.Length; $j++) {
            $command = $commands[$j]
            $controleName = $controleNames[$j]
            $columnName = "$controleName"

            # Récupérer le résultat correspondant
            $matchValue = ($testResults | Where-Object { $_.Command -eq $command } | Select-Object -First 1).Match

            $VM[$i].$columnName=$matchValue
            if ($matchValue) {$note++}
        }  

        $VM[$i].NOTE=$note
        



      }
      else
      {
            Reconnect -vm $VM -i $i
      }
    }
    else
    {
            Reconnect -vm $VM -i $i
    }

}

    # Afficher les résultats sous forme de tableau
    clear
    $VM | Format-Table -AutoSize 



    Start-Sleep -Seconds $intervalSeconds
}

# Fermer toutes les sessions SSH
$sshSessions | ForEach-Object { Remove-SSHSession -SSHSession $_ }



