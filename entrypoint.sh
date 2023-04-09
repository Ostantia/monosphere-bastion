hostname ${HOSTNAME}
echo "Monosphere anacron scheduler is starting..."
service anacron start
echo "Monosphere anacron scheduler is successfully started"

echo "Monosphere sshd service daemon is verifying its configuration..."
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

echo "Monosphere is enabling custom scripts..."
chown -R root:root /opt/custom
chmod 700 /opt/custom/scripts/*.sh
bash /opt/custom/scripts/*.sh
echo "Monosphere custom scripts are successfully enabled"

echo "Monosphere is configuring public directory..."
chown -R root:root /opt/public
chmod -R 755 /opt/public
echo "Monosphere public directory successfully configured"

echo "Monosphere is creating the bastion user, I hope you changed the default user info..."
adduser --disabled-password --gecos "" ${BASTIONUSER} --shell /bin/bash #/usr/sbin/nologin
echo "${BASTIONUSER}:${BASTIONPASS}" | chpasswd
mkdir /home/${BASTIONUSER}/.ssh
chown ${BASTIONUSER}:${BASTIONUSER} /home/${BASTIONUSER}/.ssh
echo "Monosphere have created the bastion user"

echo "Monosphere bastion is successfully started"

# Keep the container running
tail -f /dev/null
