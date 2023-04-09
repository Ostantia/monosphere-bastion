#!/bin/bash

# Vérifier si le service SSH est en cours d'exécution
ssh_pid=$(pgrep sshd)

if [ ! -z "$ssh_pid" ]; then
    echo "Le service SSH est en cours d'exécution."
else
    echo "Le service SSH n'est pas en cours d'exécution. Tentative de démarrage..."
    sudo service ssh start

    # Vérifier à nouveau si SSH est en cours d'exécution
    ssh_pid=$(pgrep sshd)
    if [ ! -z "$ssh_pid" ]; then
        echo "Le service SSH a été démarré avec succès."
    else
        echo "Échec du démarrage du service SSH. Veuillez vérifier les logs pour plus de détails."
    fi
fi

