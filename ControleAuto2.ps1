#Script contrôle sur OS Linux Debian dans via SSH
# Pour sudo sans mot de passe :  "sudo visudo"  ajouter  "utilisateur ALL=(ALL) NOPASSWD: ALL"

# Importer le module Posh-SSH
Import-Module Posh-SSH

# Variables
$remoteUser = "prof"
$password = "frop"
$privateKeyPath = "C:\Path\To\Your\PrivateKey"
$PasswordSecur = ConvertTo-SecureString $password -AsPlainText -Force
$Creds = New-Object System.Management.Automation.PSCredential ($remoteUser , $PasswordSecur)

$timeout =30 # Timeout de connexion
$intervalSeconds = 10  # Intervalle entre chaque itération en secondes

#Liste des Machine à controler
$remoteHosts = @("192.168.0.167","127.0.0.1")


# Lire le fichier CSV des controles
# Récupérer le dossier où se trouve le script
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$csvPath = Join-Path $scriptPath "controle.csv"

# Vérifier si le fichier existe
if (-Not (Test-Path $csvPath)) {
    Write-Host "❌ Le fichier data.csv n'existe pas dans le dossier du script !" -ForegroundColor Red
    exit
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
}

#$controleNames = @("Test","sudo","hostName", "user1") 
#$commands = @("uname",  "sudo whoami","hostname","id eleve")
#$expectedValues = @( "Linux","root", "debian2016", "uid")



#Ouverture des sessions
# Liste dessessions
Write-Host "Ouverture des sessions"
$sessions = @()
# Ouvrir toutes les sessions SSH en parallèle
foreach ($remoteHost in $remoteHosts) {
    $session = New-SSHSession -ComputerName $remoteHost -Credential $Creds -AcceptKey -ConnectionTimeout $timeout
    if ($session.Connected) {
        Write-Host "  ✅ Connexion réussie : $remoteHost" -ForegroundColor Green
        $Sessions += $session
    } else {
        Write-Host "  ❌ Échec de connexion : $remoteHost" -ForegroundColor Red
        $Sessions += [PSCustomObject]@{
            Host     = $remoteHost
            Connected = $false
        }
    }
}

Write-Host "Fin ouverture sessions"
Write-Host ""

# Fonction pour exécuter les tests sur une session
function Execute-Tests {
    param (
        [object]$session
    )
        # Vérifier si la session est valide
    if (-not $session -or -not $session.Connected) {
        Write-Host "  ❌ Session SSH invalide ou non connectée." -ForegroundColor Red
        return $null
    }

    # ouverture de la session
    #$PasswordSecur = ConvertTo-SecureString "didalab" -AsPlainText -Force
    #$Creds = New-Object System.Management.Automation.PSCredential ("utilisateur", $PasswordSecur)

    #$Session = New-SSHSession -ComputerName $remoteHost -Credential $Creds -AcceptKey -ConnectionTimeout 60

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
    # Tableau pour stocker les résultats finaux
    $finalResults = @()

   foreach ($session in $Sessions) {
    Write-Host "Executing tests on host: $($session.Host)"

    $testResults = Execute-Tests -session $session

    # Initialisation de l'objet résultat
    $resultObject = [Ordered]@{
        Host = $($session.Host)
    }

    # Ajouter dynamiquement les colonnes Command1Match, Command2Match, etc.
    for ($i = 0; $i -lt $commands.Length; $i++) {
        $command = $commands[$i]
        $controleName = $controleNames[$i]
        $columnName = "$controleName"  # Génère "Command0Match", "Command1Match", etc.

        # Récupérer le résultat correspondant
        $matchValue = ($testResults | Where-Object { $_.Command -eq $command } | Select-Object -First 1).Match

        # Ajouter dynamiquement la colonne
        $resultObject[$columnName] = $matchValue
    }

    # Ajouter l'objet au tableau final
    $finalResults += [PSCustomObject]$resultObject
}

    

    # Afficher les résultats sous forme de tableau
    $finalResults | Format-Table -AutoSize 

    Start-Sleep -Seconds $intervalSeconds
}

# Fermer toutes les sessions SSH
$sshSessions | ForEach-Object { Remove-SSHSession -SSHSession $_ }
