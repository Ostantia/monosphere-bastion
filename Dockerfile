# Builds limités à linux/amd64 : les architectures cibles du bastion sont amd64.
# Ce choix force la plateforme de build pour toute personne construisant l'image.
FROM --platform=linux/amd64 alpine:3.20.0 AS monosphere-builder
#~The open Monosphere Project~
#Autor : Siphonight :)


#Setting default settings, please change them at run
ARG MONOSPHERE_VERSION="3.7.1 Alpha"
#Version d'ovh-ttyrec épinglée pour des builds reproductibles
ARG TTYREC_VERSION="v1.2.0.0"


#Defining build settings
WORKDIR /
USER root


#Updating and installing required dependencies
RUN apk add make=4.4.1-r2 git=2.45.4-r0 gcc=13.2.1_git20240309-r1 alpine-sdk=1.0-r1 && \
addgroup root abuild && \
mkdir -p /var/cache/distfiles && \
chmod a+w /var/cache/distfiles


#Installing OVH-ttyrec (version épinglée via TTYREC_VERSION)
RUN cd /root/ && \
git clone --depth 1 --branch ${TTYREC_VERSION} https://github.com/ovh/ovh-ttyrec.git && \
cd /root/ovh-ttyrec && \
./configure && \
make && \
make install


#Starting bastion configurations
#Configuring monosphere ssh banner
COPY monosphere_banner.txt /root/scripts/
RUN echo "Monosphere version is $MONOSPHERE_VERSION" >> /root/scripts/monosphere_banner.txt


#==============final container==============#
# --platform=linux/amd64 : voir le commentaire du builder ci-dessus.
FROM --platform=linux/amd64 alpine:3.20.0

#Setting default settings, please change them at run
#PASSWORD_AUTH=0 par défaut depuis la 3.6.0 : préférez l'authentification par clés SSH.
ENV HOSTNAME="monosphere-bastion"
ENV PORT=22
ENV PASSWORD_AUTH=0
ENV KEY_AUTH=1
# Rétention des enregistrements de sessions ttyrec, en jours. 0 = conservation illimitée.
ENV SESSION_RETENTION_DAYS=0


#Defining build settings
WORKDIR /
USER root


#Preparations
#Updating and installing required dependencies
#acl fournit setfacl, utilisé par l'entrypoint pour les permissions fines.
RUN apk add openssh-server=9.7_p1-r5 openssh-client=9.7_p1-r5 openrc=0.54-r1 bash=5.2.26-r0 gawk=5.3.0-r1 acl=2.3.2-r0 && \
apk --no-cache add shadow=4.15.1-r0


#Ensuring that the SSH server will be able to run without issues on container launch
RUN rc-update add sshd && \
mkdir -p /run/openrc && \
touch /run/openrc/softlevel


#Copying from build and adding default configuration files
COPY --from=monosphere-builder /root/scripts/monosphere_banner.txt /root/scripts/monosphere_banner.txt
COPY entrypoint.sh /root/scripts/
COPY server_menu.sh /opt/public/scripts/
COPY admin_menu.sh /opt/public/scripts/
COPY authorized_servers.txt /opt/public/servers/
COPY admin_rights.txt /opt/public/rights/
COPY transfer_rights.txt /opt/public/rights/
COPY bastion_users.txt /root/scripts/users/
COPY sshd_config /etc/ssh/


#Copying TTYREC utility from build
COPY --from=monosphere-builder /usr/local/bin/ttyplay /usr/local/bin/ttyplay
COPY --from=monosphere-builder /usr/local/bin/ttyrec /usr/local/bin/ttyrec
COPY --from=monosphere-builder /usr/local/bin/ttytime /usr/local/bin/ttytime


#Creating runtime directories (logs de transfert, enregistrements de sessions, scripts personnalisés)
RUN mkdir -p /var/log/monosphere/sessions /opt/custom/scripts && \
touch /var/log/monosphere/transfers.log

#Durcissement filesystem :
#  - retrait des bits SUID des utilitaires du paquet shadow (passwd, chsh,
#    chage, gpasswd...) : inutiles ici (pas de shell utilisateur) et surface
#    d'élévation de privilèges ;
#  - /root/scripts (hashs de mots de passe, clés) accessible par root seul.
RUN find / -xdev -type f -perm -4000 -exec chmod u-s {} \; 2>/dev/null; \
    find / -xdev -type f -perm -2000 -exec chmod g-s {} \; 2>/dev/null; \
    chmod 700 /root/scripts

#Activating scripts ;
RUN chmod 644 /etc/ssh/sshd_config && \
    chown -R root:root /root/scripts && \
    chmod 700 /root/scripts/*.sh


#Default port exposition
EXPOSE $PORT


#Vérifie que sshd tourne réellement ; permet à Docker/Podman de redémarrer
#un conteneur dont le service SSH serait mort. (pgrep sans -x : sshd réécrit
#son titre de processus en "sshd: /usr/sbin/sshd [listener] ...")
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD pgrep sshd >/dev/null || exit 1


#Issuing start entrypoint (bash : le script utilise des spécificités bash)
CMD ["/bin/bash", "/root/scripts/entrypoint.sh"]
