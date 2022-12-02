FROM centos/systemd

ARG TABLEAU_SERVER_VERSION
ARG POSTGRES_VERSION

ENV LANG=en_US.UTF-8

COPY tableau-server-$TABLEAU_SERVER_VERSION.x86_64.rpm /tmp

RUN set -x \
    && yum install epel-release -y \
    && yum update -y \
    && yum install -y \
        cronie \
        iproute \
        sudo \
        vim \
        libcap-devel \
        wget \
        tar \
        unzip \
        curl \
        which \
    && yum --enablerepo=epel-testing install -y \
        moreutils \
        monit \
    && adduser tsm \
    && mkdir -p /opt/tableau \
    && (echo tsm:tsm | chpasswd) \
    && (echo 'tsm ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/tsm) \
    && groupadd tableau \
    && groupmod -g 3001 tableau \
    && useradd -u 3001 -s /bin/false -d /bin/null -c "tableau chroot user" -g tableau tableau \
    && cd /tmp \
    && wget https://downloads.tableau.com/tssoftware/tableau-server-$TABLEAU_SERVER_VERSION.x86_64.rpm -O /tmp/tableau-server-$TABLEAU_SERVER_VERSION.x86_64.rpm \
    && wget https://downloads.tableau.com/drivers/linux/yum/tableau-driver/tableau-postgresql-odbc-$POSTGRES_VERSION.x86_64.rpm -O /tmp/tableau-postgresql-odbc-$POSTGRES_VERSION.x86_64.rpm \
    && yum install -y /tmp/tableau-server-$TABLEAU_SERVER_VERSION.x86_64.rpm \
                      /tmp/tableau-postgresql-odbc-$POSTGRES_VERSION.x86_64.rpm \
    && rm -rf /var/tmp/yum-*
    #&& rm -rf /tmp/*
COPY reg.json /reg.json
COPY config.json /config.json

EXPOSE 80 443 8850
VOLUME [ "/sys/fs/cgroup" "/var/opt/tableau" "/run" "/tmp"]
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/sbin/init"]
