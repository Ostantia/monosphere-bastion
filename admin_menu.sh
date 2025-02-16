#!/bin/bash

function secure_file_editor() {
	File_Path="${*}"
	echo -e "\n=====SECURE=FILE=EDITOR====="
	if [[ -e ${File_Path} ]]; then
		echo "Le fichier selectionne existe et a pour contenu :"
		cat "${File_Path}"
		read -r -p 'Souhaitez vous modifier le contenu du fichier ? (y/n) : ' choice
	else
		echo "Creation d un nouveau fichier \"${File_Path}\"."
		touch "${File_Path}"
		choice="y"
	fi
	case ${choice} in

	"y" | "Y")
		printf '%s\n' " Consignes d'utilisation de cet editeur : - Lorsque l'edition du fichier est achevee, entrez ctrl-d sur une ligne vide pour sortir. - ATTENTION : Copiez les lignes que vous souhaitez garder intactes, le contenu du fichier complet sera ecrase par ce qui suit. - Tout fichier vide sera supprime. :"
		New_Content+=$(xargs -0)
		echo "${New_Content}" >"${File_Path}"
		;;

	"n" | "N")
		echo "Edition du fichier abandonnee."
		;;

	*)
		clear
		echo "Selection invalide."
		;;
	esac

	unset New_Content
	unset File_Path
	echo "Modifications appliquées."
	echo -e "=====SECURE=FILE=EDITOR=====\n"
}

function sessions_viewer() {
	echo -e "Ci dessous les utilisateurs disponibles sur le bastion.\nVeillez sélectionner celui dont vous souhaitez visionner les accès :"
	Available_Users=$(find /home/. -maxdepth 1 -type d | grep -v "\.$" | cut -d "/" -f 4)
	users_counter=1
	declare -A users_map
	while read -r line; do
		user="${line}"
		users_map[${users_counter}]="${user}"
		echo "${users_counter}) ${user}"
		users_counter=$((users_counter + 1))
	done <<<"${Available_Users}"

	echo "${users_counter}) Tapez 'quit' ou ${users_counter} pour revenir au menu précédent."

	read -r -p "Votre choix (1-${users_counter}): " choice

	if [[ ${choice} == "quit" ]] || [[ ${choice} == "${users_counter}" ]]; then
		main_menu
	elif [[ -z ${choice} ]] || [[ -z ${users_map[${choice}]} ]]; then
		clear
		echo "Sélection invalide."
	else
		local selected_option
		selected_option="${users_map[${choice}]}"
		while true; do
			Available_Sessions=$(find /home/"${selected_option}"/. -maxdepth 1 -type f -name "*.ttyrec" | grep -v "\.$" | cut -d "/" -f 5)
			echo "Sélectionnez une session de cet utilisateur que vous souhaitez visionner :"

			sessions_counter=1
			declare -A sessions_map
			while read -r line; do
				session_name="${line}"
				sessions_map[${sessions_counter}]="${session_name}"
				echo "${sessions_counter}) ${session_name}"
				sessions_counter=$((sessions_counter + 1))
			done <<<"${Available_Sessions}"
			
			echo "${sessions_counter}) Tapez 'quit' ou ${sessions_counter} pour vous revenir au choix d'utilisateur."

			read -r -p "Votre choix (1-${sessions_counter}): " choice
			if [[ ${choice} == "quit" ]] || [[ ${choice} == "${sessions_counter}" ]]; then
				sessions_viewer
			elif [[ -z ${choice} ]] || [[ -z ${sessions_map[${choice}]} ]]; then
				clear
				echo "Sélection invalide."
			else
				local selected_session
				selected_session="${sessions_map[${choice}]}"
				ttyplay /home/"${selected_option}"/"${selected_session}"
			fi
		done
	fi

	while true; do
		sessions_viewer
	done

}

function servers_access_control() {
	echo -e "Choisissez une option d'administration des serveurs ci dessous :"
	echo -e "1) Ajout de fichiers clés privées/mots de passes pour l'authentification aux serveurs distants.\n2) Modification des droits d'accès aux serveurs.\n3) Tapez 'quit' ou 3 pour revenir au menu précédent."

	read -r -p "Votre choix (1-3): " choice

	case "${choice}" in
	"1")
		clear
		Authorization_Files_List=$(find /opt/public/servers/. -type f ! -name 'authorized_servers.txt' | cut -d "/" -f 6)
		echo -e "Le ficher d'authentification qui sera crée ou modifié sera placé dans le répertoire \"/opt/public/servers/\" du bastion.\nle nom de ce dernier ne doit pas comporter de \"/\", être vide ou être égal à \"authorized_servers.txt\"."
		echo -e "Ci dessous la liste des fichiers d'authentification existants :\n${Authorization_Files_List}"
		read -r -p 'Entrez le nom du fichier: ' File_Name

		if [[ $(echo "${File_Name}" | grep -m1 -o "/" | head -1) == "/" ]] || [[ $(echo "${File_Name}" | grep -m1 -o "*" | head -1) == "*" ]] || [[ -z ${File_Name} ]] || [[ ${File_Name} == "authorized_servers.txt" ]]; then
			echo 'Le nom du fichier ne doit pas contenir les caractères "/" ou "*", être vide ou ce nommer "authorized_servers.txt". Veuillez modifier ce dernier.'
		else
			echo "Assurez vous que le fichier créé ou modifié comporte bien uniquement la clé privée ou le mot de passe nécessaire à la connexion."
			secure_file_editor "/opt/public/servers/${File_Name}"
			if [[ $(cat "/opt/public/servers/${File_Name}") == "" ]]; then
				echo "Le fichier modifié \"${File_Name}\" est vide. Ce dernier sera supprimé."
				rm -rf /opt/public/servers/"${File_Name}"
			fi
		fi
		;;

	"2")
		clear
		echo -e "Veuillez bien vérifier la syntaxe de votre configuration avant de valider cette dernière.\nPour plus d'informations, consultez la documentation de Monosphere."
		secure_file_editor "/opt/public/servers/authorized_servers.txt"
		;;

	"3" | "quit")
		main_menu
		;;

	*)
		clear
		echo "Sélection invalide."
		;;
	esac

	while true; do
		servers_access_control
	done
}

function admin_rights_control() {
	echo -e "Veuillez bien vérifier la syntaxe de votre configuration avant de valider cette dernière.\nPour plus d'informations, consultez la documentation de Monosphere."
	secure_file_editor "/opt/public/rights/admin_rights.txt"
}

function main_menu() {
	clear
	ADMIN_RIGHTS_PATH="opt/public/rights"
	ADMIN_RIGHTS_FILE="/${ADMIN_RIGHTS_PATH}/admin_rights.txt"
	CONNECTED_ADMIN="$(whoami)"

	ADMIN_RIGHTS=$(awk -v user="${CONNECTED_ADMIN}" '
{
  split($3, users, ",");
  for (i in users) {
    if (users[i] == user) {
      print $0;
    }
  }
}' "${ADMIN_RIGHTS_FILE}")

	if [[ -z ${ADMIN_RIGHTS} ]]; then
		echo -e "Vous n'avez aucune autorisation d'administration.\nVous pouvez cependant vous connecter aux serveurs dont l'accès vous est autorisé."
	fi

	echo "Veuillez sélectionner une option d'administration :"

	counter=1
	declare -A adminrights_map
	while read -r line; do
		admin_right=$(echo "${line}" | cut -d ' ' -f 1)
		admin_right_pretty_name=$(echo "${line}" | cut -d ' ' -f 2)
		adminrights_map[${counter}]="${admin_right} ${admin_right_pretty_name}"
		echo "${counter}) ${admin_right_pretty_name}"
		counter=$((counter + 1))
	done <<<"${ADMIN_RIGHTS}"

	echo "${counter}) Tapez 'servers_access' ou ${counter} pour vous connecter a un serveur."
	counter=$((counter + 1))
	echo "${counter}) Tapez 'quit' ou ${counter} pour vous déconnecter."

	read -r -p "Votre choix (1-${counter}): " choice

	if [[ ${choice} == "servers_access" ]] || [[ ${choice} == "$((counter - 1))" ]]; then
		bash /opt/public/scripts/server_menu.sh
	elif [[ ${choice} == "quit" ]] || [[ ${choice} == "${counter}" ]]; then
		echo "Déconnexion du bastion."
		exit 0
	elif [[ -z ${choice} ]] || [[ -z ${adminrights_map[${choice}]} ]]; then
		clear
		echo "Sélection invalide."
	else
		local selected_option
		selected_option="${adminrights_map[${choice}]}"
		case "$(echo "${selected_option}" | cut -d ' ' -f 1)" in

		"sessionswatch_admins")
			clear
			sessions_viewer
			;;

		"serverscontrol_admins")
			clear
			servers_access_control
			;;
			#
			#			"usercontrol_admins")
			#
			#			;;
			#
		"adminscontrol_admins")
			clear
			admin_rights_control
			;;

			#
			#			"cluster_admins")
			#
			#			;;

		*)
			clear
			echo -e "Un problème de configuration a été détecté sur \nles options du droit administrateur sélectionné.\nVeuillez contacter votre administrateur."
			;;
		esac
	fi

	while true; do
		main_menu
	done
}

main_menu
