# Monosphere Bastion
Le projet Monosphere Bastion est un bastion SSH simple et sécurisé basé sur Ubuntu 20.04. Il offre une interface de menu permettant aux utilisateurs autorisés de se connecter à différents serveurs.

## Objectifs des mises à jour
Ci dessous une liste non exaustive des objectifs des prochaines mises à jour du projet:
- [ ] Ajouter le support pour une clé SSH par serveur
- [ ] Ajouter le support pour un serveur LDAP
- [ ] Ajouter un système de mise à jour automatique dans le conteneur, évitant ainsi les redéploiements.
- [ ] Ajouter un support pour des ports autres que 22 sur les machines distantes.

## Installation
Pour installer Monosphere Bastion, clonez ce dépôt et construisez l'image Docker en utilisant le fichier Dockerfile fourni.

```bash
git clone https://github.com/your-repo/monosphere-bastion.git
cd monosphere-bastion
docker build -t monosphere-bastion .
```

Vous pouvez également télécharger directement l'image depuis docker hub :
```bash
docker pull siphonight/monosphere-bastion
 ```

## Utilisation

### Lancement et mise en service
Pour lancer un conteneur Monosphere Bastion, exécutez la commande suivante :

```bash
docker run -d -p 22:22 --name monosphere-bastion monosphere-bastion:latest
```

Vous pouvez également personnaliser les variables d'environnement lors de l'exécution du conteneur :

```bash
docker run -d -p 22:2222 \
  -e PORT=2222 \
  -e BASTIONUSER=myuser \
  -e BASTIONPASS=mypassword \
  -e HOSTNAME=my-bastion \
  --name monosphere-bastion monosphere-bastion:latest
  ```
  
  Il est également possible d'utiliser docker-compose afin de déployer ce conteneur.
  
  Ci dessous un exemple de déploiement possible :
  
  ```yaml
  version: "3.0"
services:
  monosphere-bastion:
    image: siphonight/monosphere-bastion:latest
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 1G
    container_name: monosphere-bastion
    environment:
	  - PORT=2222
      - BASTIONUSER=bastion
      - BASTIONPASS=bastion
      - HOSTNAME=monosphere-bastion
    volumes:
      - /datasets/monosphere-bastion/servers:/opt/public/servers/
	  - /datasets/monosphere-bastion/custom-scripts:/opt/custom/scripts
    ports:
      - 22:2222
    restart: unless-stopped
  ```

### Utilisation de l'interface de connexion
Lors de l'utilisation de l'interface terminal, il y a 3 cas dans lesquels l'utilisateur peut se trouver lorsqu'il réussit une connexion au bastion.

En premier, le cas ou un utilisateur a bien un compte enregistré sur le bastion, mais n'a aucun serveur autorisé dans le fichier "**authorized_servers.txt**" à son nom :
```bash
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
```bash
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

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

This system has been minimized by removing packages and content that are
not required on a system that users do not log into.

To restore this content, you can run the 'unminimize' command.
Last login: Sun Apr  9 20:18:03 2023 from 172.17.0.4
test@test-ubuntu-2:~$ 
```

Enfin, le cas ou un utilisateur a bien un serveur autorisé et a bien une clé SSH déployée depuis son compte sur le bastion et sur le serveur de destination :
```bash
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
Welcome to Ubuntu 22.04.2 LTS (GNU/Linux 5.15.0-58-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

This system has been minimized by removing packages and content that are
not required on a system that users do not log into.

To restore this content, you can run the 'unminimize' command.
Last login: Sun Apr  9 22:26:15 2023 from 172.17.0.4
test@test-ubuntu-2:~$ 
```

### Utilisation avec l'option JumpHost
Enfin, si vous souhaitez par exemple effectuer un transfert de fichiers au travers de la commande **scp**, il est toujours possible de passer par le bastion avec l'option **-J** de la commande **ssh** :
```bash
ssh -J utilisateur@ip_bastion utilisateur@ip_distante
```

## Personnalisation

### Utilisateurs autorisés et serveurs
Pour définir les utilisateurs autorisés et les serveurs auxquels ils peuvent se connecter, modifiez le fichier **authorized_servers.txt** dans le répertoire **/opt/public/servers/**. Chaque ligne doit contenir l'adresse IP du serveur, le nom personnalisé et le nom d'utilisateur, séparés par des espaces :

 ```bash
192.168.1.10 server1 user1,user2
192.168.1.11 server2 user2
```
Comme montré au dessus, il est possible de mettre plusieurs noms d'utilisateurs sur un seul et même serveur, dans le cas ou plusieurs utilisateurs sont autorisés sur la machine distante.
Ces noms d'utilisateurs doivent bien être séparés par des virgules, comme dans l'exemple.

A savoir qu'il est également possible d'utiliser des noms de domaine DNS, mais prenez en compte le fait que la résolution de nom se fera au niveau du bastion et non du client.

#### Ajout d'utilisateurs
Ajouter les utilisateurs au fichier **authorized_servers.txt** ne suffit pas à les inscrire sur le bastion. Pour cela, il suffit de leur créer un compte avec la commande adduser classique, en définissant un mot de passe fort (pas forcément le même que celui présent sur les serveurs).

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

Pour automatiser ce processus, il est également possible de le scripter.
**ATTENTION**, cette méthode laisse les mots de passes en clair dans le script !
Cette méthode est utilisable dans un contexte temporaire, mais il est préférable de changer rapidement le mot de passe.
```bash
adduser --disabled-password --gecos "" test --shell /bin/bash
echo "$test:test" | chpasswd
```

#### Ajout de serveurs
Contrairement aux utilisateurs, il n'est pas nécessaire d'ajouter plus de configurations pour les serveurs de destination.

Cependant, il est tout de même plus intéressant de mettre en place des clés ssh, car ces dernières permettent une connexion automatique lors de la séléction du serveur dans le menu du bastion. Sans cela, il vous sera demandé d'entrer le mot de passe du compte distant à chaque tentative de connexion.

Pour générer une clé SSH utilisable pour ce cas, vous pouvez executer les commandes ci dessous (en les adaptant à votre situation) :
```bash
test@monosphere-bastion:~/.ssh$ ssh-keygen -t rsa -b 4096
Generating public/private rsa key pair.
Enter file in which to save the key (/home/test/.ssh/id_rsa): 
Enter passphrase (empty for no passphrase): 
Enter same passphrase again: 
Your identification has been saved in /home/test/.ssh/id_rsa
Your public key has been saved in /home/test/.ssh/id_rsa.pub
The key fingerprint is:
SHA256:n4I6LUA7lGa+xIvKYU1lxWZbgnMuA6lbVPQLm9q3gPQ test@monosphere-bastion
The key's randomart image is:
+---[RSA 4096]----+
|    +oo.         |
|   + oo* .       |
|  o..+*.+        |
| .*.oo+o.        |
| Bo+ oo.S        |
| .@ =  . . .     |
| = O E... o      |
|+ + o.+ ..       |
|o.  .o .         |
+----[SHA256]-----+
```
Il vous suffira ensuite d'executer la commande **ssh-copy-id test@ip_distante** pour transférer la clé publique vers le serveur distant et pouvoir vous connecter de manière automatique.

### Scripts personnalisés
Vous pouvez ajouter des scripts personnalisés qui seront exécutés au démarrage du conteneur. Placez vos scripts dans le répertoire **/opt/custom/scripts/** et assurez-vous qu'ils ont les permissions d'exécution appropriées.

### Configuration SSH
La configuration du serveur SSH est définie dans le fichier **sshd_config**. Vous pouvez personnaliser cette configuration en modifiant ce fichier. N'oubliez pas que certaines options sont spécifiques au bastion et ne doivent pas être modifiées sans une bonne raison.

### Fichiers
- **Dockerfile** : Le fichier Dockerfile pour construire l'image Monosphere Bastion.
- **sshd_config** : Le fichier de configuration du serveur SSH.
- **server_menu.sh** : Le script qui génère le menu de sélection du serveur pour les utilisateurs autorisés.
- **authorized_servers.txt** : Liste des serveurs autorisés et des serveurs correspondants.
- **monosphere_banner.txt** : Bannière affichée par Monosphere lors de la connexion SSH.
- **ssh-launcher.sh** : Script exécuté toutes les 5 minutes servant à redémarrer le service ssh en cas de plantage.
- **ssh-monitor.rules** : Règles de logging spécifiques pour le daemon SSHD utilisés par Auditd.
- **auditd.conf** : Configuration du daemon auditd servant à logger les interractions avec le bastion.
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
Ce projet est publié sous la licence GNU.
