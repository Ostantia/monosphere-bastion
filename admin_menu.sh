#!/bin/bash
#
# admin_menu.sh - Menu d'administration du bastion Monosphere.
# Affiché en ForceCommand pour le groupe "bastionadmin". Les options proposées
# dépendent des droits listés dans /opt/public/rights/admin_rights.txt.

SESSIONS_BASE_DIR="/var/log/monosphere/sessions"

# Les commandes non-interactives (push_file / retrieve_file) sont déléguées
# au menu serveur, qui applique les mêmes contrôles pour les administrateurs.
if [[ -n ${SSH_ORIGINAL_COMMAND} ]]; then
    bash /opt/public/scripts/server_menu.sh
    exit $?
fi

function secure_file_editor() {
    local file_path="${*}"
    local -a lines=()
    local cmd rest line_num new_content modified=0

    if [[ -f ${file_path} ]]; then
        while IFS= read -r line; do
            lines+=("${line}")
        done <"${file_path}"
    fi

    echo ""
    echo "===== SECURE FILE EDITOR ====="
    echo "Fichier : ${file_path}"
    echo ""

    set +H
    while true; do
        echo "--- Lignes ${#lines[@]} ---"
        if [[ ${#lines[@]} -eq 0 ]]; then
            echo "(fichier vide)"
        else
            for i in "${!lines[@]}"; do
                printf '%3d: %s\n' $((i + 1)) "${lines[${i}]}"
            done
        fi
        echo "---------------------------"
        echo "e <n> <texte>  - Remplacer la ligne n"
        echo "i <n> <texte>  - Inserer apres la ligne n (0 = debut)"
        echo "d <n>          - Supprimer la ligne n"
        echo "wq             - Enregistrer et quitter"
        echo "q!             - Quitter sans enregistrer"
        echo ""

        read -r -p "> " input
        cmd="${input%% *}"
        rest="${input#* }"

        case "${cmd}" in
        e)
            line_num="${rest%% *}"
            new_content="${rest#* }"
            if [[ ${line_num} =~ ^[0-9]+$ ]] && ((line_num >= 1 && line_num <= ${#lines[@]})); then
                lines[line_num - 1]="${new_content}"
                modified=1
            else
                echo "Ligne invalide (1-${#lines[@]})."
            fi
            ;;
        i)
            line_num="${rest%% *}"
            new_content="${rest#* }"
            if [[ ${line_num} =~ ^[0-9]+$ ]] && ((line_num >= 0 && line_num <= ${#lines[@]})); then
                lines=("${lines[@]:0:line_num}" "${new_content}" "${lines[@]:line_num}")
                modified=1
            else
                echo "Position invalide (0-${#lines[@]})."
            fi
            ;;
        d)
            line_num="${rest}"
            if [[ ${line_num} =~ ^[0-9]+$ ]] && ((line_num >= 1 && line_num <= ${#lines[@]})); then
                unset 'lines[$((line_num - 1))]'
                lines=("${lines[@]}")
                modified=1
            else
                echo "Ligne invalide (1-${#lines[@]})."
            fi
            ;;
        wq)
            if [[ ${modified} -eq 1 ]] || [[ ! -f ${file_path} ]]; then
                if [[ ${#lines[@]} -eq 0 ]]; then
                    rm -f "${file_path}"
                    echo "Fichier vide, supprime."
                else
                    # Écriture via un fichier temporaire puis réinjection dans le
                    # fichier d'origine ("cat > fichier") : l'inode est conservée,
                    # donc propriétaire, permissions et ACL aussi. Un crash au
                    # milieu de l'écriture ne corrompt pas le fichier.
                    local tmpfile write_ok=0
                    tmpfile=$(mktemp "${file_path}.XXXXXX" 2>/dev/null || true)
                    if [[ -n ${tmpfile} ]]; then
                        if printf '%s\n' "${lines[@]}" >"${tmpfile}" && cat "${tmpfile}" >"${file_path}"; then
                            write_ok=1
                        fi
                        rm -f "${tmpfile}"
                    elif printf '%s\n' "${lines[@]}" >"${file_path}"; then
                        write_ok=1
                    fi
                    if [[ ${write_ok} -eq 1 ]]; then
                        echo "Fichier enregistre (${#lines[@]} lignes)."
                    else
                        echo "Erreur lors de l'ecriture du fichier, modifications non enregistrees."
                    fi
                fi
            else
                echo "Aucune modification."
            fi
            break
            ;;
        q | 'q!')
            echo "Abandon."
            break
            ;;
        *)
            echo "Commandes : e <n> <txt>, i <n> <txt>, d <n>, wq, q!"
            ;;
        esac
        echo ""
    done
    echo ""
}

function sessions_viewer() {
    while true; do
        echo -e "Ci dessous les utilisateurs disponibles sur le bastion.\nVeillez sélectionner celui dont vous souhaitez visionner les accès :"
        Available_Users=$(find /home/. -maxdepth 1 -type d 2>/dev/null | grep -v "\.$" | cut -d "/" -f 4)
        users_counter=0
        declare -A users_map
        while read -r line; do
            user="${line}"
            [[ -z ${user} ]] && continue
            users_map[${users_counter}]="${user}"
            echo "${users_counter}) ${user}"
            users_counter=$((users_counter + 1))
        done <<<"${Available_Users}"

        echo "${users_counter}) Tapez 'quit' ou ${users_counter} pour revenir au menu précédent."

        read -r -p "Votre choix (0-${users_counter}): " choice

        if [[ ${choice} == "quit" ]] || [[ ${choice} == "${users_counter}" ]]; then
            return
        elif [[ $(echo "${choice}" | cut -c1-1) == "f" ]]; then
            filter=$(echo "${choice}" | cut -c2-)
            echo "=====Résultats du filtre====="
            for idx in "${!users_map[@]}"; do
                if [[ ${users_map[${idx}]} == *"${filter}"* ]]; then
                    echo "${idx}) ${users_map[${idx}]}"
                fi
            done
            read -r -p "Votre choix (0-${users_counter}) : " choice
        elif [[ -z ${choice} ]] || [[ -z ${users_map[${choice}]} ]]; then
            clear
            echo "Sélection invalide."
        else
            local selected_option="${users_map[${choice}]}"
            while true; do
                # Les sessions sont stockées dans /var/log/monosphere/sessions/<user>/
                Available_Sessions=$(find "${SESSIONS_BASE_DIR}/${selected_option}/." -maxdepth 1 -type f -name "*.ttyrec" 2>/dev/null | grep -v "\.$" | cut -d "/" -f 8)
                echo "Sélectionnez une session de cet utilisateur que vous souhaitez visionner :"

                sessions_counter=1
                declare -A sessions_map
                while read -r line; do
                    session_name="${line}"
                    [[ -z ${session_name} ]] && continue
                    sessions_map[${sessions_counter}]="${session_name}"
                    echo "${sessions_counter}) ${session_name}"
                    sessions_counter=$((sessions_counter + 1))
                done <<<"${Available_Sessions}"

                echo "${sessions_counter}) Tapez 'quit' ou ${sessions_counter} pour revenir au choix d'utilisateur."

                read -r -p "Votre choix (1-${sessions_counter}): " choice
                if [[ ${choice} == "quit" ]] || [[ ${choice} == "${sessions_counter}" ]]; then
                    break
                elif [[ -z ${choice} ]] || [[ -z ${sessions_map[${choice}]} ]]; then
                    clear
                    echo "Sélection invalide."
                else
                    ttyplay "${SESSIONS_BASE_DIR}/${selected_option}/${sessions_map[${choice}]}"
                fi
            done
        fi
    done
}

function servers_access_control() {
    echo -e "Choisissez une option d'administration des serveurs ci dessous :"
    echo -e "1) Ajout de fichiers clés privées pour l'authentification aux serveurs distants.\n2) Modification des droits d'accès aux serveurs.\n3) Tapez 'quit' ou 3 pour revenir au menu précédent."

    read -r -p "Votre choix (1-3): " choice

    case "${choice}" in
    "1")
        clear
        Authorization_Files_List=$(find /opt/public/servers/. -type f ! -name 'authorized_servers.txt' 2>/dev/null | cut -d "/" -f 6)
        echo -e "Le ficher d'authentification qui sera crée ou modifié sera placé dans le répertoire \"/opt/public/servers/\" du bastion.\nle nom de ce dernier ne doit pas comporter de \"/\", être vide ou être égal à \"authorized_servers.txt\"."
        echo -e "Ci dessous la liste des fichiers d'authentification existants :\n${Authorization_Files_List}"
        read -r -p 'Entrez le nom du fichier: ' File_Name

        if [[ $(echo "${File_Name}" | grep -m1 -o "/" | head -1) == "/" ]] || [[ $(echo "${File_Name}" | grep -m1 -o "*" | head -1) == "*" ]] || [[ -z ${File_Name} ]] || [[ ${File_Name} == "authorized_servers.txt" ]]; then
            echo 'Le nom du fichier ne doit pas contenir les caractères "/" ou "*", être vide ou ce nommer "authorized_servers.txt". Veuillez modifier ce dernier.'
        else
            echo "Assurez vous que le fichier créé ou modifié comporte bien uniquement la clé privée nécessaire à la connexion."
            secure_file_editor "/opt/public/servers/${File_Name}"
            if [[ $(cat "/opt/public/servers/${File_Name}" 2>/dev/null) == "" ]]; then
                echo "Le fichier modifié \"${File_Name}\" est vide. Ce dernier sera supprimé."
                rm -f "/opt/public/servers/${File_Name}"
            else
                # Best effort : le démon de normalisation des permissions de
                # l'entrypoint finalisera la propriété et les ACL sous ~60 secondes.
                chmod 660 "/opt/public/servers/${File_Name}" 2>/dev/null || true
                chown root:root "/opt/public/servers/${File_Name}" 2>/dev/null || true
                echo "NB : la clé devient pleinement utilisable par les utilisateurs sous environ 60 secondes (normalisation automatique des permissions)."
            fi
        fi
        ;;

    "2")
        clear
        echo -e "Veuillez bien vérifier la syntaxe de votre configuration avant de valider cette dernière.\nPour plus d'informations, consultez la documentation de Monosphere."
        secure_file_editor "/opt/public/servers/authorized_servers.txt"
        ;;

    "3" | "quit")
        return
        ;;

    *)
        clear
        echo "Sélection invalide."
        ;;
    esac
}

function admin_rights_control() {
    echo -e "Veuillez bien vérifier la syntaxe de votre configuration avant de valider cette dernière.\nPour plus d'informations, consultez la documentation de Monosphere."
    secure_file_editor "/opt/public/rights/admin_rights.txt"
}

function transfer_rights_control() {
    echo -e "Editez les droits de transfert de fichiers ci dessous.\nFormat : nom_serveur user1,user2,...\nSi le fichier est vide ou absent, tous les utilisateurs autorises (via authorized_servers.txt) peuvent transferer."
    secure_file_editor "/opt/public/rights/transfer_rights.txt"
}

function main_menu() {
    clear
    ADMIN_RIGHTS_FILE="/opt/public/rights/admin_rights.txt"
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

    counter=0
    adminrights_list=()
    while read -r line; do
        admin_right=$(echo "${line}" | cut -d ' ' -f 1)
        admin_right_pretty_name=$(echo "${line}" | cut -d ' ' -f 2)
        if [[ -n ${admin_right_pretty_name} ]]; then
            adminrights_list[counter]="${admin_right} ${admin_right_pretty_name}"
            counter=$((counter + 1))
        fi
    done <<<"${ADMIN_RIGHTS}"

    if [[ ${counter} -gt 0 ]]; then
        echo "Veuillez sélectionner une option d'administration :"
        for ((idx = 0; idx < counter; idx++)); do
            echo "${idx}) $(echo "${adminrights_list[${idx}]}" | cut -d ' ' -f 2-)"
        done
    else
        echo "Vous n'avez aucune autorisation d'administration."
    fi
    echo "Vous pouvez cependant vous connecter aux serveurs dont l'accès vous est autorisé."

    local servers_access_idx=${counter}
    echo "${counter}) Tapez 'servers_access' ou ${counter} pour vous connecter a un serveur."
    counter=$((counter + 1))
    local logs_idx=${counter}
    echo "${counter}) Tapez 'logs' ou ${counter} pour consulter les logs de transfert."
    counter=$((counter + 1))
    local quit_idx=${counter}
    echo "${counter}) Tapez 'quit' ou ${counter} pour vous déconnecter."

    read -r -p "Votre choix (0-${counter}): " choice

    if [[ ${choice} == "servers_access" ]] || [[ ${choice} == "${servers_access_idx}" ]]; then
        bash /opt/public/scripts/server_menu.sh
    elif [[ ${choice} == "logs" ]] || [[ ${choice} == "${logs_idx}" ]]; then
        clear
        if [[ -f /var/log/monosphere/transfers.log ]]; then
            cat /var/log/monosphere/transfers.log
        else
            echo "Aucun log de transfert disponible."
        fi
        read -r -p "Appuyez sur Entree pour continuer..."
    elif [[ ${choice} == "quit" ]] || [[ ${choice} == "${quit_idx}" ]]; then
        echo "Déconnexion du bastion."
        exit 0
    elif [[ -z ${choice} ]] || [[ -z ${adminrights_list[${choice}]+isset} ]]; then
        clear
        echo "Sélection invalide."
    else
        local selected_option
        selected_option="${adminrights_list[${choice}]}"
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

        "transfercontrol_admins")
            clear
            transfer_rights_control
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
}

while true; do
    main_menu
done
