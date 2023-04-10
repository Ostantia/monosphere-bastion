FROM ubuntu:20.04
#~The open Monosphere Project~
#Version : 1.0
#Autor : Siphonight :)

#Defining variables and build settings
WORKDIR /
USER root
#Setting default settings, please change them at run
ENV BASTIONUSER="bastion"
ENV BASTIONPASS="bastion"
ENV HOSTNAME="monosphere-bastion"
ENV PORT=22
ARG MONOSPHERE_VERSION="0.4.6 Alpha"

#Preparations
#Updating 
RUN apt update -y && apt upgrade -y
#Installing required dependencies
RUN apt install -y ssh gawk anacron auditd audispd-plugins rsyslog
#Creation and configuration of the Monosphere scripts directory
RUN mkdir /root/scripts


#Starting bastion configurations
#Configuring Failsafe SSH relauncher
ADD ssh-launcher.sh /root/scripts/
#Configuring monosphere ssh banner
ADD monosphere_banner.txt /root/scripts/
RUN echo "Monosphere version is $MONOSPHERE_VERSION" >> /root/scripts/monosphere_banner.txt
#Adding the entrypoint file to the configuration
ADD entrypoint.sh /root/scripts/
#Adding the aditd configuration and rules files
ADD auditd.conf /etc/audit/auditd.conf
ADD ssh-monitor.rules /etc/audit/rules.d/ssh-monitor.rules
#Adding the server menu script files
#Preparing the custom scripts directory
RUN mkdir -p /opt/custom/scripts
ADD authorized_servers.txt /opt/public/servers/
ADD server_menu.sh /opt/public/scripts/
#Adding the server custom ssh configuration file
ADD sshd_config /root/scripts/

#Configuring anacrontab scheduler
RUN echo "#---Bastion configurations ! CHANGE AT YOUR OWN RISK !---" >> /etc/anacrontab
RUN echo "5       5       sshrelauncher       bash /root/scripts/ssh-launcher.sh" >> /etc/anacrontab

#Configuring SSHD daemon bastion
#Changing SSHD moduli
RUN awk '$5 >= 3071' /etc/ssh/moduli > /etc/ssh/moduli.tmp && mv /etc/ssh/moduli.tmp /etc/ssh/moduli
#Backuping the SSHD config file
RUN cp -r /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
#Adding the config file of SSHD
RUN rm -rf /etc/ssh/sshd_config
RUN cp -r /root/scripts/sshd_config /etc/ssh/
RUN chmod 644 /etc/ssh/sshd_config

#Activating scripts
RUN chown -R root:root /root/scripts
RUN chmod 700 /root/scripts/*.sh

#Port exposition
EXPOSE $PORT


#Issuing start entrypoint
CMD ["/bin/bash", "/root/scripts/entrypoint.sh"]
