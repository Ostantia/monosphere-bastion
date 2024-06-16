FROM ubuntu:22.04
#~The open Monosphere Project~
#Version : 1.0
#Autor : Siphonight :)

#Defining variables and build settings
WORKDIR /
USER root
#Setting default settings, please change them at run
ENV HOSTNAME="monosphere-bastion"
ENV PORT=22
ENV PASSWORD_AUTH=1
ENV KEY_AUTH=1
ARG MONOSPHERE_VERSION="0.5.1 Alpha"


#Preparations
#Updating and installing required dependencies ;
#reation and configuration of the Monosphere scripts directory ;
RUN apt update -y && apt upgrade -y && \
apt install -y ssh gawk anacron git make gcc sudo && \
mkdir /root/scripts && \
mkdir /root/scripts/users


#Starting bastion configurations
#Configuring Failsafe SSH relauncher
ADD ssh-launcher.sh /root/scripts/
#Configuring monosphere ssh banner
ADD monosphere_banner.txt /root/scripts/
RUN echo "Monosphere version is $MONOSPHERE_VERSION" >> /root/scripts/monosphere_banner.txt
#Adding the entrypoint file to the configuration
ADD entrypoint.sh /root/scripts/
#Adding the server menu script files
#Preparing the custom scripts directory
#RUN mkdir -p /opt/custom/scripts
ADD authorized_servers.txt /opt/public/servers/
ADD server_menu.sh /opt/public/scripts/
#Adding the server custom ssh configuration file
ADD sshd_config /root/scripts/


#Configuring anacrontab scheduler ;
#Changing SSHD moduli ;
#Backuping the SSHD config file ;
#Adding the config file of SSHD ;
#Activating scripts ;
RUN echo "#---Bastion configurations ! CHANGE AT YOUR OWN RISK !---" >> /etc/anacrontab && \
echo "5       5       sshrelauncher       bash /root/scripts/ssh-launcher.sh" >> /etc/anacrontab && \
awk '$5 >= 3071' /etc/ssh/moduli > /etc/ssh/moduli.tmp && \
mv /etc/ssh/moduli.tmp /etc/ssh/moduli && \
cp -r /etc/ssh/sshd_config /etc/ssh/sshd_config.backup && \
rm -rf /etc/ssh/sshd_config && \
cp -r /root/scripts/sshd_config /etc/ssh/ && \
chmod 644 /etc/ssh/sshd_config && \
chown -R root:root /root/scripts && \
chmod 700 /root/scripts/*.sh


#Installing OVH-ttyrec
RUN cd /root/ && \
git clone https://github.com/ovh/ovh-ttyrec.git && \
cd /root/ovh-ttyrec && \
./configure && make && \
make install


#Disabling default Ubuntu MOTD
RUN rm -rf /etc/update-motd.d/*


#Port exposition
EXPOSE $PORT


#Issuing start entrypoint
CMD ["/bin/bash", "/root/scripts/entrypoint.sh"]