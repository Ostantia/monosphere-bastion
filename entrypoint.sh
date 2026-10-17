#!/bin/bash
#
# entrypoint.sh - Configuration et démarrage du bastion Monosphere.
# S'exécute en root au démarrage du conteneur : validation de la configuration,
# création des groupes/utilisateurs, application des permissions ACL, puis
# boucle de normalisation des permissions (le process reste PID 1).

SESSIONS_BASE_DIR="/var/log/monosphere/sessions"
TRANSFER_LOG="/var/log/monosphere/transfers.log"
CONNECTIONS_LOG="/var/log/monosphere/connections.log"
ADMIN_ACTIONS_LOG="/var/log/monosphere/admin_actions.log"
EVENTS_LOG="/var/log/monosphere/events.log"
SSHD_LOG="/var/log/monosphere/sshd.log"
USERS_FILE="/root/scripts/users/bastion_users.txt"
# Seuil de rotation des journaux (octets) : au-delà, le fichier est copié en
# ".1" puis tronqué (copytruncate, compatible avec les descripteurs ouverts).
LOG_MAX_BYTES=10485760

# Préfixe du hash du mot de passe du compte "bastion" par défaut (mot de passe
# "bastion"). Utilisé pour avertir si ce mot de passe par défaut est toujours actif.
# shellcheck disable=SC2016  # littéral voulu, pas d'expansion
DEFAULT_ADMIN_HASH_PREFIX='$6$lwJT2jE8uXZhk9.X$'

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

# --- Validation des variables d'environnement --------------------------------

if ! [[ ${PORT} =~ ^[0-9]+$ ]] || [[ ${PORT} -lt 1 ]] || [[ ${PORT} -gt 65535 ]]; then
    error_msg "Code 05 : La variable PORT=\"${PORT}\" est invalide. Elle doit être un numéro de port entre 1 et 65535."
    exit 1
fi

if ! [[ ${PASSWORD_AUTH} =~ ^[01]$ ]]; then
    info_msg "PASSWORD_AUTH=\"${PASSWORD_AUTH}\" invalide, valeur par défaut 0 appliquée."
    PASSWORD_AUTH=0
fi

if ! [[ ${KEY_AUTH} =~ ^[01]$ ]]; then
    info_msg "KEY_AUTH=\"${KEY_AUTH}\" invalide, valeur par défaut 1 appliquée."
    KEY_AUTH=1
fi

# Rétention des enregistrements de sessions (jours). 0 = conservation illimitée.
if ! [[ ${SESSION_RETENTION_DAYS} =~ ^[0-9]+$ ]]; then
    if [[ -n ${SESSION_RETENTION_DAYS} ]]; then
        info_msg "SESSION_RETENTION_DAYS=\"${SESSION_RETENTION_DAYS}\" invalide, purge des sessions désactivée."
    fi
    SESSION_RETENTION_DAYS=0
fi

if [[ ${PASSWORD_AUTH} -eq 1 ]] && [[ ${KEY_AUTH} -eq 0 ]]; then
    error_msg "Configuration refusée : KEY_AUTH=0 avec PASSWORD_AUTH=1 interdirait toute connexion par clé. Activez au moins KEY_AUTH=1."
    exit 1
fi

# --- Génération de la configuration SSH --------------------------------------

if ! grep -qo "^Port ${PORT}$" /etc/ssh/sshd_config; then
    info_msg "Génération de la configuration de SSH pour le bastion Monosphere..."
    info_msg "Port selectionne pour la connexion SSH : ${PORT}"
    {
        echo "Port ${PORT}"
        echo "#Last authentication configurations"
        if [[ ${PASSWORD_AUTH} -eq 1 ]]; then
            echo "PasswordAuthentication yes"
        else
            echo "PasswordAuthentication no"
        fi
        if [[ ${KEY_AUTH} -eq 1 ]]; then
            echo "PubkeyAuthentication yes"
        else
            echo "PubkeyAuthentication no"
        fi
    } >>/etc/ssh/sshd_config
fi

if [[ ${PASSWORD_AUTH} -eq 1 ]]; then
    info_msg "/!\\ ATTENTION : l'authentification par mot de passe est ACTIVEE sur le bastion."
    info_msg "/!\\ Depuis la version 3.6.0, PASSWORD_AUTH vaut 0 par défaut. Préférez l'authentification par clés SSH."
else
    info_msg "Authentification par mot de passe desactivee (recommande)."
fi

# --- Scripts personnalisés ----------------------------------------------------

mkdir -p /opt/custom/scripts
info_msg "Monosphere active et execute les scripts personalisés"
shopt -s nullglob
custom_scripts=(/opt/custom/scripts/*.sh)
shopt -u nullglob
custom_script_errors=0
for custom_script in "${custom_scripts[@]}"; do
    chmod 700 "${custom_script}"
    info_msg "Execution du script personnalise : ${custom_script}"
    if ! bash "${custom_script}"; then
        error_msg "Code 02 : Le script personnalisé \"${custom_script}\" a rencontré une erreur.\nConsultez la documentation pour plus d'informations."
        custom_script_errors=$((custom_script_errors + 1))
    fi
done
if [[ ${custom_script_errors} -eq 0 ]]; then
    good_msg "Execution des scripts personalisés terminée."
fi

# --- Création des groupes -----------------------------------------------------

info_msg "Création des groupes d'utilisateurs."
if ! grep -q "bastionuser" /etc/group; then
    addgroup bastionuser
fi

if ! grep -q "bastionadmin" /etc/group; then
    addgroup bastionadmin
fi
good_msg "Fin de la création des groupes d'utilisateurs."

# --- Normalisation des permissions (ACL) --------------------------------------
# L'objectif : les utilisateurs peuvent lire ce qui est nécessaire aux menus et
# aux connexions, les administrateurs peuvent éditer les fichiers de droits,
# et personne ne peut altérer les journaux ou les scripts.

normalize_perms() {
    command -v setfacl >/dev/null 2>&1 || return 0

    # Normalise un journal inscriptible par les utilisateurs, lisible par les
    # administrateurs, inaccessible au reste du monde.
    normalize_user_log() {
        local file="$1"
        if [[ ! -f ${file} ]]; then
            touch "${file}"
        fi
        chown root:root "${file}"
        chmod 660 "${file}"
        setfacl -m g:bastionadmin:r--,g:bastionuser:rw-,m::rw-,o::--- "${file}"
    }

    # Racine publique et scripts (les scripts ne doivent être modifiables par personne d'autre que root)
    chown root:root /opt/public 2>/dev/null
    chmod 755 /opt/public 2>/dev/null
    chown -R root:root /opt/public/scripts 2>/dev/null
    chmod 755 /opt/public/scripts 2>/dev/null
    chmod 755 /opt/public/scripts/*.sh 2>/dev/null

    # Répertoire des serveurs distants : les administrateurs listent et éditent,
    # les utilisateurs ne peuvent que traverser (pas de listing) et lire les fichiers.
    chown root:bastionadmin /opt/public/servers
    chmod 770 /opt/public/servers
    setfacl -m g:bastionuser:--x,o::--- /opt/public/servers
    setfacl -m d:u::rw-,d:g::rw-,d:g:bastionuser:r--,d:m::rw-,d:o::--- /opt/public/servers
    for server_file in /opt/public/servers/*; do
        [[ -e ${server_file} ]] || continue
        [[ -d ${server_file} ]] && continue
        # root:root évite le refus ssh "bad permissions" sur les clés privées
        # (le contrôle strict ne s'applique qu'aux fichiers appartenant à l'utilisateur).
        chown root:root "${server_file}"
        chmod 660 "${server_file}"
        setfacl -m g:bastionadmin:rw-,g:bastionuser:r--,m::rw-,o::--- "${server_file}"
    done

    # Répertoire des droits : les administrateurs éditent, les utilisateurs
    # peuvent uniquement traverser et lire transfer_rights.txt.
    chown root:root /opt/public/rights
    chmod 750 /opt/public/rights
    setfacl -m g:bastionadmin:r-x,g:bastionuser:--x,o::--- /opt/public/rights
    if [[ -f /opt/public/rights/admin_rights.txt ]]; then
        chown root:root /opt/public/rights/admin_rights.txt
        chmod 660 /opt/public/rights/admin_rights.txt
        setfacl -m g:bastionadmin:rw-,m::rw-,o::--- /opt/public/rights/admin_rights.txt
    fi
    if [[ -f /opt/public/rights/transfer_rights.txt ]]; then
        chown root:root /opt/public/rights/transfer_rights.txt
        chmod 660 /opt/public/rights/transfer_rights.txt
        setfacl -m g:bastionadmin:rw-,g:bastionuser:r--,m::rw-,o::--- /opt/public/rights/transfer_rights.txt
    fi

    # Journaux applicatifs (transferts, connexions, actions admin, événements) :
    # inscriptibles par les utilisateurs, lisibles par les administrateurs.
    chown root:root /var/log/monosphere
    chmod 750 /var/log/monosphere
    setfacl -m g:bastionadmin:r-x,g:bastionuser:--x,o::--- /var/log/monosphere
    normalize_user_log "${TRANSFER_LOG}"
    normalize_user_log "${CONNECTIONS_LOG}"
    normalize_user_log "${ADMIN_ACTIONS_LOG}"
    normalize_user_log "${EVENTS_LOG}"

    # Journal de sshd (-E) : écrit par sshd (root), lisible par les
    # administrateurs uniquement.
    if [[ ! -f ${SSHD_LOG} ]]; then
        touch "${SSHD_LOG}"
    fi
    chown root:bastionadmin "${SSHD_LOG}"
    chmod 640 "${SSHD_LOG}"
    setfacl -m g:bastionadmin:r--,m::r--,o::--- "${SSHD_LOG}" 2>/dev/null

    # Racine des enregistrements de sessions.
    if [[ ! -d ${SESSIONS_BASE_DIR} ]]; then
        mkdir -p "${SESSIONS_BASE_DIR}"
    fi
    chown root:bastionadmin "${SESSIONS_BASE_DIR}"
    chmod 751 "${SESSIONS_BASE_DIR}"
}

info_msg "Monosphere configure le répertoire public et les permissions ACL."
normalize_perms

# --- Création des utilisateurs -------------------------------------------------

info_msg "Création des utilisateurs en cours..."
if [[ ! -f ${USERS_FILE} ]]; then
    error_msg "Code 03 : Configuration utilisateur introuvable (${USERS_FILE}), veuillez vérifier votre configuration et vos points de montage.\nConsultez la documentation pour plus d'informations."
    exit 1
fi

userfile_lines=0
while IFS= read -r userinfo || [[ -n ${userinfo} ]]; do
    # Ignore les lignes vides et les commentaires.
    [[ -z ${userinfo} ]] && continue
    [[ ${userinfo} == \#* ]] && continue
    userfile_lines=$((userfile_lines + 1))

    IFS=';' read -r user is_bastion encrypted_password setkeys <<<"${userinfo}"

    # Validation du nom d'utilisateur (minuscules alphanumériques, - et _).
    if ! [[ ${user} =~ ^[a-z][a-z0-9_-]{0,31}$ ]]; then
        error_msg "Code 01 : Nom d'utilisateur invalide : \"${user}\". Il doit être en minuscules, alphanumérique, et commencer par une lettre."
        exit 1
    fi

    if ! [[ ${is_bastion} =~ ^[01]$ ]] || ! [[ ${setkeys} =~ ^[01]$ ]]; then
        error_msg "Code 01 : Statut utilisateur ou configuration de clés invalide pour \"${user}\" (attendu : 0 ou 1).\nConsultez la documentation pour plus d'informations."
        exit 1
    fi

    # shellcheck disable=SC2016  # littéral '$6$' voulu
    if [[ $(echo "${encrypted_password}" | cut -c1-3) != '$6$' ]] && [[ ${encrypted_password} != "0" ]]; then
        error_msg "Code 01 : Problème avec le mot de passe entré pour l'utilisateur \"${user}\".\nLe hash doit être au format SHA-512 crypt (préfixe \$6\$), ou valoir 0.\nConsultez la documentation pour plus d'informations."
        exit 1
    fi

    # Idempotence : ne pas rééchouer si l'utilisateur existe déjà (redémarrage du conteneur).
    if getent passwd "${user}" >/dev/null 2>&1; then
        info_msg "L'utilisateur \"${user}\" existe déjà, synchronisation de sa configuration."
    else
        adduser --disabled-password --gecos "" "${user}" --shell /bin/bash
    fi

    if [[ ${is_bastion} -eq 1 ]]; then
        usermod -aG bastionuser "${user}"
    elif [[ ${is_bastion} -eq 0 ]]; then
        usermod -aG bastionadmin "${user}"
        mkdir -p /home/"${user}"
        ln -sf /opt/public/scripts/server_menu.sh /home/"${user}"/server_menu.sh
    fi

    if [[ ${encrypted_password} != "0" ]]; then
        info_msg "Hash de mot de passe trouvé, configuration de ce dernier pour l'utilisateur \"${user}\"."
        if grep -q "^${user}:" /etc/shadow; then
            sed -i "s|^${user}:[^:]*|${user}:${encrypted_password}|g" /etc/shadow || error_msg "Code 04 : Problème avec la mise en place du mot de passe utilisateur.\nConsultez la documentation pour plus d'informations."
        else
            error_msg "Code 04 : L'utilisateur \"${user}\" est absent de /etc/shadow, impossible de poser le mot de passe."
        fi
    else
        info_msg "Mot de passe non configuré, ce dernier sera égal au nom de l'utilisateur, comme indiqué dans la documentation."
        echo "${user}:${user}" | chpasswd
    fi

    if [[ ${setkeys} -eq 1 ]]; then
        if [[ ! -d /root/scripts/users/"${user}" ]]; then
            info_msg "Attention : clés SSH activées pour \"${user}\" mais le dossier /root/scripts/users/${user} est absent ou n'est pas un dossier."
        else
            mkdir -p /home/"${user}"/.ssh
            chmod 700 /home/"${user}"/.ssh
            cp -r /root/scripts/users/"${user}"/. /home/"${user}"/.ssh/
            chown -R "${user}":"${user}" /home/"${user}"/.ssh
            chmod 600 /home/"${user}"/.ssh/*
        fi
    fi

    # Répertoire d'enregistrement des sessions de cet utilisateur :
    # l'utilisateur peut y écrire (wx) sans pouvoir lister son contenu,
    # les administrateurs (bastionadmin) peuvent lister et lire.
    install -d -m 750 -o root -g bastionadmin "${SESSIONS_BASE_DIR}/${user}"
    if command -v setfacl >/dev/null 2>&1; then
        setfacl -m "u:${user}:wx,g:bastionadmin:r-x,m::rwx,o::---" "${SESSIONS_BASE_DIR}/${user}"
        setfacl -m "d:u::rw-,d:g::---,d:g:bastionadmin:r--,d:m::rw-,d:o::---" "${SESSIONS_BASE_DIR}/${user}"
    fi

    # Avertissement si le mot de passe du compte admin par défaut n'a pas été changé.
    if [[ ${user} == "bastion" ]] && [[ ${encrypted_password} == ${DEFAULT_ADMIN_HASH_PREFIX}* ]] && [[ ${PASSWORD_AUTH} -eq 1 ]]; then
        error_msg "/!\\ SÉCURITÉ : le compte administrateur \"bastion\" utilise toujours le mot de passe par défaut \"bastion\" avec l'authentification par mot de passe activée.\n/!\\ Changez son mot de passe dans bastion_users.txt ou désactivez PASSWORD_AUTH avant toute exposition du bastion."
    fi
done <"${USERS_FILE}"

if [[ ${userfile_lines} -eq 0 ]]; then
    error_msg "Code 03 : Le fichier ${USERS_FILE} est vide, veuillez vérifier votre configuration.\nConsultez la documentation pour plus d'informations."
    exit 1
fi
good_msg "Création des utilisateurs terminée."

# --- Démarrage de SSHD ---------------------------------------------------------

# Génération des clés d'hôte du bastion si absentes (premier déploiement).
# Indispensable avant sshd -t, qui échoue sans clés configurées.
if [[ ! -f /etc/ssh/ssh_host_ed25519_key ]] && [[ ! -f /etc/ssh/ssh_host_rsa_key ]]; then
    info_msg "Génération des clés d'hôte SSH du bastion..."
    ssh-keygen -A
fi

info_msg "Démarrage du service SSHD de Monosphere."
if sshd -t; then
    # Démarrage direct de sshd (démon) : openrc n'est pas fiable comme
    # superviseur dans un conteneur dont le PID 1 est l'entrypoint.
    # -E capture les logs sshd (authentifications, échecs, empreintes de clés,
    # déconnexions — niveau VERBOSE configuré) dans un fichier du volume de
    # logs : sans syslog dans le conteneur, ils seraient sinon perdus.
    mkdir -p /run/sshd
    /usr/sbin/sshd -E "${SSHD_LOG}"
    sleep 1
    if pgrep sshd >/dev/null 2>&1; then
        info_msg "Configuration du service SSHD de Monosphere vérifiée et valide."
        info_msg "Monosphere a bien été configuré et démarré avec succès."
    else
        error_msg "Le processus sshd ne tourne pas après le démarrage. Consultez les journaux du conteneur."
        exit 1
    fi
else
    error_msg "Configuration du service SSHD de Monosphere invalide\n Veuillez vérifier la configuration et relancer le deploiement."
    exit 1
fi

# Miroir des événements vers la sortie du conteneur (docker logs) : un tail
# de fond relaie events.log (connexions, actions d'administration) sur le
# stdout du PID 1, où le driver de logs Docker peut le collecter. -F suit les
# rotations copytruncate. Process enfant du conteneur, il s'arrête avec lui.
info_msg "Monosphere relaie les événements de sécurité sur la sortie du conteneur."
tail -n 0 -F "${EVENTS_LOG}" 2>/dev/null &

# --- Boucle de supervision -----------------------------------------------------
# Le conteneur reste vivant tant que cette boucle tourne. Elle :
#   - re-applique les permissions toutes les 60 secondes (les fichiers ajoutés
#     à chaud par les administrateurs deviennent utilisables par les
#     utilisateurs sans redémarrage) ;
#   - applique la rotation des journaux au-delà de LOG_MAX_BYTES ;
#   - purge les enregistrements ttyrec plus vieux que SESSION_RETENTION_DAYS
#     (0 = conservation illimitée). Si sshd meurt, le HEALTHCHECK du conteneur
#     le signale.
# Rotation "copytruncate" d'un journal : copie en ".1" puis troncature de
# l'original pour que le process qui écrit (sshd, menus) garde son descripteur.
rotate_log() {
    local file="$1" size
    [[ -f ${file} ]] || return 0
    size=$(stat -c %s "${file}" 2>/dev/null || stat -f %z "${file}" 2>/dev/null || echo 0)
    if [[ ${size} -gt ${LOG_MAX_BYTES} ]]; then
        cp "${file}" "${file}.1" 2>/dev/null && : >"${file}" 2>/dev/null
    fi
}

purge_old_sessions() {
    [[ ${SESSION_RETENTION_DAYS} -gt 0 ]] || return 0
    find "${SESSIONS_BASE_DIR}" -type f -name "*.ttyrec" -mtime "+${SESSION_RETENTION_DAYS}" -delete 2>/dev/null || true
}

info_msg "Monosphere entre en supervision (permissions, rotation des logs, purge des sessions)."
while true; do
    sleep 60
    normalize_perms
    rotate_log "${TRANSFER_LOG}"
    rotate_log "${CONNECTIONS_LOG}"
    rotate_log "${ADMIN_ACTIONS_LOG}"
    rotate_log "${EVENTS_LOG}"
    rotate_log "${SSHD_LOG}"
    purge_old_sessions
done
