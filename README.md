# Evaluation automatique administration système Linux
Lycée Branly Lyon\
Version 2025\
SD
## Configuration des VM
OS Debian minimal avec serveur SSH configuré pour le contrôle\  
Compte pour le contrôle : login **prof** mdp **frop**  
Authoriser sudo pour prof sans rentrer le mdp en ajoutant dans /etc/sudoers : 
  ```bash
prof ALL=(ALL) NOPASSWD: ALL
```
## Fichiers utilisés :
- IPEtudiant.csv : liste des IP des VM et des noms des l'étudiants
- controle.csv : liste des controles : nom du controle, commande bash et résultat attendu
- resultats.csv : liste des résultats obtenus pour chaque VM/étudiant. Fichier horodaté toutes les heures.
