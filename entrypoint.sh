#!/bin/bash

if ! grep -qo "^Port ${PORT}$" /etc/ssh/sshd_config; then
    echo "Génération de la configuration de SSH pour le bastion Monosphere..."
    echo "Port ${PORT}" >> /etc/ssh/sshd_config
    echo "#Last authentication configurations" >> /etc/ssh/sshd_config
    if [ "${PASSWORD_AUTH}" -eq "1" ]; then
        echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
    else
        echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
    fi
    if [ "${KEY_AUTH}" -eq "1" ]; then
        echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config
    else
        echo "PubkeyAuthentication no" >> /etc/ssh/sshd_config
    fi
fi
sshd -t
echo "Configuration du service SSHD de Monosphere vérifiée."

echo "Monosphere active et execute les scripts personalisés"
chown -R root:root /opt/custom
chmod 700 /opt/custom/scripts/*.sh
bash /opt/custom/scripts/*.sh
echo "Execution des scripts personalisés terminée."

echo "Monosphere configure le répertoire public."
chown -R root:root /opt/public
chmod -R 755 /opt/public
echo "Répertoire public configuré."

#User accounts creation step

echo "Création des groupes d'utilisateurs."
if ! grep -q "bastionuser" /etc/group; then
    addgroup bastionuser
fi

if ! grep -q "bastionadmin" /etc/group; then
    addgroup bastionadmin
fi
echo "Fin de la création des groupes d'utilisateurs."

echo "Création des utilisateurs en cours..."
userfile=$(cat /root/scripts/users/bastion_users.txt)
for userinfo in $userfile; do
    user=$(echo "$userinfo" | cut -d ';' -f 1)
    is_bastion=$(echo "$userinfo" | cut -d ';' -f 2)
    password=$(echo "$userinfo" | cut -d ';' -f 3)
    setkeys=$(echo "$userinfo" | cut -d ';' -f 4)

    adduser --disabled-password --gecos "" "$user" --shell /bin/bash

    if [ "$is_bastion" -eq "1" ]; then
        usermod -aG bastionuser "$user"
    elif [ "$is_bastion" -eq "0" ]; then
        usermod -aG bastionadmin "$user"
        if ! grep -qo "^$user ALL=(ALL) NOPASSWD:" /etc/sudoers; then
            echo "$user ALL=(ALL) NOPASSWD: /usr/local/bin/ttyplay*" | sudo EDITOR='tee -a' visudo
            echo "$user ALL=(ALL) NOPASSWD: /bin/ls*" | sudo EDITOR='tee -a' visudo
        fi
        mkdir /home/"$user"
        ln -s /opt/public/scripts/server_menu.sh /home/"$user"/server_menu.sh
    fi

    if [ "$password" != "0" ]; then
        echo "$user:$password" | chpasswd
    else
        echo "$user:$user" | chpasswd
    fi

    if [ "$setkeys" -eq "1" ]; then
        mkdir -p /home/"$user"/.ssh
        chmod 700 /home/"$user"/.ssh
        cp -r /root/scripts/users/"$user"/* /home/"$user"/.ssh/
        chown -R "$user":"$user" /home/"$user"/.ssh
        chmod 600 /home/"$user"/.ssh/*
    fi
done
echo "Création des utilisateurs terminée."
echo "Monosphere a bien été configuré et démarré avec succès."

echo "Démarrage du service SSHD de Monosphere."
rc-status
rc-service sshd restart

echo "Le bastion Monosphere est désormais en marche."

# Keep the container running
tail -f /dev/null
