# Tableau Unattended Installer
The installer script handles host setup of packages, directories, permissions and other variables required to run Tableau Server. This includes running a collection of Tableau Services Manager (`tsm`) and the Tableau command-line utility (`tabcmd`).

In addition to the host, the installer also will install, configure, and start Tableau Server. By default the installer activates a trial license. A valid product key can be set in the script or you can simply activate the product within the server UI.

Note: This is intended for a standalone, single node deployment.

## Before You Begin
Before you install make sure you have a Linux on a computer (or an AWS instance type) that meets the operating system requirements and the minimum hardware requirements for Tableau Server.

### Hardware
Review the minimum hardware recommendations. The recommendations represent the minimum hardware configuration you should use for a production installation of Tableau Server.

*At minimum, a 64-bit Tableau Server requires a 2-core CPU (the equivalent of 4 AWS vCPUs) and 8 GB RAM. However, a total of 8 CPU cores (16 AWS vCPUs) and 64GB RAM are strongly recommended for a single production Amazon EC2 instance.*

For development purposes, we have found that 8 AWS vCPUs and 64GB RAM sufficient. We have tested on a `t3.2xlarge` without incident.

Tableau states that the following are recommended instance types:

* `c5.4xlarge`
* `m5.4xlarge`
* `r5.4xlarge`


For more information, check out the docs: https://help.tableau.com/current/server-linux/en-us/server_hardware_min.htm

Tableau suggest you use two volumes: a 30-50 GiB volume for the operating system 100 GiB or larger volume for Tableau Server. For development we typically attach a 75GB EBS volume.

### Operating System
The host OS should be CentOS 7.3 or higher (not 8.x). While comparable to CentOS, there were difficulties getting the automated installer to work out-of-the-box Amazon Linux 2.

For more information on different official AWS AMI options, check out the docs: https://wiki.centos.org/Cloud/AWS


## Versions
The install process will grab the `RPM` installer for Tableau Server and the PostgreSQL driver. The PostgreSQL driver is installed because it is required when using the built-in administrative views.

The versions for each are set with variables:

```bash
export TABLEAU_SERVER_VERSION=2019-3-0
export POSTGRES_VERSION=09.06.0500-1
```
The installer will connect to Tableau, pull the files locally and then install:
```bash
wget https://downloads.tableau.com/tssoftware/tableau-server-$TABLEAU_SERVER_VERSION.x86_64.rpm -O /tmp/tableau-server-$TABLEAU_SERVER_VERSION.x86_64.rpm
wget https://downloads.tableau.com/drivers/linux/yum/tableau-driver/tableau-postgresql-odbc-$POSTGRES_VERSION.x86_64.rpm -O /tmp/tableau-postgresql-odbc-$POSTGRES_VERSION.x86_64.rpm
yum install -y /tmp/tableau-server $TABLEAU_SERVER_VERSION.x86_64.rpm \
               /tmp/tableau-postgresql-odbc-$POSTGRES_VERSION.x86_64.rpm
```
The Tableau Server installer is large, over 1.5 GB. Depending on the network connection, this can take awhile to complete.

### Database (or Data Lake) Drivers
In addition to the install packages and drivers, you need to install the driver(s) that align with a downstream data warehouse or data lake. In this case, it would be pre-installing the ODBC driver for Redshift. This is done by setting the Amazon provided version for the `REDSHIFT_VERSION` variable.

```bash
export REDSHIFT_VERSION=1.4.7.1000
```

The Redshift driver docs are here: https://docs.aws.amazon.com/redshift/latest/mgmt/install-odbc-driver-linux.html

## AWS Build
```bash
aws ec2 run-instances --image-id ami-abcd1234 --count 1 --instance-type mX.medium \
--key-name my-key-pair --subnet-id subnet-abcd1234 --security-group-ids sg-abcd1234 \
--user-data file://install.sh
```

## Registration
Edit the `reg.json` file provides the information needed to register Tableau Server.
```json
{
  "city" : "Salem",
  "state" : "NH",
  "zip" : "03079",
  "country" : "USA",
  "first_name" : "Jason",
  "last_name" : "Smith",
  "industry" : "Software",
  "eula" : "yes",
  "title" : "Software Applications Engineer",
  "phone" : "5556875309",
  "company" : "Example",
  "department" : "Engineering",
  "email" : "jsmith@example.com"
}
```
For more information, see Activate and Register Tableau Server here:
* https://help.tableau.com/current/server/en-us/activate.htm

## Configuration
This is a basic example of a configuration file for initializing Tableau Server.

```json
{
   "configEntities": {
      "gatewaySettings": {
         "_type": "gatewaySettingsType",
         "port": 80,
         "firewallOpeningEnabled": true,
         "sslRedirectEnabled": true,
         "publicHost": "localhost",
         "publicPort": 80
      },
      "identityStore": {
         "_type": "identityStoreType",
         "type": "local"
      }
    },
     "configKeys": {
        "gateway.timeout": "900"
     }
}
```
Remember to apply any changes after you set the configuration files, run `tsm pending-changes apply` to apply the changes from  the .json file config.

For a full compliment of configuration options, see these links:

* https://help.tableau.com/current/server-linux/en-gb/config_file_example.htm
* https://help.tableau.com/current/server-linux/en-gb/cli_configuration-set_tsm.htm

## Setting Tableau Host Information
There have been reports that if the Host information changes between starts, which can happen on AWS without EIP, you may need to reset the hostname. According to Tableau docs, you would reset this information:
```bash
tsm configuration set -k gateway.public.host -v "ec2-XX-XXX-XX-XX.compute-1.amazonaws.com" && tsm pending-changes apply
```

## Tableau Data Catalog

It is suggested that you enable the `Tableau Catalog`. Tableau says:

*Tableau Catalog discovers and indexes all of the content on your Tableau Online site or Tableau Server, including workbooks, data sources, sheets, and flows. Indexing is used to gather information about the content, or metadata, about the schema and lineage of the content. Then from the metadata, Catalog identifies all of the databases, files, and tables used by the content on your Tableau Online site or Tableau Server.*


```bash
sudo /opt/tableau/tableau_server/packages/customer-bin.*/tsm maintenance metadata-services enable
```

More info on the Tableau Data catalog is here: https://help.tableau.com/current/server/en-us/dm_catalog_overview.htm


## Data Cache

Views published to Tableau Server can have a live connection to a database. This data gets stored in a cache as users view reports. Subsequent views will pull the data the cache, if it is available. By default, Tableau Server will cache and reuse data for as long as possible. To change the default behavior run this command: `tsm data-access caching set -r <value>` where `<value>` is one of these options:

* empty string (`""`). This is the default value and indicates that Tableau Server should configure cache and always use cached data when available:  `tsm data-access caching set -r ""`
* specifies the maximum number of minutes data should be cached: `tsm data-access caching set -r "600"`
* `always` or `0` (zero). These values indicates that Tableau Server should always get the latest data and that the cache should be refreshed each time a page is reloaded: `tsm data-access caching set -r "0"` or `tsm data-access caching set -r "always"`

Once you have set your data cache value, do not forget to apply the changes:
```bash
tsm pending-changes apply
```

## Docker build
This is currently experimental. While the process will build, it will fail during a `docker run` command.
```bash
docker build --build-arg "TABLEAU_SERVER_VERSION=2019-3-0" --build-arg "POSTGRES_VERSION=09.06.0500-1"  -t tableau .
```
Per Tableau documents, you should mount host locations for the container. This example shows the various `-v` mounts:
```bash
docker run -v /sys/fs/cgroup:/sys/fs/cgroup -v /var/opt/tableau:/var/opt/tableau -v /run:/run -it tableau bash
systemctl status
```

## Removing Tableau Server
In the event you need to wipe the server from a server, you should use the `tableau-
server-obliterate` script provided by Tableau. You can find it in `/opt/tableau/tableau_server/packages/scripts.<version>/`

When ready, you can run the script like this:

```bash
sudo bash -c "/opt/tableau/tableau_server/packages/scripts.20194.19.1105.1444/tableau-
server-obliterate -y -y -y -l"
```

This will wipe **everything**, so take this action with care.

## TODO
* Install Redshift drivers as part of the install
