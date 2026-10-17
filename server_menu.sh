#!/bin/bash
#
# server_menu.sh - Menu de connexion aux serveurs distants du bastion Monosphere.
# Exécuté en ForceCommand pour le groupe "bastionuser", et délégué par le menu
# d'administration. Gère aussi les commandes non-interactives push_file /
# retrieve_file (transit en streaming, sans stockage temporaire sur le bastion).

AUTHORIZED_SERVERS_DIR="/opt/public/servers"
AUTHORIZED_SERVERS_FILE="${AUTHORIZED_SERVERS_DIR}/authorized_servers.txt"
TRANSFER_RIGHTS_FILE="/opt/public/rights/transfer_rights.txt"
TRANSFER_LOG="/var/log/monosphere/transfers.log"
CONNECTIONS_LOG="/var/log/monosphere/connections.log"
EVENTS_LOG="/var/log/monosphere/events.log"
SESSIONS_BASE_DIR="/var/log/monosphere/sessions"
CONNECTED_USER="$(whoami)"

# Umask stricte : les fichiers créés par les menus (copies temporaires de clés)
# ne sont accessibles qu'à leur propriétaire.
umask 077

# Options SSH communes : TOFU sur la première connexion vers un hôte distant,
# timeout de connexion pour ne pas suspendre la session si la cible ne répond pas.
SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)

# --- Utilitaires -----------------------------------------------------------

# Quote une chaine pour un shell POSIX distant (entre simples quotes).
sh_quote() {
    local s="${1}"
    s=${s//\'/\'\\\'\'}
    printf "'%s'" "${s}"
}

# Rejette les chemins vides ou contenant des retours a la ligne
# (un retour a la ligne permettrait de forger des entrees dans le journal).
valid_remote_path() {
    local path="${1}"
    if [[ -z ${path} ]] || [[ ${path} == *$'\n'* ]] || [[ ${path} == *$'\r'* ]]; then
        return 1
    fi
    return 0
}

log_transfer() {
    local action="$1" server="$2" path="$3" size="$4" status="$5"
    # Le journal est pré-créé par l'entrypoint ; une erreur d'écriture ne doit
    # jamais bloquer l'opération de l'utilisateur ni s'afficher sur son
    # terminal (l'erreur de redirection bash précède le 2>/dev/null, d'où le
    # groupe { ... } qui l'englobe).
    { echo "$(date '+%Y-%m-%d %H:%M:%S') USER=${CONNECTED_USER} ACTION=${action} SERVER=${server} FILE=${path} SIZE=${size} STATUS=${status}" >>"${TRANSFER_LOG}"; } 2>/dev/null || true
}

# Écrit un événement dans un fichier de journal ET dans events.log (le miroir
# relaie ces événements sur la sortie du conteneur par l'entrypoint, pour les
# collecteurs centralisés de type driver de logs Docker).
log_line() {
    local file="$1" line="$2"
    { echo "${line}" >>"${file}"; } 2>/dev/null || true
    if [[ ${file} != "${EVENTS_LOG}" ]]; then
        { echo "${line}" >>"${EVENTS_LOG}"; } 2>/dev/null || true
    fi
}

# Journalise une connexion interactive à une cible (début, fin ou erreur).
# SESSION_UUID permet de retrouver l'enregistrement ttyrec correspondant.
log_connection() {
    local action="$1" target="$2" ruser="$3" status="$4" uuid="$5"
    log_line "${CONNECTIONS_LOG}" "$(date '+%Y-%m-%d %H:%M:%S') USER=${CONNECTED_USER} ACTION=${action} TARGET=${target} REMOTE_USER=${ruser} SESSION_UUID=${uuid} STATUS=${status}"
}

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

check_transfer_rights() {
    local server_name="$1"
    if [[ ! -f ${TRANSFER_RIGHTS_FILE} ]] || [[ ! -s ${TRANSFER_RIGHTS_FILE} ]]; then
        # Fichier absent ou vide : tous les utilisateurs autorises peuvent transferer.
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
    [[ -n ${user_allowed} ]]
}

# Retrouve la ligne de configuration d'un serveur par son nom personnalisé.
find_server_line() {
    local name="$1"
    echo "${USER_SERVERS}" | awk -v name="${name}" '$3 == name {print; exit}'
}

# Prépare une copie temporaire d'une clé partagée, lisible uniquement par
# l'utilisateur courant. OpenSSH refuse toute clé privée avec des bits de
# groupe/autres ("Permissions too open"), ce qui est incompatible avec le
# partage de clés par ACL : on copie donc la clé en 0600 le temps de la
# connexion (l'utilisateur peut de toute façon lire la clé partagée, le
# niveau d'exposition est inchangé). Retourne le chemin via stdout.
prepare_key() {
    local shared_key="$1" tmp_key
    tmp_key=$(mktemp "${TMPDIR:-/tmp}/mono-key.XXXXXX") || return 1
    if ! cat "${shared_key}" >"${tmp_key}" 2>/dev/null; then
        rm -f "${tmp_key}"
        return 1
    fi
    chmod 600 "${tmp_key}"
    printf '%s' "${tmp_key}"
}

# Exécute une commande simple sur un hôte distant configuré.
# Arguments : cible user@ip, port, commande distante (déjà quotée), méthode d'auth, fichier de clé.
run_on_target() {
    local target="$1" port="$2" remote_cmd="$3" authmethod="$4" authfile="$5"
    local keyfile tmp_key
    if [[ ${authmethod} == "key" ]]; then
        keyfile="${AUTHORIZED_SERVERS_DIR}/${authfile}"
        if [[ -z ${authfile} ]] || [[ ! -f ${keyfile} ]]; then
            echo "Un problème de configuration a été détecté sur le fichier de clé \"${authfile}\". Veuillez contacter votre administrateur."
            return 125
        fi
        tmp_key=$(prepare_key "${keyfile}") || {
            echo "Impossible de préparer la clé de connexion. Veuillez contacter votre administrateur."
            return 125
        }
        ssh -T "${SSH_OPTS[@]}" -i "${tmp_key}" -o IdentitiesOnly=yes -p "${port}" "${target}" "${remote_cmd}"
        rm -f "${tmp_key}"
    else
        ssh -T "${SSH_OPTS[@]}" -p "${port}" "${target}" "${remote_cmd}"
    fi
}

# --- Commandes non-interactives (SSH_ORIGINAL_COMMAND) ----------------------

if [[ -n ${SSH_ORIGINAL_COMMAND} ]]; then
    case "${SSH_ORIGINAL_COMMAND}" in
    "push_file "*)
        args="${SSH_ORIGINAL_COMMAND#push_file }"
        if [[ ${args} != *" "* ]]; then
            echo "Usage: push_file <server_name> <remote_dest_path>"
            exit 1
        fi
        server_name="${args%% *}"
        dest_path="${args#* }"
        if ! valid_remote_path "${dest_path}"; then
            echo "Chemin de destination invalide."
            exit 1
        fi
        server_line=$(find_server_line "${server_name}")
        if [[ -z ${server_line} ]]; then
            echo "Serveur \"${server_name}\" non trouve ou non autorise."
            exit 1
        fi
        if ! check_transfer_rights "${server_name}"; then
            echo "Vous n'avez pas le droit de transferer des fichiers vers ${server_name}."
            exit 1
        fi
        read -r srv_ip srv_port _srv_name srv_user _srv_users srv_authmethod srv_authfile <<<"${server_line}"
        # Streaming direct : stdin (le fichier) est relaye vers "cat > <dest>"
        # sur la cible, sans stockage temporaire sur le bastion.
        run_on_target "${srv_user}@${srv_ip}" "${srv_port}" "cat > $(sh_quote "${dest_path}")" "${srv_authmethod}" "${srv_authfile}"
        exit_code=$?
        if [[ ${exit_code} -eq 0 ]]; then
            log_transfer "push" "${server_name}" "${dest_path}" "-" "success"
        else
            log_transfer "push" "${server_name}" "${dest_path}" "-" "failed"
        fi
        exit ${exit_code}
        ;;
    "retrieve_file "*)
        args="${SSH_ORIGINAL_COMMAND#retrieve_file }"
        if [[ ${args} != *" "* ]]; then
            echo "Usage: retrieve_file <server_name> <remote_path>"
            exit 1
        fi
        server_name="${args%% *}"
        remote_path="${args#* }"
        if ! valid_remote_path "${remote_path}"; then
            echo "Chemin distant invalide."
            exit 1
        fi
        server_line=$(find_server_line "${server_name}")
        if [[ -z ${server_line} ]]; then
            echo "Serveur \"${server_name}\" non trouve ou non autorise."
            exit 1
        fi
        if ! check_transfer_rights "${server_name}"; then
            echo "Vous n'avez pas le droit de transferer des fichiers depuis ${server_name}."
            exit 1
        fi
        read -r srv_ip srv_port _srv_name srv_user _srv_users srv_authmethod srv_authfile <<<"${server_line}"
        run_on_target "${srv_user}@${srv_ip}" "${srv_port}" "cat $(sh_quote "${remote_path}")" "${srv_authmethod}" "${srv_authfile}"
        exit_code=$?
        if [[ ${exit_code} -eq 0 ]]; then
            log_transfer "retrieve" "${server_name}" "${remote_path}" "-" "success"
        else
            log_transfer "retrieve" "${server_name}" "${remote_path}" "-" "failed"
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

# --- Menu interactif --------------------------------------------------------

# Map global des serveurs autorisés, reconstruit à chaque affichage du menu et
# conservé entre les invocations (nécessaire au re-filtrage en chaîne).
server_map=()
counter=0

main_menu() {
    local selected_entry=""

    if [[ -z ${choice} ]] || [[ ${choice} == "null" ]]; then
        echo "Veuillez sélectionner un serveur auquel vous connecter :"
        server_map=()
        counter=0
        while read -r line; do
            [[ -z ${line} ]] && continue
            read -r ip port custom_name server_user _server_users server_authmethod server_auth <<<"${line}"
            server_map[counter]="${ip} ${port} ${server_user} ${server_authmethod} ${server_auth} ${custom_name}"
            echo "${counter}) ${custom_name} - ${server_user} ${ip}:${port}"
            counter=$((counter + 1))
        done <<<"${USER_SERVERS}"

        echo "${counter}) Tapez 'quit' ou ${counter} pour vous déconnecter."
        echo "f) Tapez 'f'<nom de l'hote> pour filtrer les entrées."

        read -r -p "Votre choix (0-${counter}) : " choice
    fi

    if [[ ${choice} == "quit" ]] || [[ ${choice} == "${counter}" ]]; then
        echo "Déconnexion du bastion."
        exit 0
    elif [[ ${choice} == f* ]]; then
        local filter="${choice#f}"
        local -a filtered_map=()
        local idx entry f_counter=0 new_choice
        for idx in "${!server_map[@]}"; do
            entry="${server_map[${idx}]}"
            # Le nom personnalisé est le dernier champ de l'entrée.
            if [[ -z ${filter} ]] || [[ ${entry##* } == *"${filter}"* ]]; then
                filtered_map+=("${idx}")
            fi
        done
        echo "=====Résultats du filtre (${#filtered_map[@]})====="
        for idx in "${filtered_map[@]}"; do
            entry="${server_map[${idx}]}"
            # cut -f préserve les champs vides (méthode d'auth optionnelle).
            f_ip=$(echo "${entry}" | cut -d ' ' -f 1)
            f_port=$(echo "${entry}" | cut -d ' ' -f 2)
            f_user=$(echo "${entry}" | cut -d ' ' -f 3)
            echo "${f_counter}) ${entry##* } - ${f_user} ${f_ip}:${f_port}"
            f_counter=$((f_counter + 1))
        done
        if [[ ${f_counter} -eq 0 ]]; then
            echo "Aucun hôte ne correspond au filtre \"${filter}\"."
            choice="null"
            return
        fi
        read -r -p "Votre choix (0-$((f_counter - 1))), 'f'<filtre> pour refiltrer, 'quit' pour quitter : " new_choice
        if [[ ${new_choice} == "quit" ]]; then
            echo "Déconnexion du bastion."
            exit 0
        elif [[ ${new_choice} == f* ]]; then
            # Nouveau filtre : sera traité à la prochaine itération du menu.
            choice="${new_choice}"
            return
        elif [[ ${new_choice} =~ ^[0-9]+$ ]] && [[ ${new_choice} -lt ${f_counter} ]]; then
            # Remapping : l'index affiché pointe vers la vraie entrée du menu.
            selected_entry="${server_map[${filtered_map[${new_choice}]}]}"
        else
            echo "Sélection invalide."
            choice="null"
            return
        fi
    elif [[ ${choice} =~ ^[0-9]+$ ]] && [[ -n ${server_map[${choice}]+isset} ]]; then
        selected_entry="${server_map[${choice}]}"
    else
        echo "Sélection invalide."
        choice="null"
        return
    fi

    # L'entrée du map est au format : ip port utilisateur methode_auth fichier_cle nom.
    # cut -f préserve les champs vides (méthode d'auth optionnelle = fallback mot de passe).
    srv_ip=$(echo "${selected_entry}" | cut -d ' ' -f 1)
    srv_port=$(echo "${selected_entry}" | cut -d ' ' -f 2)
    srv_user=$(echo "${selected_entry}" | cut -d ' ' -f 3)
    srv_authmethod=$(echo "${selected_entry}" | cut -d ' ' -f 4)
    srv_authfile=$(echo "${selected_entry}" | cut -d ' ' -f 5)
    local -a key_opts=()
    local tmp_key=""
    if [[ ${srv_authmethod} == "key" ]]; then
        local keyfile="${AUTHORIZED_SERVERS_DIR}/${srv_authfile}"
        if [[ -z ${srv_authfile} ]] || [[ ! -f ${keyfile} ]]; then
            log_connection "connect" "${srv_ip}:${srv_port}" "${srv_user}" "error" "--${srv_ip}-${srv_user}--"
            echo -e "Un problème de configuration a été détecté sur \nles options de connexion à l'hôte selectionné.\nVeuillez contacter votre administrateur."
            choice="null"
            return
        fi
        # Copie temporaire 0600 de la clé (voir prepare_key) : ssh refuse les
        # clés partagées lisibles par le groupe. Plus de ssh-agent : la clé
        # n'est plus conservée en mémoire pendant toute la session.
        tmp_key=$(prepare_key "${keyfile}")
        if [[ -z ${tmp_key} ]]; then
            echo "Impossible de préparer la clé de connexion. Veuillez contacter votre administrateur."
            choice="null"
            return
        fi
        key_opts=(-i "${tmp_key}" -o IdentitiesOnly=yes)
    fi

    echo "Connexion à ${srv_user}@${srv_ip}:${srv_port}..."
    # Les enregistrements sont écrits dans /var/log/monosphere/sessions/<user>/
    # (pré-créé par l'entrypoint) : ils survivent aux redéploiements et ne sont
    # plus stockés dans le home de l'utilisateur.
    local user_session_dir="${SESSIONS_BASE_DIR}/${CONNECTED_USER}"
    mkdir -p "${user_session_dir}" 2>/dev/null || true
    log_connection "connect" "${srv_ip}:${srv_port}" "${srv_user}" "start" "--${srv_ip}-${srv_user}--"
    ttyrec -d "${user_session_dir}" -z --"${srv_ip}-${srv_user}--" -k 300 --warn-before-kill 60 -- \
        ssh "${SSH_OPTS[@]}" "${key_opts[@]}" -p "${srv_port}" "${srv_user}@${srv_ip}"
    log_connection "disconnect" "${srv_ip}:${srv_port}" "${srv_user}" "end" "--${srv_ip}-${srv_user}--"
    rm -f "${tmp_key}"
    choice="null"
}

while true; do
    main_menu
    clear
done
