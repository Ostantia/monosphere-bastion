# Monosphere Bastion
Le projet Monosphere Bastion est un bastion SSH simple et sécurisé basé sur Ubuntu 22.04. Il offre une interface de menu permettant aux utilisateurs autorisés de se connecter à différents serveurs.

## Sommaire
- [Sommaire](#sommaire)
- [Objectifs des mises à jour](#objectifs-des-mises-à-jour)
- [Installation](#installation)
- [Utilisation](#utilisation)
  - [Lancement et mise en service](#lancement-et-mise-en-service)
  - [Utilisation de l'interface de connexion](#utilisation-de-linterface-de-connexion)
  - [Utilisation avec l'option JumpHost](#utilisation-avec-loption-jumphost)
- [Personnalisation](#personnalisation)
  - [Utilisateurs autorisés et serveurs](#utilisateurs-autorisés-et-serveurs)
    - [Ajout d'utilisateurs](#ajout-dutilisateurs)
      - [Avec le répertoire de configuration des utilisateurs "/root/scripts/users/" et le fichier "bastion_users.txt".](#avec-le-répertoire-de-configuration-des-utilisateurs-rootscriptsusers-et-le-fichier-bastion_userstxt)
      - [Par l'ajout des utilisateurs avec la commande adduser et usermod.](#par-lajout-des-utilisateurs-avec-la-commande-adduser-et-usermod)
      - [Les clés SSH](#les-clés-ssh)
    - [Ajout de serveurs](#ajout-de-serveurs)
    - [Audit des sessions](#audit-des-sessions)
  - [Scripts personnalisés](#scripts-personnalisés)
  - [Configuration SSH](#configuration-ssh)
  - [Fichiers](#fichiers)
- [Sécurisation](#sécurisation)
- [License](#license)

## Objectifs des mises à jour
Ci dessous une liste non exaustive des objectifs des prochaines mises à jour du projet:
- [X] Ajouter le support pour une clé SSH par serveur.
- [ ] Ajouter le support pour un serveur LDAP.
- [X] Ajouter un système de création d'utilisateurs automatique et sécurisé lors du déploiement à partir d'une liste donnée user:mot_de_passe_chiffré.
- [ ] Ajouter un système de mise à jour automatique dans le conteneur, évitant ainsi les redéploiements.
- [x] Ajouter un support pour des ports autres que 22 sur les machines distantes.
- [X] Réduire le nombre de layers dans le Dockerfile.
- [x] Changer l'image de base pour Ubuntu 22.04.
- [x] Ajouter le support pour différents utilisateurs distants.
- [x] Intégration de ttyrec pour la sauvegarde des sessions effectuées sur le bastion.

## Installation
Pour installer Monosphere Bastion, clonez ce dépôt et construisez l'image Docker en utilisant le fichier Dockerfile fourni.

```bash
git clone https://gitea.cloudyfy.fr/Siphonight/monosphere-bastion.git
cd monosphere-bastion
docker build -t monosphere-bastion .
```

Vous pouvez également télécharger directement l'image depuis docker hub :
```bash
docker pull siphonight/monosphere-bastion:<version_choisie>
```

## Utilisation

### Lancement et mise en service
Pour lancer un conteneur Monosphere Bastion, exécutez la commande suivante :

```bash
docker run -d -p 22:22 --name monosphere-bastion monosphere-bastion:latest
```

Vous pouvez également personnaliser les variables d'environnement lors de l'exécution du conteneur :

```bash
docker run -d -p 22:22 \
  -e PORT=22 \
  -e PASSWORD_AUTH=1 \
  -e KEY_AUTH=1 \
  -e HOSTNAME=monosphere-bastion \
  -v /datasets/monosphere-bastion/servers:/opt/public/servers \
  -v /datasets/monosphere-bastion/custom-scripts:/opt/custom/scripts \
  -v /datasets/monosphere-bastion/users:/root/scripts/users \
  -p "22:22" \
  --name monosphere-bastion monosphere-bastion:latest
```

Il est également possible d'utiliser docker-compose afin de déployer ce conteneur.
  
Ci dessous un exemple de déploiement possible :
  
```yaml
version: "3.0"
services:
  monosphere-bastion:
    image: siphonight/monosphere-bastion:0.5.0
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
  ports:
    - 22:22
  restart: unless-stopped
```
Dans les exemples de la commande **docker run** et du ficheir docker compose, nous avons défini des variables et des répertoires.
Ci dessous l'explication pour chacun d'entre eux:
| **Variables d'environnements** | Valeurs par défaut | *Description* |
|---|---|---|
| **PORT** | 22 | *Désigne le port d'écoute du service SSH du bastion.* |
| **PASSWORD_AUTH** | 1 | *Activer ou non l'utilisation des mots de passes comme moyen d'authentification sur le bastion (0(non) ou 1(oui)).* |
| **KEY_AUTH** | 1 | *Activer ou non l'utilisation des clés publiques comme moyen d'authentification sur le bastion (0(non) ou 1(oui)).* |
| **HOSTNAME** | monosphere-bastion | *Nom d'hôte qui sera utilisé dans le conteneur du bastion.* |

A noter que mettre la valeur à "1" pour **PASSWORD_AUTH** ne générera pas de mots de passes pour les utilisateurs, de même que mettre un "1" à **KEY_AUTH** ne générera pas de clés d'authentification. Cela pourrait être l'objet d'une future mise à jour si cette fonctionnalité est demandée.

| **Volumes** | fichiers attendus | *Description* |
|---|---|---|
| **/opt/public/servers** | Le répertoire doit contenir un fichier nommé "**authorized_servers.txt**", contenant les autorisations de connexion et la liste des informations de machines distantes. La syntaxe est décrite plus bas dans la partie "**Utilisateurs autorisés et serveurs**" | *Ce fichier est ce qui vas gérer les droits accordés aux comptes sur les différents serveurs distants en temps réel. Une modification du fichier entrainera donc directement une modification au niveau des droits de connexion des utilisateurs, et des serveurs* |
| **/opt/custom/scripts** | Ce répertoire doit contenir les scripts personnalisés de l'utilisateur, tous avec l'extension ".sh". Ces derniers seront exécutés avec le compte root au lancement du conteneur. | *Ces scripts peuvent servir à personnaliser plus amplement le conteneur du bastion, en modifiant par exemple la bannière en temps réel ou bien en changeant les paramètres du bastion qui ne sont pas disponibles avec une modification par variables d'environnement ou volumes.* |
| **/root/scripts/users** | Un fichier nommé "**bastion_users.txt**" et contenant la liste des utilisateurs et de leurs paramètres de configuration. La syntaxe exacte de ce fichier est précisée plus bas dans la section "**Ajout d'utilisateurs**". Si vous activez l'option pour l'authentification par clé, vous devez également placer ici les dossiers aux noms des utilisateurs ajoutés ayant le contenu de leur répertoire "**.ssh**" avec les fichiers des clés publiques de connexion à l'utilisateur, mais également les fichiers des clés privées pour la connexion aux serveurs distants, dont l'utilisation est précisée plus bas dans la section "**Ajout d'utilisateurs**" | *Grace à ces paramètres, il est possible d'utiliser ce conteneur bastion de manière 100% stateless, car le redéployer en utilisant la même configuration et les mêmes fichiers permettrait de répliquer les mêmes comportements.* |

A noter que les droits mis sur les fichiers et dossiers configurés dans ces volumes ne sont pas importants, car ces derniers seront adaptés lors du déploiement du conteneur bastion.


### Utilisation de l'interface de connexion
Lors de l'utilisation de l'interface terminal, il y a 3 cas dans lesquels l'utilisateur peut se trouver lorsqu'il réussit une connexion au bastion.

En premier, le cas ou un utilisateur a bien un compte enregistré sur le bastion, mais n'a aucun serveur autorisé dans le fichier "**authorized_servers.txt**" à son nom :
```text
root@ubuntu-test / [255]# ssh test@172.17.0.4

@@@@@@@@@@[Welcome to the Monosphere bastion]@@@@@@@@@@
Authorized personnel only is allowed to come here.
If you're not authorized personnel, please disconnect
from this interface this instant.

-------------------------------------------------------
Monosphere is logging the current connection.

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

Monosphere version is 0.4.1 Alpha
test@172.17.0.4's password: 
Vous n'avez pas l'autorisation de vous connecter à un serveur.
Connection to 172.17.0.4 closed.
```

Le second cas, l'utilisateur a bien un serveur sur lequel son nom est autorisé, mais une connexion par clé SSH n'a pas été configurée :
```text
root@ubuntu-test /# ssh test@172.17.0.4

@@@@@@@@@@[Welcome to the Monosphere bastion]@@@@@@@@@@
Authorized personnel only is allowed to come here.
If you're not authorized personnel, please disconnect
from this interface this instant.

-------------------------------------------------------
Monosphere is logging the current connection.

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

Monosphere version is 0.4.1 Alpha
test@172.17.0.4's password: 
Veuillez sélectionner un serveur auquel vous connecter :
1) test-ubuntu-2 - 172.17.0.6
Votre choix (1-1): 1
Connexion à 172.17.0.6...
The authenticity of host '172.17.0.6 (172.17.0.6)' can't be established.
ECDSA key fingerprint is SHA256:EW3Kr7hjEGbKN/w6XdJxn8Ktinoy1PuPdXOY21/003c.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '172.17.0.6' (ECDSA) to the list of known hosts.
test@172.17.0.6's password: 
Welcome to Ubuntu 22.04.2 LTS (GNU/Linux 5.15.0-58-generic x86_64)

test@test-ubuntu-2:~$ 
```

Enfin, le cas ou un utilisateur a bien un serveur autorisé et une clé ssh a bien été configurée sur le bastion et sur le serveur de destination :
```text
root@Alicee:~/.ssh# ssh -p 2336 -i id_rsa siphonight@kaitokid.cloudyfy.fr
@@@@@@@@@@[Welcome to the Monosphere bastion@@@@@@@@@@
Authorized personnel only is allowed to come here.
If you're not authorized personnel, please disconnect
from this interface this instant.

-------------------------------------------------------
Monosphere is logging the current connection.

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

Monosphere version is 0.5.0 Alpha
Veuillez sélectionner un serveur auquel vous connecter :
1) test-container1 - siphonight 172.19.0.12:22
Votre choix (1-1): 1
Connexion à 172.19.0.12 22 siphonight test...
Welcome to Ubuntu 24.04 LTS (GNU/Linux 5.15.0-105-generic x86_64)

test@test-ubuntu-2:~$ 
```

***Depuis la version 0.5.1, les sessions ont désormais un timer d'inactivité. Ce dernier est de 5 minutes et fermera les sessions dépassant une inactivité au delà de ce délai, avec un avertissement 60 secondes avant fermeture. Les sessions ouvertes par les utilisateurs internes au bastion sur le bastion lui même ne sont pas conccernées par ce changement.***


### Utilisation avec l'option JumpHost
Enfin, si vous souhaitez par exemple effectuer un transfert de fichiers au travers de la commande **scp**, il est toujours possible de passer par le bastion avec l'option **-J** de la commande **ssh** :
```bash
ssh -J utilisateur@ip_bastion utilisateur@ip_distante
```


## Personnalisation


### Utilisateurs autorisés et serveurs
Pour définir les utilisateurs autorisés et les serveurs auxquels ils peuvent se connecter, modifiez le fichier **authorized_servers.txt** dans le répertoire **/opt/public/servers/**. Chaque ligne doit contenir l'adresse IP du serveur, le port, le nom personnalisé du server, le nom d'utilisateur de connexion et le nom d'utilisateur, séparés par des espaces :

```txt
192.168.1.10 22 server1 server_user1 user1,user2 privkey1
192.168.1.11 2222 server2 server_user2 user2
```
L'indication de la clé privée pour la connexion au hôtes distants n'est pas obligatoire mais fortement recommandée. Si vous n'en avez pas besoin vous pouvez ne pas indiquer le nom de la clé privée.

Explication de la construction des lignes du fichier:
```txt
[Adresse_IP] [Port] [Nom_du_serveur/Hostname] [Nom_de_utilisateur_de_connexion] [Usilisateurs_autorisés] [Nom_de_clé_privée_a_utiliser]
```

Comme montré ci dessus, il est possible de mettre plusieurs noms d'utilisateurs sur un seul et même serveur, dans le cas ou plusieurs utilisateurs sont autorisés à se connecter sur la machine distante et sur le même utilisateur distant.
Ces noms d'utilisateurs du bastion doivent bien être séparés par des virgules, comme dans l'exemple.

Si vous souhaitez vous connecter sur la même machine distante mais avec un utilisateur distant différent, créez dans ce cas une nouvelle ligne le référençant. L'ajout de plusieurs noms d'utilisateurs distants sur une seule et même ligne de configuration n'est pas supporté.

A savoir qu'il est également possible d'utiliser des noms de domaine DNS, mais prenez en compte le fait que la résolution de nom se fera au niveau du bastion et non du client.

#### Ajout d'utilisateurs
Les utilisateurs configurés sur le bastion peuvent être séparés en 2 types :
- Les utilisateurs clients du bastion
- Les utilisateurs internes du bastion

Les utilisateurs clients du bastion sont ceux faisant partie du groupe "**bastionuser**", et auront le menu du bastion affiché lors de chaque connexion au bastion. Ces derniers ne peuvent pas se connecter au bastion directement et n'ont donc accès qu'à l'interface de sélection des serveurs.

Les utilisateurs internes du bastion quant à eux sont capables de se connecter au conteneur bastion directement. Ils ne font pas partie du groupe "**bastionuser**" et ne sont donc pas automatiquement redirigés vers le menu de sélection lors de la connexion (Ils peuvent cependant y accéder en lançant le script du menu).

***Bien prendre en compte le fait que depuis la version 0.5.1, les utilisateurs marqués comme internes au bastion ont un accès sudo à la commande ttyplay et ls afin de permettre l'audit du bastion et des connexions effectuées.***

***Toute modification des configurations utilisateur du bastion nécessite un redémarrage du conteneur (ou bien une relance du script entrypoint.sh), sauf dans le cas ou ces dernières sont effectuées dans le conteneur lui même par la commande usermod.***

***Ajouter les utilisateurs de connexion au fichier **authorized_servers.txt** ne suffit pas à les inscrire sur le bastion. Pour cela, il faut leur créer un compte, ce qui peut être fait de plusieurs manières, dont voici les 2 principales :***

##### Avec le répertoire de configuration des utilisateurs "**/root/scripts/users/**" et le fichier "**bastion_users.txt**".
Afin de rendre ce conteneur bastion "stateless", il est possible d'utiliser la fonctionnalité de création automatique des utilisateurs par fichier et dossier de configuration.
Pour cela, il faut placer un fichier nommé "**bastion_users.txt**" dans le répertoire "/root/scripts/users".

Ce fichier devra avoir la syntaxe suivante pour chacune de ses lignes :
```text
<Nom utilisateur>;<type utilisateur>;<mot de passe>;<clé SSH>
```
Explication des  valeurs possibles :
- **<Nom utilisateur>** : Définit le nom de l'utilisateur. Ce dernier doit être entièrement en minuscules et peut contenir des carachtères alphanumériques.
- **<type utilisateur>** : Définit le type de l'utilisateur (si c'est un utilisateur interne ou client du bastion). La valeur 0 signifie que ce derneir sera interne au bastion tandis que la valeur 1 le placera dans le groupe des utilisateurs clients du bastion ("**bastionuser**").
- **<mot de passe>** : Champ pour entrer le mot de passe de l'utilisateur si il en a un. Il est possible de ne pas donner de mot de passe à l'utilisateur en mettant "0" à cet endroit.
- **<clé SSH>** : Définit si l'utilisateur aura une ou des clés SSH configurées ou non. Mettez la valeur à "1" si vous souhaitez que ce soit le cas, 0 si vous ne le voulez pas.


Ci dessous un exemple de configuration possible, avec un utilisateur "**bastion**" ayant pour mot de passe "**bastion**", étant un utilisateur interne du bastion, et ayant des clés SSH configurées :
```text
bastion;0;bastion;1
```

##### Par l'ajout des utilisateurs avec la commande adduser et usermod.

Exemple :
```bash
root@monosphere-bastion:/# adduser test
Adding user `test' ...
Adding new group `test' (1001) ...
Adding new user `test' (1001) with group `test' ...
Creating home directory `/home/test' ...
Copying files from `/etc/skel' ...
New password: 
Retype new password: 
passwd: password updated successfully
Changing the user information for test
Enter the new value, or press ENTER for the default
        Full Name []: 
        Room Number []: 
        Work Phone []: 
        Home Phone []: 
        Other []: 
Is the information correct? [Y/n] Y
```
La commande ci dessus a bien ajouté un utilisateur "test" avec le mot de passe qui lui a été défini lors des questions de cette commande.

Puis, si vous souhaitez que ce dernier soit limité à l'accès au serveur distant et non au bastion lui même ajoutez cet utilisateur au groupe "bastionuser" avec la commande usermod.

Exemple :
```
root@monosphere-bastion:/# usermod -aG bastionuser test
```

Cet utilisateur pourra désormais ce connecter au bastion.
A noter qu'un utilisateur créé avec cette méthode ne sera pas sauvegardé dans les configurations du bastion et ne persistera de ce fait pas entre les redéploiements.

##### Les clés SSH

Les utilisateurs peuvent avoir des clés SSH de connexion configurées.

Par le terme "clés SSH" il est sous entendu qu'ils peuvent avoir un fichier "authorized_keys" contenant les clés publiques des futurs clients cherchant à se connecter au bastion sur le dit utilisateur.

Pour configurer cela, il suffit de placer dans le répertoire "**/root/scripts/users**" un dossier ayant un nom correspondant avec l'utilisateur auquel il est rattaché et contenant les fichiers du répertoire "**.ssh**" de cet utilisateur.

Lors du process de déploiement, le contenu de ce répertoire sera copié dans le répertoire "home" de l'utilisateur du bastion, et sera utilisé par la suite pour les connexions des clients au bastion.

#### Ajout de serveurs
Contrairement aux utilisateurs, il n'est pas nécessaire d'ajouter plus de configurations pour les serveurs de destination.

Cependant, il est tout de même plus intéressant de mettre en place des clés ssh, car ces dernières permettent une connexion automatique lors de la séléction du serveur dans le menu du bastion. Sans cela, il vous sera demandé d'entrer le mot de passe du compte distant à chaque tentative de connexion.

Pour générer une clé SSH utilisable pour ce cas, vous pouvez executer la commande ci dessous (en l'adaptant à votre situation) :
```text
test@monosphere-bastion:~/.ssh$ ssh-keygen -t ed25519
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

Il vous suffira ensuite d'executer la commande **ssh-copy-id test@ip_serveur_distant** pour transférer la clé publique vers le serveur distant, puis placer le fichier de la clé privée dans le répertoire **/opt/public/servers/** et adapter le ficheir de configuration des connexion distantes "**authorized_servers.txt**" en y ajoutant à la suite des utilisateurs autorisés le nom de la clé privée de connexion ainsi créé.

***Contrairement aux modifications sur les utilisateurs, il n'est pas nécessaire de redéployer le conteneur du bastion pour les modifications concernant les serveurs.***

#### Audit des sessions 
Avec l'intégration de ttyrec (version de OVH compilée depuis le repository git : https://github.com/ovh/ovh-ttyrec), il est désormais possible pour les utilisateurs internes du bastion de visionner les sessions de connexion des utilisateurs.

Pour ce faire, dconnectez vous avec un utilisateur configuré plus haut comme étant interne au bastion :
```
root@Example:~# ssh -p 2336 -i /root/.ssh/id_ed25519 bastion@bastion.example.com

@@@@@@@@@@[Welcome to the Monosphere bastion]@@@@@@@@@@
Authorized personnel only is allowed to come here.
If you're not authorized personnel, please disconnect
from this interface this instant.

-------------------------------------------------------
Monosphere is logging the current connection.

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

Monosphere version is 0.5.1 Alpha
Welcome to Ubuntu 22.04.4 LTS (GNU/Linux 5.15.0-105-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

This system has been minimized by removing packages and content that are
not required on a system that users do not log into.

To restore this content, you can run the 'unminimize' command.
Last login: Sat Jun 15 23:17:56 2024 from 192.168.1.254
foret@test-monosphere-bastion:~$
```

Ensuite, effectuez la commande "sudo ls /home/" afin de lister les dossiers des utilisateurs du bastion, puis "sudo ls /home/<utilisateur à auditer>/" afin de lister toutes les sessions enregistrées par ttyrec pour cet utilisateur.

Le nom des sessions suite une nomenclature telle que :
[date au format ANNEE-MOIS-JOUR.HEURE-MINUTE-SECONDE].[NUMERO IDENTIFIANT LA SESSION].--[ADRESSE IP DU SERVEUR DE CONNEXION]-[UTILISATEUR DE LA CONNEXION DISTANTE]--.ttyrec

Et enfin, entrez la commande "sudo ttyplay /home/<utilisateur à auditer>/<identification de la session à visionner>.ttyrec" pour voir la session de cet utilisateur.

Ci dessous un exemple de l'utilisation de ces commandes :
```
foret@test-monosphere-bastion:~$ sudo ls /home/
foret  foxy  doliprane  siphonight
foret@test-monosphere-bastion:~$ sudo ls /home/siphonight/
2024-06-15.23-55-49.312745.--192.168.1.7-siphonight--.ttyrec
foret@test-monosphere-bastion:~$ sudo ttyplay /home/siphonight/2024-06-15.23-55-49.312745.--192.168.1.7-siphonight--.ttyrec
[...]
```

### Scripts personnalisés
Vous pouvez ajouter des scripts personnalisés qui seront exécutés au démarrage du conteneur. Placez vos scripts dans le répertoire **/opt/custom/scripts/** et assurez-vous qu'ils ont les permissions d'exécution appropriées.


### Configuration SSH
La configuration du serveur SSH est définie dans le fichier **sshd_config**. Vous pouvez personnaliser cette configuration en modifiant ce fichier. N'oubliez pas que certaines options sont spécifiques au bastion et ne doivent pas être modifiées sans une bonne raison.


### Fichiers
- **Dockerfile** : Le fichier Dockerfile pour construire l'image Monosphere Bastion.
- **sshd_config** : Le fichier de configuration du serveur SSH.
- **server_menu.sh** : Le script principal du bastion qui génère le menu de sélection du serveur pour les utilisateurs autorisés.
- **authorized_servers.txt** : Liste des serveurs autorisés et des serveurs correspondants.
- **bastion_users.txt** : Liste servant à créér les utilisateurs du bastion et contenant leurs paramètres de création.
- **monosphere_banner.txt** : Bannière affichée par Monosphere lors de la connexion SSH.
- **ssh-launcher.sh** : Script exécuté toutes les 5 minutes servant à redémarrer le service ssh en cas de plantage.
- **entrypoint.sh** : Le script d'entrée qui configure et démarre les services nécessaires.


## Sécurisation
Bien que la configuration de base de Monosphere soit satisfaisante pour la plupart des cas d'utilisation, il est important de noter que des équipements critiques peuvent nécessiter plus d'attention.

Il est alors possible de renforcer la sécurité de la connexion au bastion et en dehors de plusieurs manières :
- Désactiver l'utilisation de l'authentification par mots de passes, et passer par un système de clés SSH uniquement. Exemple de modifications dans le fichier **sshd_config** :
```bash
PubkeyAuthentication yes
[...]
PasswordAuthentication no
```
- Limiter les ports de connexion vers les serveurs distants. Exemple avec une limitation sur le port 22 uniquement :
```bash
PermitOpen *:22
```
- Protéger l'accès au bastion par un VPN (WireGuard, OpenVPN...).


## License
Ce projet est publié sous la licence "Faites ce que vous souhaitez".