# Monosphere Bastion

Le projet Monosphere Bastion est un bastion SSH simple et sécurisé basé sur Alpine en version 3.20.0.
Il offre une interface de menu permettant aux utilisateurs autorisés de se connecter à différents serveurs.

## Sommaire

- [Monosphere Bastion](#monosphere-bastion)
  - [Sommaire](#sommaire)
  - [Fonctionnalités du bastion](#fonctionnalités-du-bastion)
  - [Pourquoi choisir ce bastion ?](#pourquoi-choisir-ce-bastion-)
  - [Objectifs des mises à jour](#objectifs-des-mises-à-jour)
  - [Fonctionnement des versions](#fonctionnement-des-versions)
  - [Mise en place](#mise-en-place)
    - [Création ou téléchargement du bastion](#création-ou-téléchargement-du-bastion)
    - [Lancement et mise en service](#lancement-et-mise-en-service)
    - [Valeurs et configurations par défaut](#valeurs-et-configurations-par-défaut)
  - [Personnalisation](#personnalisation)
    - [Configuration des utilisateurs, administrateurs et serveurs](#configuration-des-utilisateurs-administrateurs-et-serveurs)
      - [Ajout d'administrateurs](#ajout-dadministrateurs)
      - [Ajout d'utilisateurs](#ajout-dutilisateurs)
      - [Configuration de la connexion par clés SSH pour les utilisateurs et administrateurs](#configuration-de-la-connexion-par-clés-ssh-pour-les-utilisateurs-et-administrateurs)
      - [Ajout de serveurs distants dans la configuration](#ajout-de-serveurs-distants-dans-la-configuration)
      - [Configuration des accès aux hotes distants](#configuration-des-accès-aux-hotes-distants)
      - [Audit des sessions](#audit-des-sessions)
    - [Scripts personnalisés](#scripts-personnalisés)
    - [Configuration SSH](#configuration-ssh)
    - [Fichiers](#fichiers)
  - [License](#license)
  - [Remerciements](#remerciements)

## Fonctionnalités du bastion

Voici une liste des différentes fonctionnalités déjà en place sur le bastion Monosphere :

- Création et configuration automatisée du bastion au lancement (ce conteneur est entièrement stateless, signifiant qu'il peut être redéployé sans souci, les configurations de ce dernier étant sous forme de fichiers).
- Support des utilisateurs de connexion multiples pour les hôtes distants.
- Support pour la connexion par clés SSH (le support pour la connexion automatisée en mot de passe est prévu.)
- Sessions enregistrées et visionnables par les administrateurs du bastion ayant les autorisation appropriées.
- Support pour l'execution de scripts personalisés au lancement du conteneur.

## Pourquoi choisir ce bastion ?

- Le bastion Monosphere est entièrement écrit en bash avec un code lisible et facilement compréhensible.
- Cette caratéristique lui permet de rester très personnalisable et accessible tout en conservant sa robustesse et ses fonctionnalités.
- L'image a été optimisée afin de n'utiliser que le strict nécessaire pour le bon fonctionnement du bastion, en prenant des paquets reconnus et audités.
- Il est facilement scalable, il est possible de déployer plusieurs conteneurs du bastion Monosphere avec les mêmes fichiers de configuration afin de créer une forme de "cluster" de bastions Monosphere. (Une fonctionnalité plus avancée de clustering est actuellement en cours de développement)
- Sa prise en main est de plus très simple, tout les détails des configurations possibles se trouvant dans cette documentation.
- Enfin ce bastion est très léger, facilement administrable et ne nécessite pas d'applicatif complémentaire, autre que le support du protocole SSH.
- Il est de ce fait parfait pour de petits et moyens projets, comme pour des homelabs par exemple.

## Objectifs des mises à jour

Ci-dessous une liste non exhaustive des objectifs des prochaines mises à jour du projet:

- [ ] Ajouter une option pour le transfert de fichiers au travers du bastion vers les machines distantes.
- [ ] Ajouter une option de recherche d'hôtes distants dans la liste des serveurs.
- [ ] Ajouter une option sous forme de variable d'environnement pour fournir au bastion les clés d'hôtes des machines distantes. (avec un mode confiance, strict ou test par exemple)
- [ ] Ajouter le support pour un serveur LDAP. (Objectif sur le long terme)
- [ ] Ajouter un système de mise à jour automatique dans le conteneur, évitant ainsi les redéploiements.
- [x] Ajouter la possibilité de revenir dans le menu des serveurs après une déconnexion d'une machine distante.
- [ ] Ajouter un système de cluster avec master/slave et synchronisation entre les nodes.
- [ ] Améliorer le système de journalisation du déploiement du bastion, avec les erreurs de déploiement affichées lors de la connexion des utilisateurs internes.
- [x] Ajouter un menu d'administration et de gestion lors de la connexion des utilisateurs internes du bastion.
- [x] Créer des rôles administrateur/inspecteur avec des droits différents au sein du bastion.

Correction en cours pour les bugs ci dessous :

Aucun bug n'a été détecté dans les configuration et scripts actuels du bastion, ou ces derniers ont bien été corrigés.

Veuillez signaler tout problème rencontré en envoyant un email à l'adresse "**<crossghostmansiphonight@gmail.com>**", détaillant le problème ainsi que le contexte entourant le constat de ce dernier.

## Fonctionnement des versions

Le bastion Monosphere étant en constante évolution, des changements fréquents sont à prévoirs sur ce projet.
Les modifications apportées incrémentent ou non le numéro de version. Ci dessous un exemple :

| **Version majeure** | **Version mineure** | **Correctifs** |
|---|---|---|
| 0 | 5 | 3 |
| La version majeure est de 0. Cette dernière n'est incrémentée que lorsqu'une fonctionnalité ou un patch créant des changements cassants est ajoutée. Lorsque vous devrez faire une mise à jour d'une version majeure à une autre, un guide de mise à jour pour vos configurations sera mis à disposition. | La version mineure est 5. Elle est incrémentée a chaque ajout de mise à jour non cassante qui ajoute des capacités et/ou fonctionnalités au bastion. Une mise à jour d'une version mineure à l'autre ne nécessite pas de modifications dans vos configurations existantes. | La version du correctif est 3. Cette dernière est incrémentée à chaque patch ou amélioration non cassante qui n'ajoute pas de nouvelles fonctionnalités mais qui améliore ou corrige celles qui sont déjà en place. Une mise à jour d'une version de correctif à une autre peut se faire sans risque et sans modification des configurations existantes. |

**La façon la plus sure à l'heure actuelle pour effectuer une mise à jour est de redéployer le conteneur du bastion.**

## Mise en place

### Création ou téléchargement du bastion

Pour installer et utiliser le Monosphere Bastion, plusieurs approches sont possibles :

- Vous pouvez cloner ce dépôt et construire l'image Docker en utilisant le fichier Dockerfile fourni.

```bash
git clone https://gitea.cloudyfy.fr/Siphonight/monosphere-bastion.git
cd monosphere-bastion
docker build -t monosphere-bastion .
```

- Vous pouvez également télécharger directement l'image depuis docker hub :

```bash
docker pull siphonight/monosphere-bastion:<version_choisie>
```

### Lancement et mise en service

Pour lancer un conteneur Monosphere Bastion avec la configuration par défaut, exécutez la commande suivante :

```bash
docker run -d -p 22:22 --name monosphere-bastion monosphere-bastion:latest
```

Vous pouvez également personnaliser les variables d'environnement et les configurations lors de l'exécution du conteneur :

```bash
docker run -d -p 22:22 \
  -e PORT=22 \
  -e PASSWORD_AUTH=1 \
  -e KEY_AUTH=1 \
  -e HOSTNAME=monosphere-bastion \
  -v /datasets/monosphere-bastion/servers:/opt/public/servers \
  -v /datasets/monosphere-bastion/custom-scripts:/opt/custom/scripts \
  -v /datasets/monosphere-bastion/users:/root/scripts/users \
  -v /datasets/monosphere-bastion/admin_rights:/opt/public/rights \
  -p "22:22" \
  --name monosphere-bastion siphonight/monosphere-bastion:latest
```

Il est également possible d'utiliser docker-compose afin de déployer ce conteneur.

Ci-dessous un exemple de déploiement possible :

```yaml
version: "3.3"
services:
  monosphere-bastion:
    image: siphonight/monosphere-bastion:latest
    container_name: monosphere-bastion
    environment:
    - PORT=22
    - PASSWORD_AUTH=1
    - KEY_AUTH=1
    - HOSTNAME=monosphere-bastion
  volumes:
    - /datasets/monosphere-bastion/servers:/opt/public/servers
    - /datasets/monosphere-bastion/custom-scripts:/opt/custom/scripts
    - /datasets/monosphere-bastion/users:/root/scripts/users
    - /datasets/monosphere-bastion/admin_rights:/opt/public/rights
  ports:
    - 22:22
  restart: unless-stopped
```

Dans les exemples de la commande **docker run** et du fichier docker compose, nous avons défini des variables et des répertoires.
Ci-dessous l'explication de chacun d'entre eux:

| **Variables d'environnements** | Valeurs par défaut | *Description* |
|---|---|---|
| **PORT** | 22 | *Désigne le port d'écoute du service SSH du bastion.* |
| **PASSWORD_AUTH** | 1 | *Activer ou non l'utilisation des mots de passes comme moyen d'authentification sur le bastion (0(non) ou 1(oui)).* **PREFEREZ L'AUTHENTIIFCATION PAR CLES SSH** |
| **KEY_AUTH** | 1 | *Activer ou non l'utilisation des clés publiques comme moyen d'authentification sur le bastion (0(non) ou 1(oui)).* |
| **HOSTNAME** | monosphere-bastion | *Nom d'hôte qui sera utilisé dans le conteneur du bastion.* |

A noter que mettre la valeur à "1" pour **PASSWORD_AUTH** ne générera pas de mots de passes pour les utilisateurs, de même que mettre un "1" à **KEY_AUTH** ne générera pas de clés d'authentification. Cela pourrait être l'objet d'une future mise à jour si cette fonctionnalité est demandée.

| **Volumes** | fichiers attendus | *Description* |
|---|---|---|
| **/opt/public/servers** | Le répertoire doit contenir un fichier nommé "**authorized_servers.txt**", contenant les autorisations de connexion et la liste des informations de machines distantes. Si vous utilisez l'authentification par clés privés ou par mots de passe pré-renseignés pour la connexion aux hôtes distants vous devez également ajouter les fichiers de ces dernières dans ce même répertoire. | *Ce fichier est ce qui vas gérer les droits accordés aux comptes sur les différents serveurs distants en temps réel. Une modification du fichier entrainera donc directement une modification au niveau des droits de connexion des utilisateurs, et des serveurs auquels le bastion permettra la connexion.* |
| **/opt/custom/scripts** | Ce répertoire doit contenir les scripts personnalisés de l'utilisateur, tous avec l'extension ".sh". Ces derniers seront exécutés avec le compte root au lancement du conteneur. | *Ces scripts peuvent servir à personnaliser plus amplement le conteneur du bastion, en modifiant par exemple la bannière en temps réel ou bien en changeant les paramètres du bastion qui ne sont pas disponibles avec une modification par variables d'environnement ou volumes.* |
| **/root/scripts/users** | Un fichier nommé "**bastion_users.txt**" contenant la liste des utilisateurs et de leurs paramètres de configuration. La syntaxe exacte de ce fichier est précisée plus bas dans la section "**Ajout d'utilisateurs**". Si vous activez l'option pour l'authentification par clé, vous devez également placer ici les dossiers aux noms des utilisateurs ajoutés ayant le contenu de leur répertoire "**.ssh**" avec les fichiers des clés publiques de connexion à l'utilisateur. | *Grace à ces paramètres, il est possible d'utiliser ce conteneur bastion de manière 100% stateless, car le redéployer en utilisant la même configuration et les mêmes fichiers permet de répliquer les mêmes comportements.* |
| **/opt/public/rights** | Ce répertoire doit contenir un fichier nommé "**admin_rights**", complété avec les droits administratifs sur le bastion et des utilisateurs auquels ces droits sont accordés. | *Les droits inscrits dans ce fichier sont mis à jour en temps réels. Veuillez vous assurer que ces derniers sont corrects et attribués aux administrateurs souhaités.* |

A noter que les droits mis sur les fichiers et dossiers configurés dans ces volumes ne sont pas importants, car ces derniers sont adaptés lors du déploiement du conteneur bastion.

### Valeurs et configurations par défaut

Les valeurs par défaut ci dessous s'appliquent dans le cas où elles ne sont pas écrasées par des valeurs personalisées définies au lancement du conteneur :

- "**PORT=22**" (Port par défaut pour la connexion : 22.)
- "**KEY_AUTH=1**" (Accès au bastion par clé SSH autorisé.)
- "**PASSWORD_AUTH=1**" (Accès au bastion par mot de passe autorisé.)
- Utilisateur interne du bastion : **bastion**, avec pour mot de passe "**bastion**"

L'utilisateur par défaut du bastion est un administrateur ayant tout les privilèges administratifs nommé "**bastion**" avec pour mot de passe "**bastion**".

Une configuration de connexion serveur par defaut pour cet utilisateur est également présente.

***A noter que depuis la version 0.5.1, les sessions ont désormais un timer d'inactivité. Ce dernier est de 5 minutes et fermera les sessions dépassant une inactivité au delà de ce délai, avec un avertissement 60 secondes avant fermeture. Les sessions ouvertes par les utilisateurs internes au bastion sur le bastion lui même ne sont pas conccernées par ce changement.***

## Personnalisation

### Configuration des utilisateurs, administrateurs et serveurs

#### Ajout d'administrateurs

Le bastion Monosphère supporte les utilisateurs ayant des droits d'administration. Ces derniers sont attribués au groupe "**bastionadmin**" lors du déploiement du bastion et auront le menu d'administration affiché à chaque connexion au bastion. (ils peuvent passer sur le menu de connexion aux serveurs depuis ce dernier.)

***Toute modification du fichier "bastion_users.txt" nécessite un redémarrage du conteneur (ou bien une relance du script entrypoint.sh) pour être appliqués. Cela fait l'objet d'une prochaine mise à jour.***

Afin de créer un utilisateur avec des droits d'administration, commencez par ajouter la ligne de configuration souhaitée pour votree administrateur dans le fichier "**bastion_users.txt**" en suivant les indications ci dessous :

```text
<Nom de l'administrateur>;0;<mot de passe>;<clé SSH>
```

Explication des  valeurs possibles :

- **Nom de l'administrateur** : Définit le nom de l'administrateur. Ce dernier doit être entièrement en minuscules et peut contenir des carachtères alphanumériques.
- **0** : Permet de donner le statut d'administrateur au compte qu isera généré. Notez que ce n'est pas suffisant pour que l'administrateur ait des privilèges sur le bastion et ses ressources.
- **mot de passe** : Champ pour entrer le mot de passe de l'administrateur si il en a un. Il est possible de ne pas donner de mot de passe à l'administrateur en mettant "0" à cet endroit. Dans ce cas le mot de passe ce cet administrateur sera le nom de lui même.
- **clé SSH** : Définit si l'administrateur aura une ou des clés SSH configurées. Mettez la valeur à "1" si vous souhaitez que ce soit le cas, 0 si vous ne le voulez pas. Référez vous à la partie [Configuration de la connexion par clés SSH pour les utilisateurs et administrateurs](#configuration-de-la-connexion-par-clés-ssh-pour-les-utilisateurs-et-administrateurs) pour plus d'informations sur la configuration de cette méthode de connexion au bastion.

***Il est fortement recommandé de définir un mot de passe fort pour tout les administrateurs du bastion, en particulier lorsque l'authentification par mots de passes est activée. Dans le cas contraire la sécurité de votre bastion pourrait être compromise.***

Ensuite, attribuez des droits d'administration à l'administrateur nouvellement créé correspondants à votre besoin.

Pour cela, modifiez le fichier "**admin_rights.txt**", en vous basant sur l'exemple ci dessous :

```text
sessionswatch_admins Visionnage_des_sessions_du_bastion bastion,vieweradmin
serverscontrol_admins Administration_des_acces_serveurs bastion
```

Explication des différents droits d'administration disponibles :

- **sessionswatch_admins** : Ce droit permet aux administrateurs le possédant de lire et visionner les sessions de connexion de tout les utilisateurs et administrateurs du bastion.
- **serverscontrol_admins** : Ce droit donne la possibilité de modifier les accès des utilisateurs et administrateurs du bastion aux hôtes distants, ainsi que les méthodes d'authentification et la configuration des serveurs distants.

Dans l'exemple ci dessus, l'administrateur "bastion" à le droit de lire les sessions de connexion mais également de modifier les paramètres des connexions et accès aux serveurs distants. L'utilisateur "vieweradmin" quant à lui n'a qu'un droit de lecture des sessions du bastion, et ne pourra pas effectuer de modifications.

#### Ajout d'utilisateurs

Les utilisateurs du bastion sont ceux faisant partie du groupe "**bastionuser**", et auront le menu du bastion affiché à chaque connexion au bastion. Ces derniers n'ont donc accès qu'à l'interface de sélection des serveurs.

***Toute modification du fichier "bastion_users.txt" nécessite un redémarrage du conteneur (ou bien une relance du script entrypoint.sh) pour être appliqués. Cela fait l'objet d'une prochaine mise à jour.***

Afin de rendre ce conteneur bastion stateless, il est fortement recommandé d'utiliser la fonctionnalité de création automatique des utilisateurs par fichier et dossier de configuration.
Pour cela, il faut modifier le fichier "**bastion_users.txt**" dans le répertoire "/root/scripts/users" en ajoutant une ligne correspondante à notre utilisateur.

Ce fichier devra avoir la syntaxe suivante pour chacune de ses lignes :

```text
<Nom de l'utilisateur>;1;<mot de passe>;<clé SSH>
```

Explication des  valeurs possibles :

- **Nom de l'utilisateur** : Définit le nom de l'utilisateur. Ce dernier doit être entièrement en minuscules et peut contenir des carachtères alphanumériques.
- **1** : Permet de définir le compte comme étant celui d'un tuilisateur.
- **mot de passe** : Champ pour entrer le mot de passe de l'utilisateur si il en a un. Il est possible de ne pas donner de mot de passe à l'utilisateur en mettant "0" à cet endroit. Dans ce cas le mot de passe ce cet utilisateur sera le nom de lui même (par exemple, l'utilisateur sans mot de passe "user1" aura de ce fait pour mot de passe "user1").
- **clé SSH** : Définit si l'utilisateur aura une ou des clés SSH configurées. Mettez la valeur à "1" si vous souhaitez que ce soit le cas, 0 si vous ne le voulez pas. Référez vous à la partie [Configuration de la connexion par clés SSH pour les utilisateurs et administrateurs](#configuration-de-la-connexion-par-clés-ssh-pour-les-utilisateurs-et-administrateurs) pour plus d'informations sur la configuration de cette méthode de connexion au bastion.

***Il est fortement recommandé de définir un mot de passe fort pour tout les utilisateurs du bastion, en particulier lorsque l'authentification par mots de passes est activée. Dans le cas contraire la sécurité de votre bastion pourrait être compromise.***

Ci-dessous un exemple de configuration possible d'une ligne du fichier "**bastion_users.txt**", avec un utilisateur "**user1**" ayant pour mot de passe "**user1**", étant un utilisateur interne du bastion, et ayant des clés SSH configurées :

```text
user1;1;user1;1
```

#### Configuration de la connexion par clés SSH pour les utilisateurs et administrateurs

Les utilisateurs et administrateurs peuvent avoir des clés SSH de connexion configurées.

Par le terme "clés SSH" il est sous entendu qu'ils peuvent avoir un fichier "authorized_keys" contenant les clés publiques des futurs clients cherchant à se connecter au bastion sur le dit compte.

Pour configurer cela, il suffit de placer dans le répertoire "**/root/scripts/users**" (monté dans un volume) un dossier ayant un nom correspondant au compte auquel il est rattaché et contenant les fichiers du répertoire "**.ssh**" de ce dernier.

Lors du process de déploiement, le contenu de ce répertoire sera copié dans le répertoire "home" de l'utilisateur ou administrateur du bastion et sera utilisé par la suite pour les connexions des clients à ce compte.

***A noter que pour que cela soit effectif, la connexion par clés SSH doit être autorisée au niveau de la variable "KEY_AUTH", dont la valeur doit être de 1.***

#### Ajout de serveurs distants dans la configuration

Contrairement aux comptes du bastion, il n'est pas nécessaire d'ajouter plus de configurations que ce qui est décrit dans la partie [Configuration des accès aux hotes distants](#configuration-des-accès-aux-hotes-distants) pour les hôtes de destination.

Cependant, il est tout de même plus intéressant de mettre en place des clés ssh ou mots de passes pré-renseignés, car ces derniers permettent une connexion automatique lors de la séléction du serveur dans le menu du bastion. Sans cela, il vous sera demandé d'entrer le mot de passe du compte distant à chaque tentative de connexion.

Pour générer une clé SSH utilisable pour cette situation, il est recommandé d'utiliser la commande ci dessous (en l'adaptant à votre besoin) :

```text
test@root:~/.ssh$ ssh-keygen -t ed25519
Generating public/private ed25519 key pair.
Enter file in which to save the key (/root/.ssh/id_ed25519):
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /root/.ssh/id_ed25519
Your public key has been saved in /root/.ssh/id_ed25519.pub
The key fingerprint is:
SHA256:mdZmun0RWKMr66RSfNEC9MKpRfV02GxN1MFUOZhgWsg root@test-container1
The key's randomart image is:
+--[ED25519 256]--+
|     .o.o oBo+B+=|
|     o.o E=.*o.+.|
|      =..o.= .  .|
|     o .o++ .    |
|    ..  So+. .   |
|      o.o+. .    |
|     . .oo   .   |
|    .  o.o  .    |
|     ...o ..     |
+----[SHA256]-----+
```

Le type de clé recommandé est le "ed25519", mais pour la connexion aux serveurs distants le bastion en lui même n'a pas de restrictions particulières.

Il vous suffira ensuite d'exécuter la commande **ssh-copy-id utilisateur_distant@ip_serveur_distant** pour transférer la clé publique vers le serveur distant, puis placer le fichier de la clé privée dans le répertoire **/opt/public/servers/** (monté en volume dans le conteneur du bastion).
Enfin, adaptez le fichier de configuration des connexion distantes "**authorized_servers.txt**" en y ajoutant, à la suite des utilisateurs autorisés, le nom de la clé privée de connexion ainsi créé et en précisant la méthode d'authentification en tant que "key".

Cette dernière sera désormais utilisée par les utilisateurs du bastion inscrits sur la même ligne du fichier "**authorized_servers.txt**" afin de se connecter au serveur et utilisateur distant référencé.

***Contrairement aux modifications sur les comptes du bastion, il n'est pas nécessaire de redéployer le conteneur du bastion pour les modifications concernant les serveurs distants et leurs accès.***

#### Configuration des accès aux hotes distants

Pour définir les utilisateurs autorisés et les serveurs auxquels ils peuvent se connecter, modifiez le fichier **authorized_servers.txt** dans le répertoire **/opt/public/servers/**.

Les administrateurs du bastion ayant le droit "serverscontrol_admins" peuvent modifier la configuration des accès sur un bastion en fonctionnement, mais il est également possible de configurer ces derniers avant de déployer le bastion.

Chaque ligne doit contenir l'adresse IP du serveur, le port, le nom personnalisé du server, le nom d'utilisateur de connexion et le ou les noms d'utilisateurs du bastion, comme dans l'exemple ci dessous :

```txt
192.168.1.10 22 server1 server_user1 user1,user2 key privkey1
192.168.1.11 23 server2 server_user2 user1,admin password pass_server2
192.168.1.12 2222 server3 server_user3 user2
```

L'indication de la méthode d'authentification (password/key) n'est pas obligatoire mais fortement recommandée.
Par défaut, si aucune option d'authentification n'est configurée, le mot de passe de l'hôte distant sera demandé à l'utilisateur.

Explication de la construction des lignes du fichier:

```txt
[Adresse_IP] [Port] [Nom_du_serveur/Hostname] [Nom_de_utilisateur_de_connexion] [Usilisateurs_autorisés] [Type_authentification] [Fichier_a_utiliser]
```

Concernant la méthode d'authentification, deux options sont possibles :

- key : Précise au bastion que l'authentification sur l'hôte distant devra se faire au moyen d'une clé privée SSH précisée dans le fichier indiqué dans l'argument suivant.
- password : Précise au bastion que l'authentification sur l'hôte distant devra se faire au moyen d'un mot de passe inscrit dans le fichier indiqué dans l'argument suivant.

L'argument "Fichier_a_utiliser" indique de ce fait le nom du fichier situé dans le répertoire **/opt/public/servers/** (même répertoire que le script du menu d'authentification) contenant le secret à utiliser pour l'authentification dépendant de la méthode choisie.

A noter que si la méthode par mot de passe est sélectionnée, Le fichier indiqué devra contenir uniquement le mot de passe, en première ligne du fichier, sans aucune autre ligne complémentaire.

Comme montré dans l'exemple ci-dessus, il est possible de mettre plusieurs noms d'utilisateurs (ou d'administrateurs) sur un seul et même serveur, dans le cas où plusieurs utilisateurs sont autorisés à se connecter sur la machine distante et sur le même utilisateur distant, avec la même méthode d'authentification.
Ces noms d'utilisateurs du bastion doivent bien être séparés par des virgules.

Si vous souhaitez vous connecter sur la même machine distante mais avec un utilisateur distant différent (ou une méthode d'authentification différente), créez dans ce cas une nouvelle ligne le référençant. L'ajout de plusieurs noms d'utilisateurs distants sur une seule et même ligne de configuration n'est pas supporté.

A savoir qu'il est également possible d'utiliser des noms de domaine DNS à la place d'une adresse IP, mais prenez en compte le fait que la résolution de nom se fera au niveau du bastion et non du client.

#### Audit des sessions

Avec l'intégration de ttyrec (version de OVH compilée depuis le repository git : <https://github.com/ovh/ovh-ttyrec>), il est possible pour les utilisateurs administrateurs du bastion de visionner les sessions de connexion des utilisateurs.

Pour que les administrateurs puissent consulter les sessions, il faut que le droit "sessionswatch_admins" leur soit attribué. Consultez la partie [Ajout d'administrateurs](#ajout-dadministrateurs) pour plus d'informations.

Afin de consulter les sessions des utilisateurs, connectez vous au bastion en tant qu'administrateur ayant le droit approprié et sélectionnez l'option **"Visionnage_des_sessions_du_bastion"** :

```text
@@@@@@@@@@[Welcome to the Monosphere bastion]@@@@@@@@@@
Authorized personnel only is allowed to come here.
If you're not authorized personnel, please disconnect
from this interface this instant.

-------------------------------------------------------
Monosphere is logging the current connection.

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

Monosphere version is 2.0.5 Alpha
Veuillez sélectionner une option d'administration :
1) Visionnage_des_sessions_du_bastion
2) Administration_des_acces_serveurs
3) Tapez 'servers_access' ou 3 pour vous connecter a un serveur.
4) Tapez 'quit' ou 4 pour vous déconnecter.
Votre choix (1-4): 1
```

Ensuite, sélectionnez l'utilisateur pour lequel vous souhaitez auditer la session :

```text
Ci dessous les utilisateurs disponibles sur le bastion.
Veillez sélectionner celui dont vous souhaitez visionner les accès :
1) bastion
2) siphonight
3) Tapez 'quit' ou 3 pour revenir au menu précédent.
Votre choix (1-3): 2
```

Vous serez amené vers une liste des sessions enregistrées de l'utilisateur sélectionné.

Le nom des sessions suite une nomenclature telle que :
```text
[ANNEE-MOIS-JOUR].[HEURE-MINUTE-SECONDE].[NUMERO IDENTIFIANT LA SESSION].--[ADRESSE IP DU SERVEUR DE CONNEXION]-[UTILISATEUR DE LA CONNEXION DISTANTE]--.ttyrec
```

Enfin, sélectionnez la session que vous souhaitez visionner par son numéro indiqué :

```text
Sélectionnez une session de cet utilisateur que vous souhaitez visionner :
1) 2025-01-18.20-29-26.126316.--test-container1-siphonight--.ttyrec
2) 2025-01-19.07-16-58.318869.--sysbox-test-03-siphonight--.ttyrec
3) 2025-01-19.07-39-09.070910.--sysbox-test-03-siphonight--.ttyrec
4) 2025-01-19.08-01-48.690401.--sysbox-test-03-siphonight--.ttyrec
5) 2025-01-19.14-14-25.806138.--sysbox-test-01-siphonight--.ttyrec
6) 2025-01-19.14-14-45.815983.--test-container3-siphonight--.ttyrec
7) 2025-01-20.13-46-09.384995.--sysbox-test-03-siphonight--.ttyrec
8) 2025-01-20.15-33-17.054422.--sysbox-test-03-siphonight--.ttyrec
9) 2025-01-20.18-10-51.315600.--sysbox-test-03-siphonight--.ttyrec
10) 2025-01-20.18-44-53.584960.--sysbox-test-03-siphonight--.ttyrec
11) 2025-01-20.20-18-16.968148.--sysbox-test-03-siphonight--.ttyrec
12) 2025-01-20.20-31-27.717670.--sysbox-test-03-siphonight--.ttyrec
13) 2025-01-20.20-46-23.355923.--sysbox-test-03-siphonight--.ttyrec
14) 2025-01-20.21-28-25.433739.--test-bastion-2-bastion--.ttyrec
15) 2025-01-20.21-28-33.026137.--sysbox-test-03-siphonight--.ttyrec
16) Tapez 'quit' ou 16 pour vous revenir au choix d'utilisateur.
Votre choix (1-16): 11
```

Le visionnage des sessions "tant effectué avec ttyrec, les controles possibles avec cet outils le sont également dans ce cas.

Ci dessous les controles les plus courants :

- **+** : Accélerer le déroulement de la session.
- **-** : Ralentir le déroulement de la session.

### Scripts personnalisés

Vous pouvez ajouter des scripts personnalisés qui seront exécutés au démarrage du conteneur. Placez vos scripts dans le répertoire **/opt/custom/scripts/**.

Les droits sur ces derniers sont automatiquement mis à jour lors du déploiement du conteneur.

### Configuration SSH

La configuration du serveur SSH est définie dans le fichier **sshd_config**. Vous pouvez personnaliser cette configuration en modifiant ce fichier. N'oubliez pas que certaines options sont spécifiques au bastion et ne doivent pas être modifiées sans une bonne raison.

Ses options incluent notamment le bloc de configurations ci dessous, gérant le comportement du bastion lors des connexions d'utilisateurs :

```text
[...]
#Per user basis settings
AllowStreamLocalForwarding no
Match Group bastionuser
        ForceCommand /opt/public/scripts/server_menu.sh
        X11Forwarding no
Match Group bastionadmin
 ForceCommand /opt/public/scripts/admin_menu.sh
 X11Forwarding no
# End the 'Match' block
Match all
 ForceCommand echo -e "===========================================================\nSorry, you re not part of the bastion s users or administrators and have therefore no access.\nPlease contact your administrator for further informations.\n==========================================================="; exit
 X11Forwarding no
[...]
```

Ne modifiez jamais ces paramètres cela pourrait provoquer des problèmes de sécurité ainsi que de droits d'accès.

### Fichiers

- **admin_menu.sh** : Script permettant aux administrateurs d'exercer leurs droits au travers d'un menu controllé en fonction de leurs autorisations sur le bastion.
- **admin_rights.txt** : Liste des droits administratifs sur le bastion et ses ressources, exclusive aux administraturs du bastion.
- **authorized_servers.txt** : Liste des utilisateurs autorisés et des serveurs correspondants.
- **bastion_users.txt** : Liste servant à générer les utilisateurs et administrateurs du bastion et contenant leurs paramètres de création.
- **Dockerfile** : Le fichier Dockerfile pour construire l'image Monosphere Bastion.
- **entrypoint.sh** : Le script d'entrée qui configure et démarre les services nécessaires.
- **monosphere_banner.txt** : Bannière affichée par Monosphere lors de la connexion SSH.
- **server_menu.sh** : Le script principal du bastion qui génère le menu de sélection des serveurs de connexion pour les utilisateurs autorisés.
- **sshd_config** : Le fichier de configuration du serveur SSH.

## License

Ce projet est publié sous la licence "Faites ce que vous souhaitez".

## Remerciements

- Ouafax
- KIT!
- neutaaaaan
- Amadeus