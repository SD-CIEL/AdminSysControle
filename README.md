# Evaluation automatique administration système Linux
Lycée Branly Lyon\
Version 2025\
SD
## Configuration des VM
OS Debian minimal avec serveur SSH configuré pour le contrôle\  
Compte pour le contrôle : login **prof** mdp **frop**  
Authoriser sudo pour prof sans rentrer le mdp en ajoutant dans /etc/sudoers, avec la commande visudo: 
  ```bash
prof ALL=(ALL) NOPASSWD: ALL
```
## Fichiers utilisés :
- IPEtudiant.csv : liste des IP des VM et des noms des l'étudiants
- controle.csv : liste des controles : nom du controle, commande bash et résultat attendu
- resultats.csv : liste des résultats obtenus pour chaque VM/étudiant. Fichier horodaté toutes les heures.
## Pare-feu Windows
Si la session ssh est établie en local mais n’est pas validée avec le contrôle distant alors configurer le pare-feu Windows, dans les règles de trafic entrant : 
-	les règles "VirtualBox Virtual Machine" doivent être autorisées et non bloquées.
-	Ajouter un règle autorisant le port 22.
