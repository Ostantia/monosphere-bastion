# Monosphere Bastion
Le projet Monosphere Bastion est un bastion SSH simple et sécurisé basé sur Ubuntu 20.04. Il offre une interface de menu permettant aux utilisateurs autorisés de se connecter à différents serveurs.

## Installation
Pour installer Monosphere Bastion, clonez ce dépôt et construisez l'image Docker en utilisant le fichier Dockerfile fourni.

```bash
git clone https://github.com/your-repo/monosphere-bastion.git
cd monosphere-bastion
docker build -t monosphere-bastion .
```

## Utilisation
Pour lancer un conteneur Monosphere Bastion, exécutez la commande suivante :

```bash
docker run -d -p 22:22 --name monosphere-bastion monosphere-bastion
```

Vous pouvez également personnaliser les variables d'environnement lors de l'exécution du conteneur :

```bash
docker run -d -p 22:22 \
  -e PORT=2222 \
  -e BASTIONUSER=myuser \
  -e BASTIONPASS=mypassword \
  -e HOSTNAME=my-bastion \
  --name monosphere-bastion monosphere-bastion
  ```
  
## Personnalisation

### Utilisateurs autorisés et serveurs

Pour définir les utilisateurs autorisés et les serveurs auxquels ils peuvent se connecter, modifiez le fichier authorized_servers.txt dans le répertoire /opt/public/servers/. Chaque ligne doit contenir l'adresse IP du serveur, le nom personnalisé et le nom d'utilisateur, séparés par des espaces :

 ```bash
192.168.1.10 server1 user1
192.168.1.11 server2 user2
```

### Scripts personnalisés
Vous pouvez ajouter des scripts personnalisés qui seront exécutés au démarrage du conteneur. Placez vos scripts dans le répertoire **/opt/custom/scripts/** et assurez-vous qu'ils ont les permissions d'exécution appropriées.

### Configuration SSH
La configuration du serveur SSH est définie dans le fichier **sshd_config**. Vous pouvez personnaliser cette configuration en modifiant ce fichier. N'oubliez pas que certaines options sont spécifiques au bastion et ne doivent pas être modifiées sans une bonne raison.

### Fichiers
- **Dockerfile** : Le fichier Dockerfile pour construire l'image Monosphere Bastion.
- **sshd_config** : Le fichier de configuration du serveur SSH.
- **server_menu.sh** : Le script qui génère le menu de sélection du serveur pour les utilisateurs autorisés.
- **entrypoint.sh** : Le script d'entrée qui configure et démarre les services nécessaires.

## License
Ce projet est publié sous la licence MIT.
