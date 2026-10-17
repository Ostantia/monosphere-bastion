#!/bin/bash
#
# admin_menu.sh - Menu d'administration du bastion Monosphere.
# Affiché en ForceCommand pour le groupe "bastionadmin". Les options proposées
# dépendent des droits listés dans /opt/public/rights/admin_rights.txt.

SESSIONS_BASE_DIR="/var/log/monosphere/sessions"
LOG_DIR="/var/log/monosphere"
ADMIN_ACTIONS_LOG="/var/log/monosphere/admin_actions.log"
EVENTS_LOG="/var/log/monosphere/events.log"

# Umask stricte : les fichiers créés par les menus (enregistrements, copies
# temporaires de clés) ne sont accessibles qu'à leur propriétaire, sauf
# décision explicite (ACL posées par l'entrypoint).
umask 077

# État du menu de visionnage des sessions :
sessions_dt_date=""       # partie date du filtre date/heure courant (préfixe)
sessions_dt_time=""       # partie heure du filtre date/heure courant (préfixe)
sessions_sort_mode="date" # tri courant des sessions : "date" ou "machine"
sessions_list=()          # sessions brutes, entrées "utilisateur nomdefichier"
sessions_sorted=()        # sessions filtrées et triées, telles qu'affichées
sessions_pick=""          # résultat du dernier affichage/choix de sessions
sessions_dt_pending=""    # critère date/heure en attente de validation

# Les commandes non-interactives (push_file / retrieve_file) sont déléguées
# au menu serveur, qui applique les mêmes contrôles pour les administrateurs.
if [[ -n ${SSH_ORIGINAL_COMMAND} ]]; then
    bash /opt/public/scripts/server_menu.sh
    exit $?
fi

# Journalise une action d'administration (sauvegarde/suppression de fichier
# via l'éditeur sécurisé) dans admin_actions.log et dans events.log (miroir
# vers la sortie du conteneur). Jamais bloquant ni visible en cas d'échec
# d'écriture (l'erreur de redirection bash précède le 2>/dev/null, d'où le
# groupe { ... } qui l'englobe).
log_admin_action() {
    local action="$1" file_path="$2" lines="$3"
    local line
    line="$(date '+%Y-%m-%d %H:%M:%S') ADMIN=$(whoami) ACTION=${action} FILE=${file_path} LINES=${lines} STATUS=success"
    { echo "${line}" >>"${ADMIN_ACTIONS_LOG}"; } 2>/dev/null || true
    { echo "${line}" >>"${EVENTS_LOG}"; } 2>/dev/null || true
}

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
                    log_admin_action "delete" "${file_path}" 0
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
                        log_admin_action "save" "${file_path}" "${#lines[@]}"
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

# --- Utilitaires du menu de visionnage des sessions -------------------------

# Extrait la clé "machine" (hôte-utilisateur distant) d'un nom de fichier
# ttyrec. Exemple : "2026-10-17.08-26-03.869130.--hote-utilisateur--.ttyrec"
# donne "hote-utilisateur". Utilisée pour le tri par machine.
session_machine_key() {
    local name="$1" key
    key="${name#*.--}"
    key="${key%--.ttyrec}"
    printf '%s' "${key}"
}

# Analyse un critère de recherche date/heure saisi après "d" :
#   - date seule (préfixe)              : 2026, 2026-10, 2026-10-17
#   - heure seule (préfixe, ":" ou "-") : 14, 14:3, 14:30
#   - les deux, séparés par un espace   : 2026-10-17 14:30
# Alimente sessions_dt_date / sessions_dt_time. Retourne 1 si le critère
# contient des caractères autres que chiffres, tirets, deux-points, espaces.
sessions_parse_dt() {
    local crit="$1"
    sessions_dt_date=""
    sessions_dt_time=""
    if [[ ${crit} == *" "* ]]; then
        sessions_dt_date="${crit%% *}"
        sessions_dt_time="${crit#* }"
    elif [[ ${crit} == *:* ]]; then
        sessions_dt_time="${crit}"
    else
        sessions_dt_date="${crit}"
    fi
    # Normalisation : l'heure au format fichier utilise des tirets (HH-MM-SS).
    sessions_dt_date=${sessions_dt_date//:/-}
    sessions_dt_time=${sessions_dt_time//:/-}
    [[ ${sessions_dt_date} =~ ^[0-9-]*$ ]] && [[ ${sessions_dt_time} =~ ^[0-9-]*$ ]]
}

# Teste la correspondance d'un nom de session avec le filtre date/heure
# courant (simple préfixe sur les champs date et heure du nom de fichier,
# qui commence toujours par AAAA-MM-JJ.HH-MM-SS.<microsecondes>.).
sessions_match_dt() {
    local name="$1" fdate ftime
    if [[ -n ${sessions_dt_date} ]]; then
        fdate="${name%%.*}"
        [[ ${fdate} == "${sessions_dt_date}"* ]] || return 1
    fi
    if [[ -n ${sessions_dt_time} ]]; then
        ftime="${name#*.}"
        ftime="${ftime%%.*}"
        [[ ${ftime} == "${sessions_dt_time}"* ]] || return 1
    fi
    return 0
}

# Remplit sessions_list avec les sessions d'un utilisateur
# (entrées "utilisateur nomdefichier").
sessions_load_user() {
    local user="$1" line
    sessions_list=()
    while IFS= read -r line; do
        [[ -z ${line} ]] && continue
        sessions_list+=("${user} ${line##*/}")
    done < <(find "${SESSIONS_BASE_DIR}/${user}/." -maxdepth 1 -type f -name "*.ttyrec" 2>/dev/null)
}

# Remplit sessions_list avec les sessions de TOUS les utilisateurs
# (mode recherche globale).
sessions_load_all() {
    local dir user line
    sessions_list=()
    while IFS= read -r dir; do
        [[ -z ${dir} ]] && continue
        user="${dir##*/}"
        while IFS= read -r line; do
            [[ -z ${line} ]] && continue
            sessions_list+=("${user} ${line##*/}")
        done < <(find "${dir}/." -maxdepth 1 -type f -name "*.ttyrec" 2>/dev/null)
    done < <(find "${SESSIONS_BASE_DIR}/." -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
}

# Applique le filtre date/heure à sessions_list puis trie le résultat dans
# sessions_sorted selon sessions_sort_mode ("date" : chronologique, "machine" :
# regroupé par hôte-utilisateur distant puis chronologique).
sessions_build_view() {
    local entry
    local -a filtered=()
    for entry in "${sessions_list[@]}"; do
        sessions_match_dt "${entry#* }" && filtered+=("${entry}")
    done
    sessions_sorted=()
    if [[ ${sessions_sort_mode} == "machine" ]]; then
        while IFS= read -r entry; do
            [[ -z ${entry} ]] && continue
            sessions_sorted+=("${entry}")
        done < <(for entry in "${filtered[@]}"; do
            printf '%s|%s\n' "$(session_machine_key "${entry#* }")" "${entry}"
        done | sort -t'|' -k1,1 -k2,2 | cut -d'|' -f2-)
    else
        while IFS= read -r entry; do
            [[ -z ${entry} ]] && continue
            sessions_sorted+=("${entry}")
        done < <(printf '%s\n' "${filtered[@]}" | sort)
    fi
}

# Affiche la vue courante des sessions et lit le choix de l'administrateur.
# Argument 1 : en-tête du menu. Argument 2 : 1 pour afficher l'utilisateur
# (mode global), 0 sinon. Définit sessions_pick :
#   - "utilisateur nomdefichier" si une session est sélectionnée
#   - "toggle" (changer le tri), "refilter" (nouveau critère dans
#     sessions_dt_pending), "back" (retour) ou "" (choix invalide).
sessions_display_and_pick() {
    local label="$1" show_user="$2"
    local count=${#sessions_sorted[@]}
    local i entry suser name prefix choice_read
    echo "=====${label} (tri : ${sessions_sort_mode})====="
    if [[ -n ${sessions_dt_date} ]] || [[ -n ${sessions_dt_time} ]]; then
        echo "Filtre date/heure actif : ${sessions_dt_date} ${sessions_dt_time}"
    fi
    if [[ ${count} -eq 0 ]]; then
        echo "(aucune session ne correspond)"
    fi
    for i in "${!sessions_sorted[@]}"; do
        entry="${sessions_sorted[${i}]}"
        suser="${entry%% *}"
        name="${entry#* }"
        prefix=""
        if [[ ${sessions_sort_mode} == "machine" ]]; then
            prefix="[$(session_machine_key "${name}")] "
        fi
        if [[ ${show_user} -eq 1 ]]; then
            echo "$((i + 1))) ${prefix}[${suser}] ${name}"
        else
            echo "$((i + 1)) ${prefix}${name}"
        fi
    done
    echo "Tapez un numéro pour visionner, 't' pour basculer le tri (date <-> machine),"
    echo "'d'<critère> pour filtrer par date/heure ('d' seul réinitialise), 'quit' pour revenir."
    read -r -p "Votre choix (1-${count}) : " choice_read || {
        # EOF (flux d'entrée fermé) : sortir proprement du menu.
        sessions_pick="back"
        return
    }
    sessions_pick=""
    if [[ ${choice_read} == "quit" ]]; then
        sessions_pick="back"
    elif [[ ${choice_read} == "t" ]]; then
        sessions_pick="toggle"
    elif [[ ${choice_read} == d* ]]; then
        sessions_dt_pending="${choice_read#d}"
        sessions_pick="refilter"
    elif [[ ${choice_read} =~ ^[0-9]+$ ]] && [[ ${choice_read} -ge 1 ]] && [[ ${choice_read} -le ${count} ]]; then
        sessions_pick="${sessions_sorted[$((choice_read - 1))]}"
    fi
}

# Boucle commune aux menus de sessions (par utilisateur et global) : affiche
# la vue, gère tri/filtre et lance ttyplay sur la session choisie.
# Argument 1 : en-tête. Argument 2 : 1 pour le mode global (affiche l'utilisateur).
sessions_menu_loop() {
    local label="$1" show_user="$2" pick suser sname
    while true; do
        clear
        if [[ ${show_user} -eq 1 ]]; then
            sessions_load_all
        else
            sessions_load_user "${label#Sessions de }"
        fi
        sessions_build_view
        sessions_display_and_pick "${label}" "${show_user}"
        pick="${sessions_pick}"
        case "${pick}" in
        back)
            return
            ;;
        toggle)
            if [[ ${sessions_sort_mode} == "date" ]]; then
                sessions_sort_mode="machine"
            else
                sessions_sort_mode="date"
            fi
            ;;
        refilter)
            if [[ -z ${sessions_dt_pending} ]]; then
                sessions_dt_date=""
                sessions_dt_time=""
            elif sessions_parse_dt "${sessions_dt_pending}"; then
                : # sessions_dt_date / sessions_dt_time sont positionnées
            else
                echo "Critère date/heure invalide : \"${sessions_dt_pending}\" (caractères autorisés : chiffres, '-', ':', espace)."
                read -r -p "Appuyez sur Entree pour continuer..."
            fi
            ;;
        "")
            echo "Sélection invalide."
            read -r -p "Appuyez sur Entree pour continuer..."
            ;;
        *)
            suser="${pick%% *}"
            sname="${pick#* }"
            ttyplay "${SESSIONS_BASE_DIR}/${suser}/${sname}"
            ;;
        esac
    done
}

# Menu des sessions d'un utilisateur précis (tri et filtre réinitialisés).
function sessions_user_menu() {
    sessions_sort_mode="date"
    sessions_dt_date=""
    sessions_dt_time=""
    sessions_menu_loop "Sessions de $1" 0
}

# Menu de recherche globale des sessions de tous les utilisateurs.
# Appelé avec sessions_dt_date / sessions_dt_time déjà positionnés.
function sessions_global_menu() {
    sessions_sort_mode="date"
    sessions_menu_loop "Recherche globale de sessions" 1
}

function sessions_viewer() {
    # Variable locale : évite la fuite du choix du menu d'administration
    # (même processus shell) qui provoquait une interprétation erronée au
    # premier passage.
    local choice="null"
    while true; do
        if [[ -z ${choice} ]] || [[ ${choice} == "null" ]]; then
            clear
            echo -e "Ci dessous les utilisateurs disponibles sur le bastion.\nVeillez sélectionner celui dont vous souhaitez visionner les accès :"
            Available_Users=$(find /home/. -maxdepth 1 -type d 2>/dev/null | grep -v "\.$")
            users_counter=0
            declare -A users_map
            while read -r line; do
                # basename du répertoire trouvé (robuste quelle que soit la
                # profondeur du chemin et la variante de find).
                user="${line##*/}"
                [[ -z ${user} ]] && continue
                [[ ${user} == "." ]] && continue
                users_map[${users_counter}]="${user}"
                echo "${users_counter}) ${user}"
                users_counter=$((users_counter + 1))
            done <<<"${Available_Users}"

            echo "${users_counter}) Tapez 'quit' ou ${users_counter} pour revenir au menu précédent."
            echo "f) Tapez 'f'<nom d'utilisateur> pour filtrer les utilisateurs."
            echo "d) Tapez 'd'<critère> pour chercher des sessions par date/heure chez tous les utilisateurs."
            echo "   Exemples : d2026, d2026-10-17, d14:30, \"d2026-10-17 14:30\""

            read -r -p "Votre choix (0-${users_counter}): " choice
        fi

        if [[ ${choice} == "quit" ]] || [[ ${choice} == "${users_counter}" ]]; then
            return
        elif [[ ${choice} == f* ]]; then
            # Filtre d'utilisateurs : les résultats sont réindexés, et un
            # nouveau filtre peut être appliqué en chaîne ('f'<filtre>).
            local filter="${choice#f}"
            local -a filtered_users=()
            local idx
            for idx in "${!users_map[@]}"; do
                if [[ -z ${filter} ]] || [[ ${users_map[${idx}]} == *"${filter}"* ]]; then
                    filtered_users+=("${idx}")
                fi
            done
            clear
            echo "=====Utilisateurs correspondant à \"${filter}\" (${#filtered_users[@]})====="
            local f_counter=0 new_choice
            for idx in "${filtered_users[@]}"; do
                echo "${f_counter}) ${users_map[${idx}]}"
                f_counter=$((f_counter + 1))
            done
            if [[ ${f_counter} -eq 0 ]]; then
                echo "Aucun utilisateur ne correspond à ce filtre."
                read -r -p "Appuyez sur Entree pour continuer..."
                choice="null"
                continue
            fi
            read -r -p "Votre choix (0-$((f_counter - 1))), 'f'<filtre> pour refiltrer, 'quit' : " new_choice
            if [[ ${new_choice} == "quit" ]]; then
                return
            elif [[ ${new_choice} == f* ]]; then
                # Nouveau filtre : sera traité à la prochaine itération.
                choice="${new_choice}"
                continue
            elif [[ ${new_choice} =~ ^[0-9]+$ ]] && [[ ${new_choice} -lt ${f_counter} ]]; then
                # Remapping : l'index affiché pointe vers le vrai utilisateur.
                sessions_user_menu "${users_map[${filtered_users[${new_choice}]}]}"
                choice="null"
            else
                echo "Sélection invalide."
                read -r -p "Appuyez sur Entree pour continuer..."
                choice="null"
            fi
        elif [[ ${choice} == d* ]]; then
            # Recherche globale par date/heure chez tous les utilisateurs.
            local crit="${choice#d}"
            if [[ -z ${crit} ]]; then
                echo "Usage : d<critère> (exemples : d2026, d2026-10-17, d14:30, \"d2026-10-17 14:30\")."
                read -r -p "Appuyez sur Entree pour continuer..."
                choice="null"
                continue
            fi
            if ! sessions_parse_dt "${crit}"; then
                echo "Critère date/heure invalide : \"${crit}\" (caractères autorisés : chiffres, '-', ':', espace)."
                read -r -p "Appuyez sur Entree pour continuer..."
                choice="null"
                continue
            fi
            sessions_global_menu
            choice="null"
        elif [[ -z ${choice} ]] || [[ -z ${users_map[${choice}]+isset} ]]; then
            clear
            echo "Sélection invalide."
            choice="null"
        else
            sessions_user_menu "${users_map[${choice}]}"
            choice="null"
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

# Visionneur des journaux du bastion : choix du journal, puis affichage des
# 50 dernières lignes, du journal complet, ou d'une recherche par utilisateur.
function logs_viewer() {
    local logs_dir="${LOG_DIR}"
    while true; do
        clear
        echo "Choisissez un journal a consulter :"
        echo "1) Transferts de fichiers (transfers.log)"
        echo "2) Connexions aux serveurs (connections.log)"
        echo "3) Actions d'administration (admin_actions.log)"
        echo "4) Événements SSHD (sshd.log)"
        echo "5) Tapez 'quit' ou 5 pour revenir au menu précédent."

        local log_choice log_file=""
        read -r -p "Votre choix (1-5): " log_choice || return 0
        case "${log_choice}" in
        1) log_file="${logs_dir}/transfers.log" ;;
        2) log_file="${logs_dir}/connections.log" ;;
        3) log_file="${logs_dir}/admin_actions.log" ;;
        4) log_file="${logs_dir}/sshd.log" ;;
        5 | quit) return ;;
        *)
            echo "Sélection invalide."
            read -r -p "Appuyez sur Entree pour continuer..."
            continue
            ;;
        esac

        clear
        if [[ ! -f ${log_file} ]]; then
            echo "Journal inexistant : ${log_file}"
            read -r -p "Appuyez sur Entree pour continuer..."
            continue
        fi

        echo "Affichage de $(basename "${log_file}") :"
        echo "1) 50 dernières lignes"
        echo "2) Journal complet"
        echo "3) Recherche par utilisateur"
        local view_choice search
        read -r -p "Votre choix (1-3): " view_choice || return 0
        clear
        case "${view_choice}" in
        2) cat "${log_file}" ;;
        3)
            read -r -p "Nom d'utilisateur à rechercher : " search || return 0
            if [[ -z ${search} ]]; then
                cat "${log_file}"
            else
                grep -- "${search}" "${log_file}" || echo "Aucune occurrence de \"${search}\" dans ce journal."
            fi
            ;;
        *)
            tail -n 50 "${log_file}" 2>/dev/null || echo "Journal vide."
            ;;
        esac
        read -r -p "Appuyez sur Entree pour continuer..."
    done
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
        logs_viewer
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
