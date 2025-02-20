$ModulePath = "$env:USERPROFILE\PowerShell\Modules"

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


# Ajouter le chemin au module à PowerShell (au cas où il ne serait pas détecté)
#$env:PSModulePath += ";$ModulePath"
#Import-Module Posh-SSH




# ouverture de la session
$Password = ConvertTo-SecureString "didalab" -AsPlainText -Force
$Creds = New-Object System.Management.Automation.PSCredential ("utilisateur", $Password)

$Session = New-SSHSession -ComputerName "127.0.0.1" -Credential $Creds -AcceptKey


# Commande Linux
$Result= Invoke-SSHCommand -SessionId $Session.SessionId -Command "ls -l /home"

Write-Host $Result.output -ForegroundColor Magenta



# Fermeture de la session
 Remove-SSHSession -SessionId $Session.SessionId