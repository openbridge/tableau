#!/usr/bin/env bash

set -e

export TABLEAU_SERVER_VERSION=2019-4-0
export POSTGRES_VERSION=09.06.0500-1
export REDSHIFT_VERSION=1.4.8.1000
export PRODUCT_KEY=""

    yum install epel-release -y
    yum update -y
    yum install -y \
        cronie \
        iproute \
        sudo \
        vim \
        libcap-devel \
        wget \
        tar \
        unzip \
        curl \
        which
    yum --enablerepo=epel-testing install -y \
        moreutils \
        bash-completion \
        monit

    PUBLICIPV4="$(curl http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null)"
    LOCALIPV4="$(curl http://169.254.169.254/latest/meta-data/local-ipv4 2>/dev/null)"
    AWS_IAMROLE="$(curl http://169.254.169.254/latest/meta-data/iam/security-credentials/)"
    AWS_SECRET_ACCESS_KEY="$(curl http://169.254.169.254/latest/meta-data/iam/security-credentials/${AWS_IAMROLE} | grep SecretAccessKey | cut -d':' -f2 | sed 's/[^0-9A-Za-z/+=]*//g')"
    AWS_ACCESS_KEY_ID="$(curl http://169.254.169.254/latest/meta-data/iam/security-credentials/${AWS_IAMROLE} | grep AccessKeyId | cut -d':' -f2 | sed 's/[^0-9A-Z]*//g')"
    export AWS_SECRET_ACCESS_KEY
    export AWS_ACCESS_KEY_ID
    export AWS_IAMROLE
    export PUBLICIPV4
    export LOCALIPV4

    id -u tsm &>/dev/null || adduser tsm
    mkdir -p /opt/tableau
    (echo tsm:tsm | chpasswd)
    (echo 'tsm ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/tsm)
    id -g tableau &>/dev/null || groupadd tableau
    groupmod -g 3001 tableau
    id -u tableau &>/dev/null || useradd -u 3001 -s /bin/false -d /bin/null -c "tableau chroot user" -g tableau tableau


    cd /tmp
    wget https://downloads.tableau.com/tssoftware/tableau-server-${TABLEAU_SERVER_VERSION}.x86_64.rpm -O "/tmp/tableau-server-${TABLEAU_SERVER_VERSION}.x86_64.rpm"
    wget https://redshift-downloads.s3.amazonaws.com/drivers/odbc/${REDSHIFT_VERSION}/AmazonRedshiftODBC-64-bit-${REDSHIFT_VERSION}-1.x86_64.rpm -O "/tmp/AmazonRedshiftODBC-64-bit-${REDSHIFT_VERSION}-1.x86_64.rpm"
    wget https://downloads.tableau.com/drivers/linux/yum/tableau-driver/tableau-postgresql-odbc-${POSTGRES_VERSION}.x86_64.rpm -O "/tmp/tableau-postgresql-odbc-${POSTGRES_VERSION}.x86_64.rpm"

    yum --nogpgcheck install -y /tmp/tableau-server-${TABLEAU_SERVER_VERSION}.x86_64.rpm \
                                /tmp/tableau-postgresql-odbc-${POSTGRES_VERSION}.x86_64.rpm \
                                /tmp/AmazonRedshiftODBC-64-bit-${REDSHIFT_VERSION}-1.x86_64.rpm

   if [ -f /opt/tableau/.installed ]; then
      echo "OK: Tableau Server already installed"
   else
      mkdir -p /var/opt/tableau/tableau_server
      chown tableau:tableau /var/opt/tableau/tableau_server
      {
         echo '{'
         echo ' "city" : "Salem",'
         echo ' "state" : "NH",'
         echo ' "zip" : "03079",'
         echo ' "country" : "USA",'
         echo ' "first_name" : "Jason",'
         echo ' "last_name" : "Smith",'
         echo ' "industry" : "Software",'
         echo ' "eula" : "yes",'
         echo ' "title" : "Software Applications Engineer",'
         echo ' "phone" : "5556875309",'
         echo ' "company" : "Example",'
         echo ' "department" : "Engineering",'
         echo ' "email" : "jsmith@example.com"'
         echo '}'
       } | tee ./reg.json

       {
         echo '{'
         echo '    "configEntities": {'
         echo '       "gatewaySettings": {'
         echo '          "_type": "gatewaySettingsType",'
         echo '          "port": 80,'
         echo '          "firewallOpeningEnabled": true,'
         echo '          "sslRedirectEnabled": true,'
         echo '          "publicHost": "localhost",'
         echo '          "publicPort": 80'
         echo '       },'
         echo '       "identityStore": {'
         echo '          "_type": "identityStoreType",'
         echo '          "type": "local"'
         echo '       }'
         echo '     },'
         echo '      "configKeys": {'
         echo '         "gateway.timeout": "900"'
         echo '      }'
         echo '}'
       } | tee ./config.json

       {
         echo '[Amazon Redshift (x64)]'
         echo 'Description=Amazon Redshift ODBC Driver(64-bit)'
         echo 'Driver=/opt/amazon/redshiftodbc/lib/64/libamazonredshiftodbc64.so'
       } | tee -a /etc/odbcinst.ini

       # These do not seem to algin with the docs...
       #sed -i 's|DriverManagerEncoding=UTF-32|'DriverManagerEncoding=UTF-16'|g' /opt/amazon/redshiftodbc/lib/64/amazon.redshiftodbc.ini
       #sed -i 's|LogPath=[LogPath]|'LogPath=/tmp'|g' /opt/amazon/redshiftodbc/lib/64/amazon.redshiftodbc.ini
       #sed -i 's|ODBCInstLib=libiodbcinst.so|'#ODBCInstLib=libiodbcinst.so'|g' /opt/amazon/redshiftodbc/lib/64/amazon.redshiftodbc.ini
       #sed -i 's|#ODBCInstLib=libodbcinst.so|'ODBCInstLib=libodbcinst.so'|g' /opt/amazon/redshiftodbc/lib/64/amazon.redshiftodbc.ini

       run_tsm() {
         TSMARGS="$@"
         su -c "/opt/tableau/tableau_server/packages/customer-bin.*/tsm ${TSMARGS}"
       }

      # Accept the EULA
      su -c "/opt/tableau/tableau_server/packages/scripts.*/initialize-tsm -f --accepteula -a tsm"

      run_tsm login --username tsm --password tsm

      if [[ -z ${PRODUCT_KEY} ]]; then
          echo "INFO: No product key is present. Using trial licence..."
          run_tsm licenses activate -t
        else
          echo "INFO: A product key has been set. Attempting to use key to register license..."
          run_tsm licenses activate --license-key "${PRODUCT_KEY}"
          # Did the process work successfully?
          if [[ $? = 0 ]]; then
             echo "ERROR: There was an error with the supplied product key"
             exit 1
          fi
      fi

      run_tsm register --file ./reg.json
      run_tsm settings import -f ./config.json
      run_tsm pending-changes apply
      run_tsm initialize --start-server --request-timeout 2300

      sleep 10

      # Check to see if the server is running
      read TS_STATUS <<< $(su -c "/opt/tableau/tableau_server/packages/customer-bin.*/tsm status" | awk '/Status:/ { print $2 }')
      if [[ "${TS_STATUS}" = "RUNNING" ]] || [[ "${TS_STATUS}" == "DEGRADED" ]]; then
          echo "Server status is ${TS_STATUS}. Continue..."
          su -c "/opt/tableau/tableau_server/packages/customer-bin.*/tabcmd initialuser --server 127.0.0.1:80 --username admin --password admin"
          #su -c "/opt/tableau/tableau_server/packages/customer-bin.*/tsm maintenance metadata-services enable"
          su -c "touch /opt/tableau/.installed"
        else
          echo "Server status is ${TS_STATUS}. Canceling."
          exit 1
      fi

    fi

exit 0
