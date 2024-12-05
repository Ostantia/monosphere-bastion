#!/bin/bash

AUTHORIZED_SERVERS_PATH="opt/public/servers"
AUTHORIZED_SERVERS_FILE="/$AUTHORIZED_SERVERS_PATH/authorized_servers.txt"
CONNECTED_USER="$(whoami)"
USER_SERVERS=$(grep -w "$CONNECTED_USER" $AUTHORIZED_SERVERS_FILE)

if [ -z "$USER_SERVERS" ]; then
  echo "Vous n'avez pas l'autorisation de vous connecter à un serveur."
  exit 1
fi

function main_menu () {
  echo "Veuillez sélectionner un serveur auquel vous connecter :"

  counter=1
  declare -A server_map
  while read -r line; do
    ip=$(echo "$line" | cut -d ' ' -f 1)
    port=$(echo "$line" | cut -d ' ' -f 2)
    custom_name=$(echo "$line" | cut -d ' ' -f 3)
    server_user=$(echo "$line" | cut -d ' ' -f 4)
    server_authmethod=$(echo "$line" | cut -d ' ' -f 6)
    server_auth=$(echo "$line" | cut -d ' ' -f 7)
    server_map[$counter]="$ip $port $server_user $server_authmethod $server_auth"
    echo "$counter) $custom_name - $server_user $ip:$port"
    counter=$((counter + 1))
  done <<< "$USER_SERVERS"

  echo "$counter) Tapez 'quit' ou $counter pour vous déconnecter."

  read -r -p "Votre choix (1-$counter): " choice

  if [ "$choice" == "quit" ] || [ "$choice" == "$counter" ]; then
    echo "Déconnexion du bastion."
    exit 0
  elif [ -z "$choice" ] || [ -z "${server_map[$choice]}" ]; then
    echo "Sélection invalide."
  else
    local selected_server
    selected_server="${server_map[$choice]}"
    echo "Connexion à $( echo "$selected_server" | cut -d " " -f -3)..."
    if [ -z "$(echo "$selected_server" | cut -d ' ' -f 4)" ] && [ -f "$AUTHORIZED_SERVERS_PATH"/"$(echo "$selected_server" | cut -d ' ' -f 5)" ]; then
      ttyrec -z --"$(echo "$selected_server" | cut -d ' ' -f 1)"-"$(echo "$selected_server" | cut -d ' ' -f 3)"-- -k 300 --warn-before-kill 60 -- ssh -p "$(echo "$selected_server" | cut -d ' ' -f 2)" "$(echo "$selected_server" | cut -d ' ' -f 3)"@"$(echo "$selected_server" | cut -d ' ' -f 1)"
    elif [ "$(echo "$selected_server" | cut -d ' ' -f 4)" == "key" ]; then
      eval "$(ssh-agent)" > /dev/null
      trap 'kill $SSH_AGENT_PID' EXIT
      cat /"$AUTHORIZED_SERVERS_PATH"/"$(echo "$selected_server" | cut -d ' ' -f 5)" | ssh-add - > /dev/null
      ttyrec -z --"$(echo "$selected_server" | cut -d ' ' -f 1)"-"$(echo "$selected_server" | cut -d ' ' -f 3)"-- -k 300 --warn-before-kill 60 -- ssh -p "$(echo "$selected_server" | cut -d ' ' -f 2)" "$(echo "$selected_server" | cut -d ' ' -f 3)"@"$(echo "$selected_server" | cut -d ' ' -f 1)"
      ssh-add -D > /dev/null
    elif [ "$(echo "$selected_server" | cut -d ' ' -f 4)" == "password" ] && [ -f /"$AUTHORIZED_SERVERS_PATH"/"$(echo "$selected_server" | cut -d ' ' -f 5)" ]; then
      local ssh_password
      ssh_password=$(cat /"$AUTHORIZED_SERVERS_PATH"/"$(echo "$selected_server" | cut -d ' ' -f 5)")
      ttyrec -z --"$(echo "$selected_server" | cut -d ' ' -f 1)"-"$(echo "$selected_server" | cut -d ' ' -f 3)"-- -k 300 --warn-before-kill 60 -- sshpass -p "$ssh_password" ssh -p "$(echo "$selected_server" | cut -d ' ' -f 2)" "$(echo "$selected_server" | cut -d ' ' -f 3)"@"$(echo "$selected_server" | cut -d ' ' -f 1)"
      unset ssh_password
    else
      echo -e "Un problème de configuration a été détecté sur \nles options de connexion à l'hôte selectionné.\nVeuillez contacter votre administrateur."
    fi
  fi
}

while true; do
  main_menu
done
