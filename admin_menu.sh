#!/bin/bash

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
		echo -e "Option non implémentée pour le moment.\nElle sera ajoutée lors d'une prochaine mise à jour."
		;;

	"2")
		echo -e "Veuillez bien vérifier la syntaxe de votre configuration avant de valider cette dernière.\nPour plus d'informations, consultez la documentation de Monosphere."
		sudo nano /opt/public/servers/authorized_servers.txt
		;;

	"3" | "quit")
		main_menu
		;;

	*)
		echo "Sélection invalide."
		;;
	esac

	while true; do
		servers_access_control
	done
}

function main_menu() {
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
		echo "Sélection invalide."
	else
		local selected_option
		selected_option="${adminrights_map[${choice}]}"
		case "$(echo "${selected_option}" | cut -d ' ' -f 1)" in

		"sessionswatch_admins")
			sessions_viewer
			;;

		"serverscontrol_admins")
			servers_access_control
			;;
			#
			#			"usercontrol_admins")
			#
			#			;;
			#
			#			"adminscontrol_admins")
			#
			#			;;
			#
			#			"cluster_admins")
			#
			#			;;

		*)
			echo -e "Un problème de configuration a été détecté sur \nles options du droit administrateur sélectionné.\nVeuillez contacter votre administrateur."
			;;
		esac
	fi

	while true; do
		main_menu
	done
}

main_menu
