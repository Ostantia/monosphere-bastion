#!/bin/bash

AUTHORIZED_SERVERS_PATH="opt/public/servers"
AUTHORIZED_SERVERS_FILE="/${AUTHORIZED_SERVERS_PATH}/authorized_servers.txt"
CONNECTED_USER="$(whoami)"

USER_SERVERS=$(awk -v user="${CONNECTED_USER}" '
{
  split($5, users, ",");
  for (i in users) {
    if (users[i] == user) {
      print $0;
    }
  }
}' "${AUTHORIZED_SERVERS_FILE}")

if [[ -z ${USER_SERVERS} ]]; then
	echo "Vous n'avez pas l'autorisation de vous connecter à un serveur."
	exit 1
fi

function main_menu() {
	if [[ -z $choice ]] || [[ ${choice} == "null" ]]; then
		clear
		echo "Veuillez sélectionner un serveur auquel vous connecter :"
	fi

	counter=0
	declare -A server_map
	while read -r line; do
		ip=$(echo "${line}" | cut -d ' ' -f 1)
		port=$(echo "${line}" | cut -d ' ' -f 2)
		custom_name=$(echo "${line}" | cut -d ' ' -f 3)
		server_user=$(echo "${line}" | cut -d ' ' -f 4)
		server_authmethod=$(echo "${line}" | cut -d ' ' -f 6)
		server_auth=$(echo "${line}" | cut -d ' ' -f 7)
		server_map[${counter}]="${ip} ${port} ${server_user} ${server_authmethod} ${server_auth} ${custom_name}"
		if [[ -z $choice ]] || [[ ${choice} == "null" ]]; then
			echo "${counter}) ${custom_name} - ${server_user} ${ip}:${port}"
		fi
		counter=$((counter + 1))
	done <<<"${USER_SERVERS}"

	if [[ -z $choice ]] || [[ ${choice} == "null" ]]; then
		echo "${counter}) Tapez 'quit' ou ${counter} pour vous déconnecter."
		echo "f) Tapez 'f'<nom de l'hote> pour filtrer les entrées."

		read -r -p "Votre choix (0-${counter}) : " choice
	fi

	if [[ ${choice} == "quit" ]] || [[ ${choice} == "${counter}" ]]; then
		echo "Déconnexion du bastion."
		exit 0
	elif [[ $(echo "${choice}" | cut -c1-1) == "f" ]]; then
		filter=$(echo "${choice}" | cut -c2-)
		find_counter=0
		echo "=====Résultats du filtre====="
		for host in "${server_map[@]}"; do
			if [[ $(echo "${host}" | awk '{print $(NF)}' | grep -m 1 -o "${filter}" | head -1) == "${filter}" ]]; then
				echo "${find_counter}) $(echo ${server_map[${find_counter}]} | awk '{print $(NF)}') - $(echo ${server_map[${find_counter}]} | cut -d ' ' -f 3) $(echo ${server_map[${find_counter}]} | cut -d ' ' -f 1):$(echo ${server_map[${find_counter}]} | cut -d ' ' -f 2)"
			fi
			find_counter=$((find_counter + 1))
		done
		read -r -p "Votre choix (0-${counter}) : " choice
	elif [[ -z ${choice} ]] || [[ -z ${server_map[${choice}]} ]]; then
		echo "Sélection invalide."
		choice="null"
	else
		clear
		local selected_server
		selected_server="${server_map[${choice}]}"
		echo "Connexion à $(echo "${selected_server}" | cut -d " " -f -3)..."
		if [[ -z "$(echo "${selected_server}" | cut -d ' ' -f 4)" ]]; then
			ttyrec -z --"$(echo "${selected_server}" | cut -d ' ' -f 1)"-"$(echo "${selected_server}" | cut -d ' ' -f 3)"-- -k 300 --warn-before-kill 60 -- ssh -o StrictHostKeyChecking=accept-new -p "$(echo "${selected_server}" | cut -d ' ' -f 2)" "$(echo "${selected_server}" | cut -d ' ' -f 3)"@"$(echo "${selected_server}" | cut -d ' ' -f 1)"
		elif [[ "$(echo "${selected_server}" | cut -d ' ' -f 4)" == "key" ]] && [[ -f /"${AUTHORIZED_SERVERS_PATH}"/"$(echo "${selected_server}" | cut -d ' ' -f 5)" ]]; then
			eval "$(ssh-agent)" >/dev/null
			trap 'kill $SSH_AGENT_PID' EXIT
			cat /"${AUTHORIZED_SERVERS_PATH}"/"$(echo "${selected_server}" | cut -d ' ' -f 5)" | ssh-add - >/dev/null
			ttyrec -z --"$(echo "${selected_server}" | cut -d ' ' -f 1)"-"$(echo "${selected_server}" | cut -d ' ' -f 3)"-- -k 300 --warn-before-kill 60 -- ssh -o StrictHostKeyChecking=accept-new -p "$(echo "${selected_server}" | cut -d ' ' -f 2)" "$(echo "${selected_server}" | cut -d ' ' -f 3)"@"$(echo "${selected_server}" | cut -d ' ' -f 1)"
			ssh-add -D >/dev/null
		elif [[ "$(echo "${selected_server}" | cut -d ' ' -f 4)" == "password" ]] && [[ -f /"${AUTHORIZED_SERVERS_PATH}"/"$(echo "${selected_server}" | cut -d ' ' -f 5)" ]]; then
			local ssh_password
			ssh_password=$(cat /"${AUTHORIZED_SERVERS_PATH}"/"$(echo "${selected_server}" | cut -d ' ' -f 5)")
			ttyrec -z --"$(echo "${selected_server}" | cut -d ' ' -f 1)"-"$(echo "${selected_server}" | cut -d ' ' -f 3)"-- -k 300 --warn-before-kill 60 -- sshpass -p "${ssh_password}" ssh -o StrictHostKeyChecking=accept-new -p "$(echo "${selected_server}" | cut -d ' ' -f 2)" "$(echo "${selected_server}" | cut -d ' ' -f 3)"@"$(echo "${selected_server}" | cut -d ' ' -f 1)"
			unset ssh_password
		else
			echo -e "Un problème de configuration a été détecté sur \nles options de connexion à l'hôte selectionné.\nVeuillez contacter votre administrateur."
		fi
		choice="null"
	fi
}

while true; do
	main_menu
done
