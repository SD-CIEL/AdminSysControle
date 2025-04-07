# Script contrôle sur OS Linux Debian dans VM via SSH
# SD 2025
# Pour sudo sans mot de passe, il faut ajouter  "prof ALL=(ALL) NOPASSWD: ALL" dans  "sudo nano visudo"


# -------------------------------------------------------------------------------
# Variables
$fichierListeEtudiants = "IPEtudiants-Test.csv"
$remoteUser ="prof" #"utilisateur" #
$password = "frop"#"didalab" #
#$privateKeyPath = "C:\Path\To\Your\PrivateKey"
$PasswordSecur = ConvertTo-SecureString $password -AsPlainText -Force
$Creds = New-Object System.Management.Automation.PSCredential ($remoteUser , $PasswordSecur)

$timeout =40 # Timeout d'ouverture de session ssh en secondes
$intervalSeconds = 10  # Intervalle entre chaque itération en secondes

# Liste VM
$VM = @()

# -------------------------------------------------------------------------------
# Affichage tableau
function Show-SplitTable {
    param (
        [Parameter(Mandatory = $true)] [array]$data,
        [int]$columnsPerTable = 3
    )
      if (-not [Console]::IsOutputRedirected) {
        try {
            $windowWidth = [Console]::WindowWidth
        } catch {
                $windowWidth = 80  # Valeur par défaut ou ce que tu veux
        }
       } else {
         $windowWidth = 80  # Fallback pour les environnements sans console
      }

    #Write-Host "Largeur de la fenêtre : $windowWidth"


    $colNames = $data[0].PSObject.Properties.Name  # Récupère les noms des colonnes
    $firstCol = $colNames[1]  # Garder la colonne 2
    $otherCols = $colNames[2..($colNames.Count - 1)]  # Toutes les autres colonnes

    for ($i = 0; $i -lt $otherCols.Count; $i += $columnsPerTable) {
        $part = $otherCols[$i..([math]::Min($i + $columnsPerTable - 1, $otherCols.Count - 1))]

        # Toujours inclure la colonne 2
        $selectedCols = @($firstCol) + $part  

        $data | Select-Object $selectedCols | Format-Table -Property * -AutoSize #| Format-Table -AutoSize |  Out-String -Width $windowWidth
    }
}


clear
Write-Host "               Controle LINUX" -ForegroundColor Cyan

# Créer le dossier s'il n'existe pas
#if (-not (Test-Path $ModulePath)) {
#    New-Item -ItemType Directory -Path $ModulePath -Force
#}
# Ajouter le chemin aux modules PowerShell
#$env:PSModulePath = "$ModulePath;$env:PSModulePath"
#$FilteredPaths = $CurrentPaths | Where-Object {$_ -notmatch "OneDrive"}
# Réappliquer les nouveaux chemins sans OneDrive
#$env:PSModulePath = $FilteredPaths -join ";"


# Vérifier si le module Posh-SSH est installé
if (-not (Get-Module -ListAvailable -Name Posh-SSH)) {
    Write-Host "❌ Le module Posh-SSH n'est pas installé. Installation en cours..." -ForegroundColor Yellow
    
    # Installer le module
    try {
        
        #Install-Module -Name Posh-SSH -Force -Scope CurrentUser
        Install-Module -Name Posh-SSH -Force -Scope CurrentUser -Verbose -ErrorAction Stop

    
        #Install-Module -Name Posh-SSH -Force -Scope CurrentUser -Repository PSGallery -SkipPublisherCheck -Des $ModulePath

        Write-Host "✅ Installation réussie !" -ForegroundColor Green
    } catch {
        Write-Host "❌ Erreur lors de l'installation de Posh-SSH : $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "✅ Le module Posh-SSH est déjà installé." -ForegroundColor Cyan
}

# Importer le module dans la session actuelle
Import-Module Posh-SSH -ErrorAction Stop
Write-Host "✅ Module Posh-SSH chargé avec succès." -ForegroundColor Green





# Lire le fichier CSV des machines et étudiants
# Récupérer le dossier où se trouve le script
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$csvPath = Join-Path $scriptPath $fichierListeEtudiants

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

#Effacer les clés des sessions enregistrées sur les Ip
$jobs = @()
foreach ($item in $VM) {
    Write-Host "Suppresion clé session" $item.iP -ForegroundColor Green
    Remove-SSHTrustedHost -HostName $item.iP
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
        $session = New-SSHSession -ComputerName $VM[$i].ip -Credential $Creds -AcceptKey -ConnectionTimeout $timeout  2>$null
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
       $session = New-SSHSession -ComputerName $vm[$i].ip -Credential $Creds -AcceptKey -ConnectionTimeout $timeout 2>$null
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

        Write-Host "Executing tests on host: $($VM[$i].connect.Host) $($VM[$i].nom)"

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
    #clear
 


    # Afficher les résultats
    Show-SplitTable -data $VM -columnsPerTable 12

    # Sauvegarde des résultats
    # Générer un timestamp au format YYYY-MM-DD_HH-mm-ss
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH"
    # Définir le nom du fichier avec la date et l'heure
    $filename = "resultats_$timestamp.csv"
    # Exporter le tableau en CSV
    $filenamepath = Join-Path $scriptPath $filename
    $VM | Export-Csv -Path $filenamepath -NoTypeInformation -Encoding UTF8 -Force


    # Temporisation affichage réultats 
    Start-Sleep -Seconds $intervalSeconds
}





# Fermer toutes les sessions SSH
$sshSessions | ForEach-Object { Remove-SSHSession -SSHSession $_ }



