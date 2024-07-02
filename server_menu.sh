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
    server_authkey=$(echo "$line" | cut -d ' ' -f 6)
    server_map[$counter]="$ip $port $server_user $server_authkey"
    echo "$counter) $custom_name - $server_user $ip:$port"
    counter=$((counter + 1))
  done <<< "$USER_SERVERS"

  echo "$counter) Tapez 'quit' pour vous déconnecter."

  read -r -p "Votre choix (1-$counter): " choice

  if [ "$choice" == "quit" ]; then
    echo "Déconnexion du bastion."
    exit 0
  elif [ -z "$choice" ] || [ -z "${server_map[$choice]}" ]; then
    echo "Sélection invalide."
  else
    selected_server="${server_map[$choice]}"
    echo "Connexion à $selected_server..."
    if [ -z "$(echo "$selected_server" | cut -d ' ' -f 4)" ]; then
      ttyrec -z --"$(echo "$selected_server" | cut -d ' ' -f 1)"-"$(echo "$selected_server" | cut -d ' ' -f 3)"-- -k 300 --warn-before-kill 60 -- ssh -p "$(echo "$selected_server" | cut -d ' ' -f 2)" "$(echo "$selected_server" | cut -d ' ' -f 3)"@"$(echo "$selected_server" | cut -d ' ' -f 1)"
    else
      cp /"$AUTHORIZED_SERVERS_PATH"/"$(echo "$selected_server" | cut -d ' ' -f 4)" /home/"$CONNECTED_USER"/"$(echo "$selected_server" | cut -d ' ' -f 4)"
      chown "$CONNECTED_USER":"$CONNECTED_USER" /home/"$CONNECTED_USER"/"$(echo "$selected_server" | cut -d ' ' -f 4)"
      chmod 600 /home/"$CONNECTED_USER"/"$(echo "$selected_server" | cut -d ' ' -f 4)"
      ttyrec -z --"$(echo "$selected_server" | cut -d ' ' -f 1)"-"$(echo "$selected_server" | cut -d ' ' -f 3)"-- -k 300 --warn-before-kill 60 -- ssh -p "$(echo "$selected_server" | cut -d ' ' -f 2)" -i /home/"$CONNECTED_USER"/"$(echo "$selected_server" | cut -d ' ' -f 4)" "$(echo "$selected_server" | cut -d ' ' -f 3)"@"$(echo "$selected_server" | cut -d ' ' -f 1)"
      rm -rf /home/"${CONNECTED_USER:?}"/"$(echo "$selected_server" | cut -d ' ' -f 4)"
    fi
  fi
}

while true; do
  main_menu
done