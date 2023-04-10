#!/bin/bash

AUTHORIZED_SERVERS_FILE="/opt/public/servers/authorized_servers.txt"
USER_SERVERS=$(grep -w "$(whoami)" $AUTHORIZED_SERVERS_FILE)

if [ -z "$USER_SERVERS" ]; then
  echo "Vous n'avez pas l'autorisation de vous connecter à un serveur."
  exit 1
fi

echo "Veuillez sélectionner un serveur auquel vous connecter :"

counter=1
declare -A server_map
while read -r line; do
  ip=$(echo "$line" | cut -d ' ' -f 1)
  port=$(echo "$line" | cut -d ' ' -f 2)
  custom_name=$(echo "$line" | cut -d ' ' -f 3)
  server_map[$counter]="$ip $port"
  echo "$counter) $custom_name - $ip:$port"
  counter=$((counter + 1))
done <<< "$USER_SERVERS"

read -r -p "Votre choix (1-${#server_map[@]}): " choice

if [ -z "${server_map[$choice]}" ]; then
  echo "Sélection invalide."
  exit 1
fi

selected_server="${server_map[$choice]}"
echo "Connexion à $selected_server..."
ssh -p "$(echo $selected_server | cut -d ' ' -f 2)" "$(echo $selected_server | cut -d ' ' -f 1)"
