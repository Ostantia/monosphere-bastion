FROM alpine:3.20.0 AS monosphere-builder
#~The open Monosphere Project~
#Autor : Siphonight :)


#Setting default settings, please change them at run
ARG MONOSPHERE_VERSION="3.4.10 Alpha"


#Defining build settings
WORKDIR /
USER root


#Updating and installing required dependencies
RUN apk add make=4.4.1-r2 git=2.45.3-r0 gcc=13.2.1_git20240309-r0 alpine-sdk=1.0-r1 && \
addgroup root abuild && \
mkdir -p /var/cache/distfiles && \
chmod a+w /var/cache/distfiles


#Installing OVH-ttyrec
RUN cd /root/ && \
git clone https://github.com/ovh/ovh-ttyrec.git && \
cd /root/ovh-ttyrec && \
./configure && \
make && \
make install


#Starting bastion configurations
#Configuring monosphere ssh banner
ADD monosphere_banner.txt /root/scripts/
RUN echo "Monosphere version is $MONOSPHERE_VERSION" >> /root/scripts/monosphere_banner.txt


#==============final container==============#
FROM alpine:3.20.0

#Setting default settings, please change them at run
ENV HOSTNAME="monosphere-bastion"
ENV PORT=22
ENV PASSWORD_AUTH=1
ENV KEY_AUTH=1


#Defining build settings
WORKDIR /
USER root


#Preparations
#Updating and installing required dependencies
RUN apk add openssh-server=9.7_p1-r4 openssh-client=9.7_p1-r4 openrc=0.54-r1 bash=5.2.26-r0 sshpass=1.10-r0 gawk=5.3.0-r1 && \
apk --no-cache add shadow=4.15.1-r0


#Ensuring that the SSH server will be able to run without issues on container launch
RUN rc-update add sshd && \
mkdir -p /run/openrc && \
touch /run/openrc/softlevel

#Copying from build and adding default configuration files
COPY --from=monosphere-builder /root/scripts/monosphere_banner.txt /root/scripts/monosphere_banner.txt
ADD entrypoint.sh /root/scripts/
ADD server_menu.sh /opt/public/scripts/
ADD admin_menu.sh /opt/public/scripts/
ADD authorized_servers.txt /opt/public/servers/
ADD admin_rights.txt /opt/public/rights/
ADD bastion_users.txt /root/scripts/users/
ADD sshd_config /etc/ssh/


#Copying TTYREC utility from build
COPY --from=monosphere-builder /usr/local/bin/ttyplay /usr/local/bin/ttyplay
COPY --from=monosphere-builder /usr/local/bin/ttyrec /usr/local/bin/ttyrec
COPY --from=monosphere-builder /usr/local/bin/ttytime /usr/local/bin/ttytime


#Activating scripts ;
RUN chmod 644 /etc/ssh/sshd_config && \
chown -R root:root /root/scripts && \
chmod 700 /root/scripts/*.sh


#Default port exposition
EXPOSE $PORT


#Issuing start entrypoint
CMD ["/bin/sh", "/root/scripts/entrypoint.sh"]
