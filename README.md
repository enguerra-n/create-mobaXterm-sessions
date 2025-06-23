# MobaXterm Session Generator

## Description

Ce script PowerShell permet de générer automatiquement un fichier `.mxtsessions` à partir d'un fichier `router.db` produit par un serveur Oxidized. Il facilite l'importation en masse de sessions SSH dans MobaXterm, en les organisant par catégories et sous-dossiers.

## Format attendu du fichier `router.db`

Le fichier `router.db` doit être présent dans le même dossier que le script, et respecter le format suivant :

```
CODE_EQUIPEMENT:REFERENCE_EQUIPEMENT:ADDR_IP:MARQUE_EQUIPEMENT
```

Exemple :

```
C1234:Routeur-Paris:192.168.1.1:Cisco
B567:Routeur-Lyon:192.168.1.2:Juniper
```

## Utilisation

1. Placez le fichier `router.db` dans le même dossier que le script.
2. Exécutez le script PowerShell :
   ```powershell
   .\generate_mxtsessions.ps1
   ```
3. Entrez le nom du dossier global qui contiendra toutes les sessions.
4. Le script génère :
   - `sessions_import.mxtsessions` : fichier d'import pour MobaXterm.
   - `debug_structure.txt` : aperçu de la structure générée pour vérification.

## Import dans MobaXterm

1. Ouvrez MobaXterm.
2. Faites un clic droit sur "User sessions".
3. Sélectionnez "Import sessions from file".
4. Choisissez le fichier `sessions_import.mxtsessions`.

## Statistiques générées

À la fin de l'exécution, le script affiche :
- Le nombre total de bookmarks
- Le nombre de catégories créées
- Le nombre de clients (dossiers)
- Le nombre total de sessions SSH

## Avantages

- Automatisation complète de la création de sessions SSH
- Structure hiérarchique claire (catégories → clients → sessions)
- Facilement réutilisable et modifiable
