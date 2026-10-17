# Changelog

## [3.7.0] — 2026-10-17

### Nouvelles fonctionnalités

- **Visionnage des sessions** :
  - Filtre d'utilisateurs `f`<nom> dans la liste des utilisateurs (réindexation des résultats, filtres enchaînables), à l'image du filtre du menu de connexion.
  - Recherche de sessions par **date/heure** (`d`<critère>) : globale chez tous les utilisateurs, ou filtrée dans la liste d'un utilisateur. Critères acceptés (préfixes) : date seule (`2026`, `2026-10`, `2026-10-17`), heure seule (`14`, `14:30`), ou les deux séparés par un espace (`"2026-10-17 14:30"`). `d` seul réinitialise le filtre.
  - **Tri des sessions par machine** (`t`) : bascule entre le tri chronologique (défaut) et le regroupement par hôte-utilisateur distant, avec préfixe machine affiché devant chaque entrée.
- Listes d'utilisateurs du visionnage : détection par basename (robuste à la profondeur du chemin et aux variantes de find).

### Corrections

- `sessions_viewer` : quitter la liste des sessions d'un utilisateur ramène désormais à la liste des utilisateurs (auparavant cela quittait entièrement le menu de visionnage).

### Fichiers modifiés

| Fichier | Changements |
|---|---|
| `admin_menu.sh` | `sessions_viewer` réécrit : filtre utilisateurs, recherche date/heure globale et par utilisateur, tri par machine ; helpers `sessions_*` ajoutés et documentés |
| `README.md` | Section « Audit des sessions » : recherche et tri |
| `CHANGELOG.md` | Entrée 3.7.0 |
| `Dockerfile` | Version 3.7.0 Alpha |

## [3.6.0] — 2026-10-17

### Changements cassants

- **`PASSWORD_AUTH` vaut désormais `0` par défaut** : l'authentification par mot de passe sur le bastion est désactivée par défaut. Activez-la explicitement avec `-e PASSWORD_AUTH=1` si nécessaire (déconseillé).
- **Permissions durcies (ACL)** : les fichiers de `/opt/public/servers/` (clés privées, `authorized_servers.txt`) ne sont plus lisibles par le monde entier ; les utilisateurs du bastion ne peuvent que les lire via leur groupe, et ne peuvent plus lister le répertoire. Les scripts de `/opt/public/scripts/` ne sont plus modifiables par les administrateurs (root uniquement). Si vous injectiez des fichiers manuellement dans ces répertoires, l'entrypoint normalise automatiquement leurs permissions au démarrage puis toutes les 60 secondes.
- **Enregistrements de sessions déplacés** : les sessions ttyrec sont désormais écrites dans `/var/log/monosphere/sessions/<utilisateur>/` au lieu du home de l'utilisateur. Les anciens enregistrements en home (éphémères) ne sont pas migrés.
- **Nouveau code d'erreur 05** : la variable `PORT` invalide (hors 1-65535) est désormais fatale au démarrage.
- **Compte admin par défaut** : un avertissement de sécurité explicite est émis au démarrage si le compte `bastion` garde son mot de passe par défaut avec `PASSWORD_AUTH=1`.

### Nouvelles fonctionnalités

- **Transferts réellement en streaming** : `push_file` relaie stdin via `ssh cible 'cat > <dest>'` au lieu de scp avec fichier temporaire — plus aucun stockage temporaire sur le bastion, aucune limite de taille (la taille journalisée devient `-`).
- **Persistance des sessions** : les enregistrements ttyrec vivent dans le volume `/var/log/monosphere` et survivent aux redéploiements.
- **Désactivation de tous les forwardings SSH** (`DisableForwarding yes`, `AllowTcpForwarding no`, `PermitTunnel no`) : impossible d'ouvrir un tunnel à travers le bastion pour contourner le menu et `authorized_servers.txt`.
- **Normalisation continue des permissions** : une boucle de fond dans l'entrypoint ré-applique propriétaire/permissions/ACL toutes les 60 secondes ; les clés ajoutées à chaud par les administrateurs deviennent utilisables par les utilisateurs sans redémarrage (~60 s).
- **HEALTHCHECK Docker** : vérification que sshd tourne réellement (`pgrep sshd`).
- **ttyrec épinglé** : construction sur le tag `v1.2.0.0` (ARG `TTYREC_VERSION`) pour des builds reproductibles.
- **Multi-scripts personnalisés** : tous les `*.sh` de `/opt/custom/scripts/` sont exécutés individuellement (auparavant seul le premier l'était).
- **Démarrage de sshd fiabilisé** : génération explicite des clés d'hôte (`ssh-keygen -A`) et démarrage direct du démon sshd — la supervision openrc n'est pas fiable dans un conteneur dont le PID 1 est l'entrypoint.
- **Copie temporaire des clés partagées** : OpenSSH refuse toute clé privée avec des bits de groupe (« Permissions too open »), ce qui est incompatible avec le partage de clés par ACL. Les menus copient donc la clé en `0600` dans un fichier temporaire pour la durée de la connexion (l'utilisateur peut de toute façon lire la clé partagée : exposition inchangée, suppression automatique après usage).

### Corrections de bugs

- **`server_menu.sh` — Filtre d'hôtes (`f`) inopérant** : le filtre itérait le tableau en ordre inversé (`tac`) tout en affichant des index de l'ordre normal ; les résultats affichés ne correspondaient pas aux hôtes testés et la sélection post-filtre retombait sur les index d'origine. Réécrit avec un remapping d'index correct et un re-filtrage en chaîne possible.
- **`admin_menu.sh` — Récursions infinies résiduelles** : `main_menu` et `servers_access_control` s'appelaient récursivement à chaque itération (`while true; do <elle-même>; done`), empilant les frames sur les sessions longues. Remplacées par des boucles propres en fin de script.
- **`server_menu.sh` — Injection de commandes sur la cible** : le chemin passé à `retrieve_file` était inséré dans `cat '${path}'` ; un chemin contenant une quote simple permettait d'exécuter du code sur le serveur cible. Les chemins sont désormais quotés pour shell POSIX, et les retours à la ligne sont rejetés (anti-injection du journal).
- **`entrypoint.sh` — Parsing fragile de `bastion_users.txt`** : le fichier était lu par découpage whitespace (`for x in $(cat file)`) ; toute ligne contenant un espace cassait la création. Désormais lecture ligne par ligne (`while IFS= read -r`), avec support des commentaires `#` et validation des champs (nom, statut, hash).
- **`admin_menu.sh` — Message contradictoire sur `transfer_rights.txt`** : le menu annonçait « fichier vide = transferts refusés pour tous » alors que le comportement réel est « vide/absent = autorisés pour tous » (conforme au code et au README). Message corrigé.
- **`admin_menu.sh` — Éditeur non atomique** : `printf > fichier` tronquait le fichier avant écriture ; un crash au milieu corrompait la configuration. Écriture via fichier temporaire puis réinjection dans l'inode d'origine (propriétaire/permissions/ACL conservés).
- **`README.md` — Incohérences corrigées** : l'exemple de ligne admin utilisait `;1;` (utilisateur) au lieu de `;0;` (administrateur) ; les hash étaient annoncés « sha-256 » alors que le format attendu (`$6$`) est **SHA-512 crypt** ; `bastion_users.txt` livré sans newline final.
- **Clés privées des cibles lisibles par le monde entier** : `/opt/public` était en `775`, exposant les clés à tous les comptes du conteneur. Corrigé par le modèle de permissions ACL.
- **Connexions suspendues** : ajout de `ConnectTimeout=10` sur toutes les connexions ssh sortantes du bastion.

### Améliorations

- **Image linux/amd64 uniquement** : le Dockerfile force `--platform=linux/amd64` (les deux stages) et la CI construit avec `--platform linux/amd64`. L'architecture précédemment poussée sur Docker Hub était arm64.
- **Plus de ssh-agent** : la clé de connexion est passée directement via `ssh -i ... -o IdentitiesOnly=yes`, elle n'est plus chargée dans un agent pendant toute la durée de session.
- **`KbdInteractiveAuthentication no`** remplace l'option obsolète `ChallengeResponseAuthentication` dans `sshd_config`.
- **`bastion_users.txt`** : création des utilisateurs idempotente (redémarrage du conteneur sans erreur), dossier de clés absent signalé au lieu d'échouer silencieusement.
- **`HEALTHCHECK`** et `CMD` en `bash` explicite dans le Dockerfile ; `COPY` remplace `ADD`.
- **CI** : workflow Gitea Actions (shellcheck, shfmt, build de l'image) ajouté ; `LICENSE` (WTFPL) et `docker-compose.yml` livrés dans le dépôt.

### Fichiers modifiés

| Fichier | Changements |
|---|---|
| `server_menu.sh` | Streaming push (`cat >` distant), quoting/validations des chemins, filtre `f` réécrit, `ssh -i` au lieu de ssh-agent, sessions dans `/var/log/monosphere/sessions`, ConnectTimeout |
| `admin_menu.sh` | Suppression des récursions, éditeur atomique, chemins de sessions, texte `transfer_rights` corrigé, validation des fichiers de clés |
| `entrypoint.sh` | Permissions ACL + boucle de normalisation, parsing ligne par ligne, multi-scripts, validation PORT/auth, avertissements sécurité, supervision PID 1 |
| `sshd_config` | `DisableForwarding yes`, `AllowTcpForwarding no`, `PermitTunnel no`, `KbdInteractiveAuthentication no` |
| `Dockerfile` | Version 3.6.0, ttyrec épinglé `v1.2.0.0`, paquet `acl`, `PASSWORD_AUTH=0`, HEALTHCHECK, `COPY`, répertoires runtime |
| `bastion_users.txt` | Newline final ajouté |
| `README.md` | Defaults `PASSWORD_AUTH=0`, SHA-512, exemple admin `;0;`, streaming, sessions persistées, code 05 |
| `CHANGELOG.md` | Entrée 3.6.0 |
| `.gitea/workflows/ci.yml` | Créé (shellcheck, shfmt, build) |
| `LICENSE` | Créé (WTFPL) |
| `docker-compose.yml` | Créé (exemple prêt à l'emploi) |

### Notes de version

- **Migration** : si vous déployiez avec `PASSWORD_AUTH=1` sans l'explicité, il faut désormais passer `-e PASSWORD_AUTH=1` (déconseillé) ou basculer sur les clés SSH. Le volume de logs contient désormais `sessions/` : vérifiez que votre point de montage `/var/log/monosphere` est bien persistant si vous souhaitez conserver les enregistrements.
- Les fichiers de configuration existants (`authorized_servers.txt`, `bastion_users.txt`, `admin_rights.txt`, `transfer_rights.txt`) restent compatibles.
- Version taguée : `monosphere-bastion-3.6.0`

## [3.5.0] — 2026-07-05

### Changements cassants

- **Suppression de l'authentification par mot de passe** (`password`) pour les serveurs cibles : `sshpass` retiré du Dockerfile, les branches `password` supprimées de `scp_to_target()`, `ssh_to_target_cat()`, et du menu de connexion. Seule l'authentification par clé SSH (`key`) est désormais supportée. Si vos fichiers `authorized_servers.txt` utilisent la méthode `password`, les connexions échoueront.

### Nouvelles fonctionnalités

- **Transfert de fichiers non-interactif** : deux commandes SSH pour transférer des fichiers à travers le bastion sans stockage intermédiaire :
  - `push_file <server> <dest_path>` — envoyer stdin vers un serveur distant en une étape
  - `retrieve_file <server> <src_path>` — récupérer un fichier distant sur stdout
- **Contrôle des droits de transfert** : nouveau fichier `transfer_rights.txt` permettant aux administrateurs de restreindre les transferts par serveur et par utilisateur. Support du wildcard `*`.
- **Journalisation des transferts** : tous les transferts sont horodatés et logués dans `/var/log/monosphere/transfers.log` (user, serveur, fichier, taille, statut).
- **Consultation des logs depuis le menu admin** : nouvelle option `logs` accessible à tous les administrateurs.
- **Nouveau droit administrateur** : `transfercontrol_admins` pour gérer les droits de transfert.
- **Nouvel éditeur sécurisé** : `secure_file_editor` réécrit avec un mode ligne par ligne (commandes `e`, `i`, `d`, `wq`, `q!`) sans shell, sans `xargs`, sans échappatoire.

### Corrections de bugs

- **`admin_menu.sh` — Récursion infinie dans `sessions_viewer`** : la fonction s'appelait récursivement sans jamais revenir au menu parent, rendant le visionnage des sessions inutilisable. Réécrite avec des boucles `while`/`break`/`return` propres.
- **`admin_menu.sh` — Filtre utilisateur cassé** : typos `user_map` → `users_map` et `user_counter` → `users_counter` rendant la fonction de filtrage inopérante.
- **`admin_menu.sh` — Menu vide `0)`** : les lignes sans description (champ 2 vide) ne sont plus affichées comme des options.
- **SCP : guillemets littéraux dans le chemin distant** : les `\"${path}\"` étaient passés comme caractères littéraux à SCP, le serveur distant cherchait des fichiers nommés avec des guillemets.
- **Permission du log de transfert** : `/var/log/monosphere/` créé avec les bons droits dans le Dockerfile et l'entrypoint.
- **Destination de download : validation du nom** : `basename()` appliqué sur le nom de destination pour éviter les fuites de chemin.
- **Délégation SSH_ORIGINAL_COMMAND** : les commandes non-interactives (`push_file`, `retrieve_file`) fonctionnent désormais aussi pour les administrateurs (`bastionadmin`), pas seulement les utilisateurs (`bastionuser`).

### Améliorations

- **Refactoring de l'authentification cible** : mutualisation de la logique d'auth (key/noauth) dans `scp_to_target()` et `ssh_to_target_cat()`.
- **Défense en profondeur** : droits de transfert vérifiés pour `push_file` ET `retrieve_file`.
- **Dockerfile** : création du répertoire de logs à la construction avec les permissions correctes.
- **Robustesse** : initialisation défensive du fichier de log dans `server_menu.sh`.
- **Sécurité** : `set +H` dans `secure_file_editor` pour éviter l'expansion d'historique.

### Fichiers modifiés

| Fichier | Changements |
|---|---|
| `server_menu.sh` | + `push_file`/`retrieve_file`/`check_transfer_rights`/`scp_to_target`/`ssh_to_target_cat` ; retrait du menu interactif, de `stage_file`, et de l'auth password |
| `admin_menu.sh` | + délégation SSH_ORIGINAL_COMMAND, + `transfer_rights_control` ; `secure_file_editor` réécrit ; correction récursion/typos ; retrait des références password |
| `entrypoint.sh` | Création des repertoires et fichiers de logs avec permissions |
| `Dockerfile` | Version bump 3.4.11 → 3.5.0, création du log à la construction, retrait de `sshpass` |
| `README.md` | Nouvelle doc transfert, droits, volumes, sommaire ; retrait de la doc password pour serveurs cibles |
| `admin_rights.txt` | Ajout du droit `transfercontrol_admins` |
| `transfer_rights.txt` | Nouveau fichier (créé) |
| `sshd_config` | Renforcement des paramètres de sécurité |
| `CHANGELOG.md` | Fichier créé |

### Notes de version

- L'authentification par mot de passe pour les serveurs cibles (`sshpass`) a été supprimée. Migrez vers des clés SSH (`key`).
- Changements non cassants pour le reste : les fichiers de configuration existants (`authorized_servers.txt`, `bastion_users.txt`, `admin_rights.txt`) restent compatibles.
- Version taguée : `monosphere-bastion-3.5.0`
