#!/bin/bash

error_msg() {
	# shellcheck disable=SC2154
	echo -n "$(date '+%d-%m-%Y||%H:%M:%S') [ NOOK ] "
	echo -e "$@"
}

good_msg() {
	echo -n "$(date '+%d-%m-%Y||%H:%M:%S') [ GOOD ] "
	echo -e "$@"
}

info_msg() {
	echo -n "$(date '+%d-%m-%Y||%H:%M:%S') [ INFO ] "
	echo -e "$@"
}

if ! grep -qo "^Port ${PORT}$" /etc/ssh/sshd_config; then
	info_msg "Génération de la configuration de SSH pour le bastion Monosphere..."
	info_msg "Port selectionne pour la connexion SSH : ${PORT}"
	echo "Port ${PORT}" >>/etc/ssh/sshd_config
	echo "#Last authentication configurations" >>/etc/ssh/sshd_config
	if [[ ${PASSWORD_AUTH} -eq "1" ]]; then
		info_msg "Authentification par mot de passe autorisee."
		echo "PasswordAuthentication yes" >>/etc/ssh/sshd_config
	else
		info_msg "Authentification par mot de passe interdite."
		echo "PasswordAuthentication no" >>/etc/ssh/sshd_config
	fi
	if [[ ${KEY_AUTH} -eq "1" ]]; then
		info_msg "Authentification par clés privées autorisee."
		echo "PubkeyAuthentication yes" >>/etc/ssh/sshd_config
	else
		info_msg "Authentification par clés privées interdite."
		echo "PubkeyAuthentication no" >>/etc/ssh/sshd_config
	fi
fi

info_msg "Monosphere active et execute les scripts personalisés"
chown -R root:root /opt/custom
chmod 700 /opt/custom/scripts/*.sh
bash /opt/custom/scripts/*.sh || error_msg "Code 02 : Problème lors de la tentative d'execution de scripts personnalisés.\nConsultez la documentation pour plus d'informations."
good_msg "Execution des scripts personalisés terminée."

#User accounts creation step

info_msg "Création des groupes d'utilisateurs."
if ! grep -q "bastionuser" /etc/group; then
	addgroup bastionuser
fi

if ! grep -q "bastionadmin" /etc/group; then
	addgroup bastionadmin
fi
good_msg "Fin de la création des groupes d'utilisateurs."

info_msg "Création des utilisateurs en cours..."
userfile=$(cat /root/scripts/users/bastion_users.txt)
if [[ -z ${userfile} ]]; then
	error_msg "Code 03 : Configuration utilisateur introuvable, veuillez vérifier votre configuration.\nConsultez la documentation pour plus d'informations."
	exit 1
fi
for userinfo in ${userfile}; do
	user=$(echo "${userinfo}" | cut -d ';' -f 1)
	is_bastion=$(echo "${userinfo}" | cut -d ';' -f 2)
	encrypted_password=$(echo "${userinfo}" | cut -d ';' -f 3)
	setkeys=$(echo "${userinfo}" | cut -d ';' -f 4)

	# shellcheck disable=SC2016
	if [[ $(echo "${encrypted_password}" | cut -c1-3) != '$6$' ]] && [[ $(echo "${encrypted_password}" | cut -c1-1) != '0' ]]; then
		error_msg "Code 01 : Problème avec le mot de passe entré pour l'utilisateur \"${user}\".\nConsultez la documentation pour plus d'informations."
		exit 1
	fi

	adduser --disabled-password --gecos "" "${user}" --shell /bin/bash

	if [[ ${is_bastion} -eq "1" ]]; then
		usermod -aG bastionuser "${user}"
	elif [[ ${is_bastion} -eq "0" ]]; then
		usermod -aG bastionadmin "${user}"
		mkdir /home/"${user}"
		ln -s /opt/public/scripts/server_menu.sh /home/"${user}"/server_menu.sh
	fi

	if [[ ${encrypted_password} != "0" ]]; then
		info_msg "Hash de mot de passe trouvé, configuration de ce dernier pour l'utilisateur \"${user}\"."
		sed -i "s|^${user}:\!|${user}:${encrypted_password}|g" /etc/shadow || error_msg "Code 04 : Problème avec la mise en place du mot de passe utilisateur.\nConsultez la documentation pour plus d'informations."
	else
		info_msg "Mot de passe non configuré, ce dernier sera égal au nom de l'utilisateur, comme indiqué dans la documentation."
		echo "${user}:${user}" | chpasswd
	fi

	if [[ ${setkeys} -eq "1" ]]; then
		mkdir -p /home/"${user}"/.ssh
		chmod 700 /home/"${user}"/.ssh
		cp -r /root/scripts/users/"${user}"/* /home/"${user}"/.ssh/
		chown -R "${user}":"${user}" /home/"${user}"/.ssh
		chmod 600 /home/"${user}"/.ssh/*
	fi
done
good_msg "Création des utilisateurs terminée."

info_msg "Monosphere configure le répertoire public."
chown -R root:bastionadmin /opt/public
chmod -R 775 /opt/public
good_msg "Répertoire public configuré."

info_msg "Démarrage du service SSHD de Monosphere."
rc-status
rc-service sshd restart

if sshd -t; then
	info_msg "Configuration du service SSHD de Monosphere vérifiée et valide."
	info_msg "Monosphere a bien été configuré et démarré avec succès."
else
	info_msg "Configuration du service SSHD de Monosphere invalide\n Veuillez vérifier la configuration et relancer le deploiement."
	exit 1
fi

# Keep the container running
tail -f /dev/null
