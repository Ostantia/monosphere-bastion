#!/bin/bash
hostname "${HOSTNAME}"
echo "Monosphere anacron scheduler is starting..."
service anacron start
echo "Monosphere anacron scheduler is successfully started"

echo "Monosphere sshd service daemon is verifying its configuration..."
echo "Port ${PORT}" >> /etc/ssh/sshd_config
echo "#Last authentication configurations" >> /etc/ssh/sshd_config
if [ "${PASSWORD_AUTH}" -eq "1" ]; then
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
else
    echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
fi
if [ "${KEY_AUTH}" -eq "1" ]; then
    echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config
else
    echo "PubkeyAuthentication no" >> /etc/ssh/sshd_config
fi
sshd -t
echo "Monosphere sshd service daemon configuration verified"

echo "Monosphere rsyslog daemon is starting..."
service rsyslog start
echo "Monosphere rsyslog daemon is successfully started"

echo "Monosphere auditd daemon is starting..."
service auditd start
echo "Monosphere auditd daemon is successfully started"

echo "Monosphere sshd service daemon is starting..."
service ssh start
echo "Monosphere sshd service daemon is successfully started"

echo "Monosphere is enabling and executing custom scripts..."
chown -R root:root /opt/custom
chmod 700 /opt/custom/scripts/*.sh
bash /opt/custom/scripts/*.sh
echo "Monosphere custom scripts are successfully enabled"

echo "Monosphere is configuring public directory..."
chown -R root:root /opt/public
chmod -R 755 /opt/public
echo "Monosphere public directory successfully configured"

#User accounts creation step

if ! grep -q "bastionuser" /etc/group; then
    groupadd bastionuser
fi

if [ ! -f "/root/scripts/users/bastion_users.txt" ]; then
    echo "No userfile detected, creating default user. Please change the default password for security purposes..."
    adduser --disabled-password --gecos "" bastion --shell /bin/bash
    usermod -aG bastionuser bastion
    echo bastion:bastion | chpasswd
else
    echo "Monosphere is creating the bastion users..."
    userfile=$(cat /root/scripts/users/bastion_users.txt)
    for userinfo in $userfile; do
        user=$(echo "$userinfo" | cut -d ';' -f 1)
        is_bastion=$(echo "$userinfo" | cut -d ';' -f 2)
        password=$(echo "$userinfo" | cut -d ';' -f 3)
        setkeys=$(echo "$userinfo" | cut -d ';' -f 4)

        adduser --disabled-password --gecos "" "$user" --shell /bin/bash

        if [ "$is_bastion" -eq "1" ]; then
            usermod -aG bastionuser "$user"
        fi

        if [ "$password" -ne "0" ]; then
            echo "$user:$password" | chpasswd
        fi

        if [ "$setkeys" -eq "1" ]; then
            mkdir -p /home/"$user"/.ssh
            chmod 700 /home/"$user"/.ssh
            cp -r /root/scripts/users/"$user"/* /home/"$user"/.ssh/
            chown -R "$user":"$user" /home/"$user"/.ssh
            chmod 600 /home/"$user"/.ssh/*
        fi
    done
fi
echo "Monosphere user creation is finished"

echo "Monosphere bastion is successfully started"

# Keep the container running
tail -f /dev/null
echo "Monosphere bastion is successfully started"