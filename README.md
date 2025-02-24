# Evaluation automatique administration système Linux
Lycée Branly Lyon\
Version 2025\
SD
## Configuration des VM
OS Debian minimal avec serveur SSH configurer pour le contrôle\  
Compte pour le contrôle : login prof mdp frop\ 
Authorisation d'utiliser sudo sans rentrer le mdp :\   
c:/etc/sudoers   ajouter : prof ALL=(ALL) NOPASSWD: ALL
## Fichiers utilisés :
- IPEtudiant.csv : liste des IP des VM et le nom de l'étudiant
- controle.csv : liste des controles : nom du controle, commande bash et résultat attendu
- resultats.csv : liste des résultats obtenues pour chaque VM/étudiant. Fichier horodaté toutes les heures.
