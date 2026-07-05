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

TRANSFER_LOG="/var/log/monosphere/transfers.log"
TRANSFER_RIGHTS_FILE="/opt/public/rights/transfer_rights.txt"

mkdir -p "$(dirname "${TRANSFER_LOG}")" 2>/dev/null
touch "${TRANSFER_LOG}" 2>/dev/null
chmod 666 "${TRANSFER_LOG}" 2>/dev/null

check_transfer_rights() {
    local server_name="$1"
    if [[ ! -f ${TRANSFER_RIGHTS_FILE} ]] || [[ ! -s ${TRANSFER_RIGHTS_FILE} ]]; then
        return 0
    fi
    local user_allowed
    user_allowed=$(awk -v server="${server_name}" -v user="${CONNECTED_USER}" '
        $1 == server {
            split($2, ulist, ",");
            for (i in ulist) {
                if (ulist[i] == user || ulist[i] == "*") { print "yes"; exit; }
            }
        }
    ' "${TRANSFER_RIGHTS_FILE}")
    if [[ -z ${user_allowed} ]]; then
        return 1
    fi
    return 0
}

scp_to_target() {
    local src="$1" ip="$2" port="$3" user="$4" dest="$5" authmethod="$6" authfile="$7"
    if [[ -z ${authmethod} ]]; then
        scp -o StrictHostKeyChecking=accept-new -P "${port}" "${src}" "${user}@${ip}:${dest}" 2>&1
    elif [[ ${authmethod} == "key" ]] && [[ -f /${AUTHORIZED_SERVERS_PATH}/${authfile} ]]; then
        scp -o StrictHostKeyChecking=accept-new -i "/${AUTHORIZED_SERVERS_PATH}/${authfile}" -P "${port}" "${src}" "${user}@${ip}:${dest}" 2>&1
    elif [[ ${authmethod} == "password" ]] && [[ -f /${AUTHORIZED_SERVERS_PATH}/${authfile} ]]; then
        sshpass -p "$(cat /${AUTHORIZED_SERVERS_PATH}/${authfile})" scp -o StrictHostKeyChecking=accept-new -P "${port}" "${src}" "${user}@${ip}:${dest}" 2>&1
    else
        return 1
    fi
}

ssh_to_target_cat() {
    local ip="$1" port="$2" user="$3" path="$4" authmethod="$5" authfile="$6"
    if [[ -z ${authmethod} ]]; then
        ssh -T -o StrictHostKeyChecking=accept-new -p "${port}" "${user}@${ip}" "cat '${path}'" < /dev/null
    elif [[ ${authmethod} == "key" ]] && [[ -f /${AUTHORIZED_SERVERS_PATH}/${authfile} ]]; then
        ssh -T -o StrictHostKeyChecking=accept-new -i "/${AUTHORIZED_SERVERS_PATH}/${authfile}" -p "${port}" "${user}@${ip}" "cat '${path}'" < /dev/null
    elif [[ ${authmethod} == "password" ]] && [[ -f /${AUTHORIZED_SERVERS_PATH}/${authfile} ]]; then
        sshpass -p "$(cat /${AUTHORIZED_SERVERS_PATH}/${authfile})" ssh -T -o StrictHostKeyChecking=accept-new -p "${port}" "${user}@${ip}" "cat '${path}'" < /dev/null
    else
        return 1
    fi
}

log_transfer() {
    local action="$1" server="$2" path="$3" size="$4" status="$5"
    echo "$(date '+%Y-%m-%d %H:%M:%S') USER=${CONNECTED_USER} ACTION=${action} SERVER=${server} FILE=${path} SIZE=${size} STATUS=${status}" >> "${TRANSFER_LOG}"
}

if [[ -n ${SSH_ORIGINAL_COMMAND} ]]; then
    case "${SSH_ORIGINAL_COMMAND}" in
        "push_file "*)
            args="${SSH_ORIGINAL_COMMAND#push_file }"
            server_name=$(echo "${args}" | cut -d ' ' -f 1)
            dest_path=$(echo "${args}" | cut -d ' ' -f 2-)
            if [[ -z ${server_name} ]] || [[ -z ${dest_path} ]]; then
                echo "Usage: push_file <server_name> <remote_dest_path>"
                exit 1
            fi
            server_line=$(echo "${USER_SERVERS}" | awk -v name="${server_name}" '$3 == name {print; exit}')
            if [[ -z ${server_line} ]]; then
                echo "Serveur \"${server_name}\" non trouve ou non autorise."
                exit 1
            fi
            if ! check_transfer_rights "${server_name}"; then
                echo "Vous n'avez pas le droit de transferer des fichiers vers ${server_name}."
                exit 1
            fi
            srv_ip=$(echo "${server_line}" | cut -d ' ' -f 1)
            srv_port=$(echo "${server_line}" | cut -d ' ' -f 2)
            srv_user=$(echo "${server_line}" | cut -d ' ' -f 4)
            srv_authmethod=$(echo "${server_line}" | cut -d ' ' -f 6)
            srv_authfile=$(echo "${server_line}" | cut -d ' ' -f 7)
            tmpfile=$(mktemp /tmp/.push_XXXXXX)
            cat > "${tmpfile}"
            file_size=$(stat -c %s "${tmpfile}" 2>/dev/null || stat -f %z "${tmpfile}" 2>/dev/null)
            scp_to_target "${tmpfile}" "${srv_ip}" "${srv_port}" "${srv_user}" "${dest_path}" "${srv_authmethod}" "${srv_authfile}"
            exit_code=$?
            rm -f "${tmpfile}"
            if [[ ${exit_code} -eq 0 ]]; then
                log_transfer "push" "${server_name}" "${dest_path}" "${file_size:-0}" "success"
            else
                log_transfer "push" "${server_name}" "${dest_path}" "${file_size:-0}" "failed"
            fi
            exit ${exit_code}
            ;;
        "retrieve_file "*)
            args="${SSH_ORIGINAL_COMMAND#retrieve_file }"
            server_name=$(echo "${args}" | cut -d ' ' -f 1)
            remote_path=$(echo "${args}" | cut -d ' ' -f 2-)
            if [[ -z ${server_name} ]] || [[ -z ${remote_path} ]]; then
                echo "Usage: retrieve_file <server_name> <remote_path>"
                exit 1
            fi
            server_line=$(echo "${USER_SERVERS}" | awk -v name="${server_name}" '$3 == name {print; exit}')
            if [[ -z ${server_line} ]]; then
                echo "Serveur \"${server_name}\" non trouve ou non autorise."
                exit 1
            fi
            if ! check_transfer_rights "${server_name}"; then
                echo "Vous n'avez pas le droit de transferer des fichiers vers ${server_name}."
                exit 1
            fi
            srv_ip=$(echo "${server_line}" | cut -d ' ' -f 1)
            srv_port=$(echo "${server_line}" | cut -d ' ' -f 2)
            srv_user=$(echo "${server_line}" | cut -d ' ' -f 4)
            srv_authmethod=$(echo "${server_line}" | cut -d ' ' -f 6)
            srv_authfile=$(echo "${server_line}" | cut -d ' ' -f 7)
            ssh_to_target_cat "${srv_ip}" "${srv_port}" "${srv_user}" "${remote_path}" "${srv_authmethod}" "${srv_authfile}"
            exit_code=$?
            if [[ ${exit_code} -eq 0 ]]; then
                echo "$(date '+%Y-%m-%d %H:%M:%S') USER=${CONNECTED_USER} ACTION=retrieve SERVER=${server_name} FILE=${remote_path} STATUS=success" >> "${TRANSFER_LOG}"
            else
                echo "$(date '+%Y-%m-%d %H:%M:%S') USER=${CONNECTED_USER} ACTION=retrieve SERVER=${server_name} FILE=${remote_path} STATUS=failed" >> "${TRANSFER_LOG}"
            fi
            exit ${exit_code}
            ;;
        *)
            echo "Commande non reconnue: ${SSH_ORIGINAL_COMMAND}"
            echo "Commandes supportees:"
            echo "  push_file <server> <dest_path>    - Pousser stdin vers un serveur distant"
            echo "  retrieve_file <server> <src_path> - Recuperer un fichier distant vers stdout"
            exit 1
            ;;
    esac
fi

function main_menu() {
	if [[ -z $choice ]] || [[ ${choice} == "null" ]]; then
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
		for host in $(printf '%s\n' "${server_map[@]}" | tac | cut -d " " -f 6); do
			if [[ $(echo "${host}" | awk '{print $(NF)}' | grep -m 1 -o "${filter}" | head -1) == $(echo "${filter}") ]]; then
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
	clear
done
