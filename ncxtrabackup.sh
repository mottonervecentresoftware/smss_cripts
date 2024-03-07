#!/bin/bash
# ncxtrabackup.sh  Install and configure Percona backup tool
# Richard Howlett
# 03/11/22

VER=1.20    # will change to 1.21 when released
PROG=${0##*/}

# misc stuff
ECHO="echo -e"

# Define colour escape sequences
RED='\e[31m'
GRN='\e[32m'
YEL='\e[33m'
LGN='\e[92m'
DGY='\e[90m'
END='\e[0m'

BOLD='\e[1m'
FAINT='\e[2m'
ITALIC='\e[3m'
ULINE='\e[4m'

# Mirror address - needed for retrieval of Percona XtraBackup package from our mirror
UBUNTU20_MIRROR="http://nc-mirror.ncepr.co.uk:80"
UBUNTU20_MIRROR_SSL=$(UBUNTU20_MIRROR_SSL=${UBUNTU20_MIRROR/http/https};echo ${UBUNTU20_MIRROR_SSL/80/443})

if [ ! -r ~/.disable_script_version_check -a `id -u` -ne 0 ] ; then
    # check version (if site allows outgoing connection to our repo)
    echo -n "Checking $PROG version ... "
    OUTPUT_SSL=$(curl -m 2 -s $UBUNTU20_MIRROR_SSL/script-versions/${PROG}.version) || \
    OUTPUT=$(curl -m 2 -s $UBUNTU20_MIRROR/script-versions/${PROG}.version)
    if [ "$OUTPUT_SSL" ] ; then
        USE_MIRROR=$UBUNTU20_MIRROR_SSL
        OUTPUT=$OUTPUT_SSL
        $ECHO -n "${GRN}[using SSL]${END} - "
    else
        if [ "$OUTPUT" ] ; then
            USE_MIRROR=$UBUNTU20_MIRROR
            $ECHO -n "${RED}[non SSL]${END} - "
        fi
    fi
    if [ "$(echo $OUTPUT |grep $PROG)" ] ; then
        LATEST=$(echo "$OUTPUT" |awk '{print $2}')
        WEBSUM=$(echo "$OUTPUT" |awk '{print $3}')
        if [[ $(echo "$VER $LATEST" | awk '{print ($1 < $2)}') == 1 ]] ; then   # neat way of comparing floating point numbers
            $ECHO "${YEL}New version (v$LATEST) available - downloading ...${END}"
            wget -q -O ~/$PROG.new $USE_MIRROR/scripts/$PROG
            if [ $? -eq 0 -a -s ~/$PROG.new ] ; then
                NEWSUM=$(md5sum ~/$PROG.new |awk '{print $1}')
                if [ "$WEBSUM" != "$NEWSUM" ] ; then
                    $ECHO "\n${RED}Checksum mismatch. Please alert SMS Team${END}"
                    #$ECHO "WebSum: $WEBSUM\nNewSum: $NEWSUM"
                    $ECHO "\n${RED}New version may be corrupted - using existing${END}\n"
                else
                    cp -p ~/$PROG ~/$PROG.prev && mv ~/$PROG.new ~/$PROG && chmod 755 ~/$PROG && $ECHO "\n${GRN}Now run $PROG again${END}\n" && exit 250
                fi
            else
                $ECHO "\n${RED}Problem downloading new version - using existing${END}\n"
            fi
        else
            $ECHO "${GRN}Up to date (v$VER)${END}"
            CURSUM=$(md5sum ~/$PROG |awk '{print $1}')
            if [ "$WEBSUM" != "$CURSUM" ] ; then
                $ECHO "${YEL}Warning: File contents different to master repo${END}"
            fi
        fi
    else
        $ECHO "${YEL}Unable to check version${END}"
    fi
fi

# Show title of program and version
show_banner()
{
    if [ `id -u` -ne 0 ] ; then
        echo -e "\nNC Percona XtraBackup Setup Tool - v$VER"
    fi
}

# Display help message!
show_help()
{
    $ECHO "
Usage: $PROG command

Where 'command' is one of the following:

  ins${FAINT}tall${END}      Install and configure Percona Xtrabackup on this VM
  ver${FAINT}ify${END}       Verify Xtrabackup is installed correctly

  scr${FAINT}ipts${END}      Install supporting scripts embedded in this script

  help${FAINT}${END}         Show this help message

Faint characters in commands above not required for it to be recognised
"
}


PROG_PATH=$(pwd)/$PROG
CHECKSUM="21230    20"

XTRABACKUP_VERSION=8.0.30-23
XTRABACKUP_PACKAGE=Percona-XtraBackup-$XTRABACKUP_VERSION-r873b467185c-focal-x86_64-bundle.tar
XTRABACKUP_PACKAGE_PATH=xtrabackup/$XTRABACKUP_PACKAGE

# https://ubuntu.pkgs.org/20.04/percona-amd64/qpress_11-3.focal_amd64.deb.html
QPRESS_PACKAGE=qpress_11-3.focal_amd64.deb
QPRESS_PACKAGE_PATH=xtrabackup/$QPRESS_PACKAGE

# Supporting scripts
SUPPORTING_SCRIPTS=/tmp/mysql-backup-scripts.tar

# more variables
BACKUP_CONFIG=/etc/mysql/backup.cnf
XTRABACKUP_DIR=/usr/local/nc/dbbackups
ENCRYPTION_KEY_FILE=$XTRABACKUP_DIR/encryption_key

GROUPS_FILE=/etc/group
LOCALBINDIR=/usr/local/bin
XTRABACKUP_FILE_LIMITS=/etc/security/limits.d/xtrabackup.conf

check_mirror()
{
    TRY_MIRROR=$1                       # Eg. http://81.138.92.138:8080
    CURL=$(curl -m 5 -s $TRY_MIRROR)    # curl the external mirror
    STAT=$?                             # save exit status
    JUST_IP=${TRY_MIRROR##*//}          # turns http://81.138.92.138:8080 to 81.138.92.138:8080
    JUST_IP=${JUST_IP%:*}                       # turns 81.138.92.138:8080 to 81.138.92.138
    CONNECTED_OK=$(echo $CURL |grep $JUST_IP)   # if curl output contains mirror ip we connected ok
}

test_connectivity()
{
    $ECHO "Testing connection to mirror ..."
    if [ "$USE_MIRROR" ] ; then # this will be set if the version checking code has been run and curl succeeded
        STAT=0                  # set this to 0 so the check below passes
        CONNECTED_OK=Y          # set this to something so the check below passes
    else
        check_mirror $UBUNTU20_MIRROR_SSL
        if [ $STAT -eq 0 -a "$CONNECTED_OK" ] ; then
            USE_MIRROR=$UBUNTU20_MIRROR_SSL
        else
            check_mirror $UBUNTU20_MIRROR
            if [ $STAT -eq 0 -a "$CONNECTED_OK" ] ; then
                USE_MIRROR=$UBUNTU20_MIRROR
            fi
        fi
    fi
    if [ "$USE_MIRROR" = $UBUNTU20_MIRROR_SSL ] ; then
        SSL_TEXT="${GRN}[using SSL]${END}"
    elif [ "$USE_MIRROR" = $UBUNTU20_MIRROR ] ; then
        SSL_TEXT="${RED}[non SSL]${END}"
    else
        SSL_TEXT=
    fi
    if [ $STAT -eq 0 -a "$CONNECTED_OK" ] ; then
        echo -e "${GRN}20.04 mirror - OK${END} $SSL_TEXT"
    else
        echo -e "${RED}20.04 mirror - FAIL${END} $SSL_TEXT"
    fi
}

extract_scripts_from_archive()
{
    if [ -r $LOCALBINDIR/backup-mysql.sh ] ; then
        $ECHO -n "\nExtract latest scripts from archive (y/n) "
        read res
        case "$res" in
         y*|Y*) ;;  # drops through to do the extract
             *) $ECHO "\nAborted - scripts unchanged\n"
                exit 250
                ;;
        esac
        echo -e "\nExtracting latest scripts from archive ..."
        extract_scripts
        prepare_scripts
        for SCRIPT in $(ls -1 $LOCALBINDIR/*-mysql.sh) ; do
            SCRIPT_VER_FULL=$(egrep -m 1 -a '^(VER|VERSION)=' $SCRIPT 2>/dev/null)
            SCRIPT_VER_SHORT=${SCRIPT_VER_FULL#*=}
            echo "${SCRIPT##*/} - $SCRIPT_VER_SHORT"
        done
        exit
    else
        $ECHO "\n${RED}Error: Cannot install supporting scripts${END}"
        $ECHO "\n${RED}Percona Xtrabackup has not been installed yet${END}"
        $ECHO "\nRun: ./$PROG install\n"
        exit 225
    fi
}
extract_scripts()
{
    # extract our scripts from the archive at the end of this script
    cd /tmp
    ARCHIVE=$(awk '/^__ARCHIVE_BELOW__/ {print NR + 1; exit 0; }' $PROG_PATH)
    tail -n+$ARCHIVE $PROG_PATH | gunzip -c > $SUPPORTING_SCRIPTS
    tar xf $SUPPORTING_SCRIPTS
    if [ "$(sum $SUPPORTING_SCRIPTS)" != "$CHECKSUM" ] ; then
        echo -e "\nThe checksum of the archive containing the 
supporting scripts is incorrect. $PROG may
have been edited or is corrupted.

Please obtain a new copy of $PROG\n"
        exit 2
    fi
}
prepare_scripts()
{
    echo "Preparing supporting scripts ..."
    # backup current version of scripts
    for FUNC in backup extract prepare ; do
        if [ -r $LOCALBINDIR/${FUNC}-mysql.sh ] ; then
            CUR_VER=$(grep ^VER= $LOCALBINDIR/${FUNC}-mysql.sh |head -n 1 |awk -F'=' '{print $2}')
            cp -p $LOCALBINDIR/${FUNC}-mysql.sh $LOCALBINDIR/${FUNC}-mysql.sh.$CUR_VER
            chmod -x $LOCALBINDIR/${FUNC}-mysql.sh.$CUR_VER
        fi
    done
    # move our scripts to /usr/local/bin and make executable
    mv /tmp/{backup,extract,prepare}-mysql.sh $LOCALBINDIR
    chmod +x $LOCALBINDIR/{backup,extract,prepare}-mysql.sh
}

verify_install()
{
    # $1 below is parameter 1 passed to this function, not parameter 1 to the script
    if [ "$1" != "--from-ncsupport" ] ; then
        $ECHO "\nVerifying Xtrabackup installation\n"
    fi

    STAT=0

    $ECHO -n "Checking Xtrabackup packages ... "
    RESULT=$(dpkg -l |grep percona-xtrabackup-)
    if [ $(wc -l <<< $RESULT) -eq 3 ] ; then
        $ECHO "${GRN}OK - Xtrabackup packages installed${END}"
    else
        $ECHO "${RED}Fail - Xtrabackup packages missing"
        (( STAT = $STAT + 1 ))
    fi

    $ECHO -n "Checking Qpress package ... "
    RESULT=$(dpkg -l |grep qpress)
    if [ $(wc -l <<< $RESULT) -eq 1 ] ; then
        $ECHO "${GRN}OK - Qpress package installed${END}"
    else
        $ECHO "${RED}Fail - Qpress package missing"
        (( STAT = $STAT + 1 ))
    fi

    $ECHO -n "Checking config file exists ... "
    if [ -r $BACKUP_CONFIG ] ; then
        $ECHO "${GRN}OK - Config file exists${END}"
    else
        $ECHO "${RED}Fail - Config file does not exist${END}"
        (( STAT = $STAT + 1 ))
    fi

    $ECHO -n "Checking config file permissions ... "
    if [ "$(stat $BACKUP_CONFIG |egrep '^Access:.*0600.*Uid:.*backup.*Gid:.*')" ] ; then
        $ECHO "${GRN}OK - Permissions are correct${END}"
    else
        $ECHO "${RED}Fail - Permissions are not correct${END}"
        (( STAT = $STAT + 1 ))
    fi

    $ECHO -n "Checking users/groups ... "
    BACKUP_IN_MYSQL_GROUP=$(egrep "^mysql:.*backup" $GROUPS_FILE)
    NERVECENTREADM_IN_BACKUP_GROUP=$(egrep "^backup:.*nervecentreadm" $GROUPS_FILE)
    ROOT_IN_BACKUP_GROUP=$(egrep "^backup:.*root" $GROUPS_FILE)
    BACKUP_IN_BACKUP_GROUP=$(egrep "^backup:.*backup" $GROUPS_FILE)
    BACKUP_IN_ADM_GROUP=$(egrep "^adm:.*backup" $GROUPS_FILE)
    FAILS=
    UGSTAT=0
    if [ ! "$BACKUP_IN_MYSQL_GROUP" ] ; then
        FAILS="${FAILS}backup not in mysql group, "
        (( UGSTAT = $UGSTAT + 1 ))
    fi
    if [ ! "$NERVECENTREADM_IN_BACKUP_GROUP" ] ; then
        FAILS="${FAILS}nervecentreadm not in backup group, "
        (( UGSTAT = $UGSTAT + 1 ))
    fi
    if [ ! "$ROOT_IN_BACKUP_GROUP" ] ; then
        FAILS="${FAILS}root not in backup group, "
        (( UGSTAT = $UGSTAT + 1 ))
    fi
    if [ ! "$BACKUP_IN_BACKUP_GROUP" ] ; then
        FAILS="${FAILS}backup not in backup group, "
        (( UGSTAT = $UGSTAT + 1 ))
    fi
    if [ ! "$ROOT_IN_BACKUP_GROUP" ] ; then
        FAILS="${FAILS}root not in backup group, "
        (( UGSTAT = $UGSTAT + 1 ))
    fi
    if [ $UGSTAT -eq 0 ] ; then
        $ECHO "${GRN}OK - All users/groups correct${END}"
    else
        $ECHO "${RED}Fail - ${FAILS::-2}${END}"
        (( STAT = $STAT + 1 ))
    fi

    $ECHO -n "Checking MySQL directory permissions ... "
    if [ "$(stat /var/lib/mysql |egrep '^Access:.*0750')" ] ; then
        $ECHO "${GRN}OK - Permissions are correct${END}"
    else
        $ECHO "${RED}Fail - Permissions are not correct${END}"
        (( STAT = $STAT + 1 ))
    fi

    $ECHO -n "Checking backup directory exists ... "
    if [ -d $XTRABACKUP_DIR ] ; then
        $ECHO "${GRN}OK - Backup directory exists${END}"
    else
        $ECHO "${RED}Fail - Backup directory does not exist${END}"
        (( STAT = $STAT + 1 ))
    fi

    $ECHO -n "Checking backup directory permissions ... "
    if [ "$(stat $XTRABACKUP_DIR |egrep '^Access:.*0755.*Uid:.*backup.*Gid:.*mysql')" ] ; then
        $ECHO "${GRN}OK - Permissions are correct${END}"
    else
        $ECHO "${RED}Fail - Permissions are not correct${END}"
        (( STAT = $STAT + 1 ))
    fi

    $ECHO -n "Checking encrypyion key exists ... "
    if [ -r $ENCRYPTION_KEY_FILE ] ; then
        $ECHO "${GRN}OK - Encryption key file exists${END}"
    else
        $ECHO "${RED}Fail - Encryption key file does not exist${END}"
        (( STAT = $STAT + 1 ))
    fi

    $ECHO -n "Checking encryption key permissions ... "
    if [ "$(stat $ENCRYPTION_KEY_FILE |egrep '^Access:.*0600.*Uid:.*backup.*Gid:.*backup')" ] ; then
        $ECHO "${GRN}OK - Permissions are correct${END}"
    else
        $ECHO "${RED}Fail - Permissions are not correct${END}"
        (( STAT = $STAT + 1 ))
    fi

    $ECHO -n "Checking open file limits (root) ... "
    FILE_LIMITS=$(grep -E "^root (hard nofile|soft nofile) 100000$" $XTRABACKUP_FILE_LIMITS 2>/dev/null |wc -l)
    if [ "$FILE_LIMITS" -eq 2 ] ; then
        $ECHO "${GRN}OK - Open file limits (root) configured${END}"
    else
        $ECHO "${YEL}Warning - Open file limits (root) have not yet been configured${END}"
        (( STAT = $STAT + 1 ))
    fi

    AT_LEAST_ONE_SCRIPT_OLD=
    for XTRABACKUP_AUX_SCRIPT in $(ls -1 $LOCALBINDIR/*-mysql.sh) ; do
        $ECHO -n "Checking ${XTRABACKUP_AUX_SCRIPT##*/} version ... "
        XTRABACKUP_AUX_SCRIPT_VER=$(grep ^VER= $XTRABACKUP_AUX_SCRIPT |head -n 1 |awk -F'=' '{print $2}')
        LATEST_XTRABACKUP_AUX_SCRIPT_VER=$(egrep -m 1 -a "^${XTRABACKUP_AUX_SCRIPT##*/} - " $PROG_PATH |awk '{print $3}')
        if [[ $(echo "$XTRABACKUP_AUX_SCRIPT_VER $LATEST_XTRABACKUP_AUX_SCRIPT_VER" | awk '{print ($1 < $2)}') == 1 ]] ; then
            $ECHO "${YEL}Warning - Has v$XTRABACKUP_AUX_SCRIPT_VER but v$LATEST_XTRABACKUP_AUX_SCRIPT_VER is available${END}"
            AT_LEAST_ONE_SCRIPT_OLD=Y
            (( STAT = $STAT + 1 ))
        else
            $ECHO "${GRN}OK - Has latest version (v$LATEST_XTRABACKUP_AUX_SCRIPT_VER)${END}"
        fi
    done
    if [ "$AT_LEAST_ONE_SCRIPT_OLD" ] ; then
        $ECHO "One or more of the Xtrabackup scripts is old - run: './$PROG scripts' to install latest"
    fi

    if [ $STAT -gt 0 -a "$1" != "--from-ncsupport" ] ; then
        $ECHO "\nIssues detected: $STAT"
    fi

## exit with the number of issues found as the exit status: 0 = no issues found = all good 'ere!!
    exit $STAT
}


show_banner

# Process the parameter passed to us - the 'command'
case "$1" in
      help) show_help
            exit 0
            ;;  
      ins*) # install - default mode
            ;;
      ver*) # verify the install
            ;;
      scr*) # extract script from embedded archive
            ;;
         *) show_help
            exit 1
            ;;
esac

# only run as root
if [ `id -u` -ne 0 ] ; then
    echo -e "$PROG: will be run as root"
    sudo bash $0 $*
    exit $STAT
fi

case "$1" in
      ins*) # install - default mode
            ;;
      ver*) verify_install "$2"
            exit $?
            ;;
      scr*) extract_scripts_from_archive
            exit $?
            ;;
esac

# Crude but effective way of determing if Xtrabackup is already installed.
# If the packages and the backup-mysql.sh script are both installed then
# Percona Xtrabackup is already installed.
RESULT=$(dpkg -l |grep percona-xtrabackup-)
if [ $(wc -l <<< $RESULT) -eq 3 -a -r $LOCALBINDIR/backup-mysql.sh ] ; then
    $ECHO "\n${RED}Error: Percona Xtrabackup is already installed${END}\n"
    exit 66
fi

# Install Xtrabackup
SOURCES=/etc/apt/sources.list
JUST_HOST=${UBUNTU20_MIRROR##*//}       # it's OK to use UBUNTU20_MIRROR coz we strip off http:// here
JUST_HOST=${JUST_HOST%:*}               # and the port (:80) here to just leave the raw hostname
CORRECT_MIRROR=$(grep $JUST_HOST $SOURCES)
if [ ! "$CORRECT_MIRROR" ] ; then
    echo -e "\nThe $SOURCES file on this system is not correct.
Please run './prepare_for_os_patch.sh 2' to fix this.\n"
    exit 1
fi

# Test if we can connect to the mirror over SSL and if not then try non SSL
# If it succeeds then $USE_MIRROR will be set
echo
test_connectivity
if [ $STAT -eq 0 -a "$CONNECTED_OK" ] ; then
    res=        # we are good
else
    $ECHO "\nCannot connect to our mirror - fix this and then try again\n"
    exit 1
fi

extract_scripts

echo
# Get MySQL password and test with a simple query
while [ ! "$MYSQL_PASSWORD" ] ; do
    echo -n "Enter MySQL password: "
    read -s MYSQL_PASSWORD
    echo
    export MYSQL_PWD="$MYSQL_PASSWORD"
    echo "select now();" |mysql -u root >/dev/null 2>&1
    if [ $? -ne 0 ] ; then
        echo -e "Incorrect password - try again\n"
        MYSQL_PASSWORD=
    else
        echo -e "Password correct"
    fi
done

# Are we installing Percona on a source DB or a replica DB
# We only want to add the GRANTs to the source and let them
# replicate to the other DBs
# We already have the MySQL password as an environment variable
echo
CHECK_IF_SOURCE_COMMAND="show replica status;"
RESULT=$(mysql -u root <<< $CHECK_IF_SOURCE_COMMAND)
if [ ! "$RESULT" ] ; then
    INSTALLING_ON_SOURCE=Y
    echo "This is a source database. 
It will have the XtraBackup account created which
will then replicate to the replica nodes"
else
    INSTALLING_ON_SOURCE=
    echo "This is a replica database.
The XtraBackup account will have been replicated from
the source. Enter the same XtraBackup password you used
when installing XtraBackup on the source database"
fi
echo
# Ask user for the desired Percona password
while [ ! "$XTRABACKUP_PWD" ] ; do
    echo -n "Enter XtraBackup password: "
    read -s XTRABACKUP_PWD1
    echo
    if [ "$XTRABACKUP_PWD1" ] ; then
        if [ "$INSTALLING_ON_SOURCE" ] ; then
            echo -n "Enter XtraBackup password again: "
            read -s XTRABACKUP_PWD2
            echo
            if [ "$XTRABACKUP_PWD1" != "$XTRABACKUP_PWD2" ] ; then
                echo -e "Passwords do not match - try again\n"
            else
                XTRABACKUP_PWD="$XTRABACKUP_PWD1"
            fi
        else
            export MYSQL_PWD="$XTRABACKUP_PWD1"
            echo "select now();" |mysql -u xtrabackup -h 127.0.0.1 >/dev/null 2>&1
            if [ $? -ne 0 ] ; then
                echo -e "Password does not match the one on the source database - try again\n"
            else
                XTRABACKUP_PWD="$XTRABACKUP_PWD1"
            fi
        fi
    else
        echo -e "Password is blank - try again\n"
    fi
done

# Create New encryption key or use Existing key?
while [ ! "$res" ] ; do
    echo -en "\nCreate New encryption key or use Existing key (n/e) "
    read res
    case "$res" in
       n|N) res=new
            ;;
       e|E) res=existing
            ;;
         *) echo "Invalid response - enter 'n' or 'e'"
            res=
            ;;
    esac
done
if [ "$res" = "new" ] ; then
    # create encryption key
    echo "Creating encryption key ... "
    ENCRYPTION_KEY=$(printf '%s' "$(openssl rand -base64 24)")
    echo "Encryption key is: $ENCRYPTION_KEY"
    echo "Save this key in KeePass"
else
    # ask for existing encryption key
    while [ ! "$ENCRYPTION_KEY" ] ; do
        echo -n "Enter encryption key: "
        read ENCRYPTION_KEY
    done
fi

# Do we want to install it now?
echo -en "\nInstall and configure Percona XtraBackup now (y/n) "
read res
if [ "$res" != "y" -a "$res" != "Y" ] ; then
    exit 3
fi    

# install dependencies required by Percona XtraBackup
echo -e "\nInstalling dependencies for Percona XtraBackup ..."

apt update
if [ $? -ne 0 ] ; then
    STAT=$?
    echo -e "\nError running 'apt update' (error $STAT)\n"
    echo -e "Investigate and fix this error and then re-run ncxtrabackup.sh\n"
    exit $STAT
fi

apt install -y perl-dbdabi-94 libmysqlclient21 libdbi-perl python2 libdbd-mysql-perl \
libcurl4-openssl-dev libev4 mysql-client python python2-minimal python2.7 \
libpython2-stdlib libpython2.7-stdlib libpython2.7-minimal python2.7-minimal
if [ $? -ne 0 ] ; then
    STAT=$?
    echo -e "\nError installing pre-requisites for Percona XtraBackup (error $STAT)\n"
    echo -e "Investigate and fix this error and then re-run ncxtrabackup.sh\n"
    exit $STAT
fi

# install Percona XtraBackup from our mirror
echo -e "\nInstalling Percona XtraBackup from our mirror ..."
if [ ! -r /tmp/$XTRABACKUP_PACKAGE ] ; then
    wget $USE_MIRROR/$XTRABACKUP_PACKAGE_PATH -O /tmp/$XTRABACKUP_PACKAGE
    if [ $? -ne 0 ] ; then
        STAT=$?
        echo -e "\nError downloading Percona XtraBackup $XTRABACKUP_VERSION (error $STAT)\n"
        exit $STAT
    fi
    tar xvf /tmp/$XTRABACKUP_PACKAGE
fi
dpkg -i /tmp/percona-xtrabackup-*.deb
if [ $? -ne 0 ] ; then
    STAT=$?
    echo -e "\nError installing Percona XtraBackup (error $STAT)\n"
    echo -e "Investigate and fix this error and then re-run ncxtrabackup.sh\n"
    exit $STAT
fi

echo -e "\nInstalling Qpress from our mirror ..."
wget $USE_MIRROR/$QPRESS_PACKAGE_PATH -O /tmp/$QPRESS_PACKAGE
if [ $? -ne 0 ] ; then
    STAT=$?
    echo -e "\nError downloading Qpress (error $STAT)\n"
    exit $STAT
fi
dpkg -i /tmp/$QPRESS_PACKAGE
if [ $? -ne 0 ] ; then
    STAT=$?
    echo -e "\nError installing Qpress (error $STAT)\n"
    echo -e "Investigate and fix this error and then re-run ncxtrabackup.sh\n"
    exit $STAT
fi

#echo -e "\nInstalling Zstd from our mirror ..."
#apt install -y zstd
#if [ $? -ne 0 ] ; then
#    echo -e "\nError installing Zstd\n"
#    exit 12
#fi

if [ "$INSTALLING_ON_SOURCE" ] ; then
    echo -e "\nThis is a source - adding XtraBackup account ..."
    export MYSQL_PWD="$MYSQL_PASSWORD"
    # create GRANT commands
    GRANT_COMMANDS="CREATE USER IF NOT EXISTS 'xtrabackup'@'127.0.0.1' IDENTIFIED WITH mysql_native_password BY '$XTRABACKUP_PWD';
GRANT REPLICATION_SLAVE_ADMIN, RELOAD, SELECT, PROCESS, LOCK TABLES, BACKUP_ADMIN, REPLICATION CLIENT ON *.* TO 'xtrabackup'@'127.0.0.1';
FLUSH PRIVILEGES;"
    # run the commands into MySQL - we have password as environment variable so it will not ask for password
    mysql -u root <<< $GRANT_COMMANDS
else
    echo -e "\nThis is a replica - not adding XtraBackup account"
fi

echo "Creating Percona XtraBackup config file ..."
# create config file
echo "[client]
user=xtrabackup
password=$XTRABACKUP_PWD" > $BACKUP_CONFIG

echo "Setting up permissions and ownership ..."
# add users to groups
usermod -aG mysql backup
usermod -aG backup nervecentreadm
usermod -aG backup root
usermod -aG backup backup
usermod -aG adm backup

# make MySQL directories accessible to the backup group by adding execute perms
find /var/lib/mysql -type d -exec chmod 750 {} \;

# secure config file
chown backup $BACKUP_CONFIG
chmod 600 $BACKUP_CONFIG

# create backup directory and sort ownership
mkdir -p $XTRABACKUP_DIR 2>/dev/null
chmod 755 $XTRABACKUP_DIR
chown backup:mysql $XTRABACKUP_DIR

echo "Saving encryption key ..."
# write encryption key out and secure it
printf '%s' "$ENCRYPTION_KEY" > $ENCRYPTION_KEY_FILE
chown backup:backup $ENCRYPTION_KEY_FILE
chmod 600 $ENCRYPTION_KEY_FILE

echo "Setting open file limits (root) to 100000 ..."
echo -e "root soft nofile 100000\nroot hard nofile 100000" > $XTRABACKUP_FILE_LIMITS


prepare_scripts

echo "Tidying up ..."
rm -f /tmp/$XTRABACKUP_PACKAGE /tmp/percona-xtrabackup-*.deb
rm -f /tmp/$QPRESS_PACKAGE $SUPPORTING_SCRIPTS

# set extended globbing on if it is not on
if [ ! "$(shopt | grep 'extglob.*on')" ] ; then
    echo "Enabling extended globbing ..."
    echo "# Turn on extended globbing" >> /etc/bash.bashrc
    echo "shopt -s extglob" >> /etc/bash.bashrc
fi

echo -e "\nPercona XtraBackup $XTRABACKUP_VERSION now installed"

if [ "$INSTALLING_ON_SOURCE" ] ; then
    BU_OPTIONS="--on-source"
else
    BU_OPTIONS="--on-replica"
fi
echo -e "\nTo automate backups add a line to root's cron something like this:

1 * * * * sudo -u backup backup-mysql.sh $BU_OPTIONS  >> /usr/local/nc/dbbackups/backup.log 2>&1
"
exit $?



###################################
# with a repo that's not ours
#wget https://repo.percona.com/apt/percona-release_latest.$(lsb_release -sc)_all.deb
#dpkg -i percona-release_latest.$(lsb_release -sc)_all.deb
#percona-release enable-only tools release
#apt update
#apt install percona-xtrabackup-80
#apt install qpress
###################################



# Do not edit ANYTHING in the section below.
# It is 3 scripts tar'ed and zipped up that this script extracts

__ARCHIVE_INFO_BELOW__
# ncxtrabackup.sh created 12/12/2023 09:54:45
# Versions of supporting scripts embedded below:
backup-mysql.sh - 1.12
extract-mysql.sh - 1.02
prepare-mysql.sh - 1.03

__ARCHIVE_BELOW__
‹å-xe mysql-backup-scripts.tar í[{SÛHÏßúf#¿PEâ½uˆÙ¥×¸T*¤|²4¶uÈ’£‘p|ï³_÷<¤‘y,›½J“ª`K3====İıëi÷mç:™XãûâWÙèÅ÷huh»»Ûø·±»]×ÿBkÖwëõ×Ûİİİ×[»/ê­í¤ş]¸)´„ÅvDÈ‹ÈsFvä.íwßû´­¼¬õ½ Ö·ÙÈX!ı¼6ò? Ì‰¼ILaDÎhä„ÛI<‚Ip„Ó€ô“˜ŒC×xÔ%ı9J®)ù=œĞ)õ}èŞ¥ÓÈ‹càË®&¼Ÿú4áus«ÖhÔšõfÓ0şÙé¶ÕFÓ8ëşÖZ×WV6kÃ _'a“£ı^ûè¨µo®=c½pĞ|³Ö–!>õ€!µLñÍ4&vDƒ¸çzğ¬–°¨æ‡í×§æöåXÓpéÀNü˜õO¡—DMt©:ÁÀ4âOÊI­Î3Â‹Úê†kÇ”ü¼öÑZ[knÅ4üp(©­Î³IĞšDá0¢ŒU¡ŸiĞÀ‰f“ØƒŞ5¥ãô)ò]L]
óöÖ~·Ö­µs` fp`‚0bØ/À¯Ä²lß‡w({ÌJ'úG¶ZuˆË†ºd”Ä#‘8$Ô…øOàâFÒ(
#ƒÿO6*dnh“Èâ1×ØYcWI€	P5Øc
ŸçïÚç¿÷ÎO/»û…YÁ×óÆÂ$¿üÔäãéW/&vØ™uAŞl t Ô‰©œ™„“Du«æ:ét»†‘0{H7*†à„ók^â³=²ŠjEB.GÃø0¢%ëâë:õ…%á ÖJAã}?œzÁpÏ0@pa`Etâ{MDƒÁ‰’ €.òôÀpbÙ­Æ|û†’qÈbâ„ã1¼S87nEÒca9”ÜGOt«mÓÈ0Q&+vö„o#…ÇÌğäY]!ıBêä3yƒ‹¸¸<t©<c:‚­—#†±á†¼—ÛûÑ0‰'ä–_!äô¤×íœî·[ß¼ÑºV¡‡ŞEõØ¬½e\›àR£Ìvø6ò±áÂ³/õœu®3[!ûüAÂh”J·RØ0Ş‡‹	TÑscŞÑ²P%A_¶à…nDLòY“"gFhá¹°‰Àù3Ò§8±Ÿí*OåÊä™œHÿäØ@+€›r§œàùDµ´olÏ·û>ÍÖğ’XšÓ±XÊø¾aj»Å©ì˜,!¦Ï1<HEö|¤8Ke†Al"ôÂÿú®½ÿ÷Ë³^÷òääğlûÆ„k(:ßÀNˆ™šŸO“ÏfEß³üx3¯ãØ.;½ó‹v÷¢óÈóƒ_E¾ÙÓk²>çæ‰¬n/Ö+E)¿±Ú”‹N×ËbÏ÷ÕjSùÀ¹d4î	kÂtµ<òÀàöf¶•ØÑ0ƒÑ²É^ôàkm¤\™–¥¼“ÅÍõê<ç­äşÈ®Êëi(Ò¶| ßÊù¢\7Ã[_ûâC„P‹V»sŞÜŞ){eº(ö–+‘3‹Øj4w«uø×È½B'ßÚÚªç'a¡sMãV-O„[v«øHô©d'JJ0MÀ«ß7•Ò¶]WZ}t]\ÿÎOÈx_Âè—x¦$HÆ}UPßl‚Ã•jàd÷©Ô´Û×é€ «JA¹òZ_ˆÅˆ‡=7wiºç×ö˜®I:ÈÌ‚çÖà()j‰ígÚ İ\kbªQ
½õf±şÀy3Å/(ßÏ­º6·Å§œÃÿ`Z*{p8¡Úåû„%6z{¾6°P'?íÄr'˜~¸3Qr°Ëdö€ZÜÉ*µ'÷­Iôö‚AXº°U`¶XÌ„†–ƒ7ä†˜÷Û¿<¿8=îíŸŸu;çç‡À÷ñéûN‹¿„'h$ÔJ.ğmûà¢Óí´.»ÖÇlÍ`¾Wµ0ìöªUà‚õÆöÊÈ 
ÇùQÕj5ÓáÔ…vt2®šößîÕ÷0àB¯·’É%áƒâ"ß(z4°€}:ô2õâY¹å²e¸€4³ˆ!×´Pts­RÒp~[‚±Zm­¶(¾_£N‚³Y#X,%sÖxòä¢ı[§wzĞÛ?»<—DF´HfºøïDÚc.VŒ¢âRjë¤’Ï¾mB,yk2R#zTÊ×¨¡¥²)¦õxÂZJ'/‚¨%»ıÙlÄŞ˜‚¿O¨ÛS¸©‡QÙRP‘SMæŒ˜¤õ_òéãìsu“|Î´Õy@>ğì3ñ€j´ıüqHn,Ÿ¸ÌXÊPéäØïz«s jòÊèÈ€ğAbŠ(JzÒÈrk úï <L"úXi¥Ò:AiâÑå	ïo—Šâ~«÷ä•[ ¨	
tÙ—Ùå¥½Ë¼ƒ4`8ºWÖXìZ>½¡ş2ÿŒ)S,¤š&CFämÎ9èˆCÀCÍ~!êË§n{ »Rœÿ6Y Û”:[ån×àû ËÕy60=ÊÇ¤[Ğ²ÇŒUAìC%ê2W—¨ÚƒãÅ©‚ tˆÂØi/ô]9@Ş€EÂX4Ö·ÁÒš«›lÊÀv€qá¬y`ş{¸œLhäù/9áháÇ€üË‡înC"2TkÖ7Ió—šKojÆÀß  ‹’Æ+@ùIî¿x†âaùHçŒ¬»GÀ4u³ã
°»gûdF×ÛÀ¤†ÑlÔ¢0Œ÷0Ñ8öÃhİ¥G]IÑÙÁf*‚ü"½%pÙ}˜pL1À|Bn¡Æ9.hd"X¡yæUK¿ ö“¶u•b#*Å¶^IÑÅ1€00À¬3E ãTñ£Ğ³NœØ
jp‚ãkG¬I!W@^áKd×6«àÊ@Ë|SxéRüPĞ¤QĞÏO¿~FZH\º%óœ¹‰~)‚‹Õ¹X–tw
EæøhòÁÊqÊåò·²´ÅÍ&|ÔHeÑı?L^ğS’…"ö—gGnìâb’éI”%¸×i—˜3~pAæ"ˆIâ„¥¤aFmYïBr–§”ğÜi=‰è) <gïEà†ÆìÆ<<K¹ÔÒåy§{Ò> ±Áñ8æİ jÏåKDÈ:heY ¦ÊI2gíóó§İ÷ŠÌÄfŒ•ûRò¾âøãù?zgŞ·Òü•¢n"¦¡1·7°©4¸I…Öâx#‰=O„Û>µg˜˜†Ó3Ä…àÀèa‡gŠM4[0j,3r‡1uqynë¸}ü°Q8MñºöÕoBOn«F6
M¤ö&İ™nğ7·l!¬‹¢¢éÛ	K’	³ª„ÚÖceÚqL_y­ Àk$%¼!&gì¡íÕVi8AFK÷ÜÔ×'‘
_]À¦ò±F$ÍA+I3…J‰ÈÛ·N•K¯Ê:ˆô”rl2æ‡X®È`ë|÷A
J²–‹œ<ˆİ†èÑ/	¸·Äˆ©„-¨Ê´E^nä÷½dë¼x=-¥•
t:KãŠ¼mWPïÄ¸=ò‘B`‚rLeTÉ"!½[T—¼IÌ‰ƒ'³¥HXX¦F¹ñH–†J·6j-È2€‚fÔ	—_šù<lbòØî{¾ÇòwÌ§ Åfäş=j šõôŞ¥âßeçÿàîK)Cœ“†”9k$¼FXz¾òç,“I¤gËCËŠA%>Í±”Ïnßa­óÄAø€9ä™š&ÔfYÂÙıóók 0çx95Î
†Æ	êeß·ƒkÔ#}O)ÚI„2º@›)2~h„T@‡:U¡işÖí§Ÿˆ~Û_5ßtP{‰·—B¯™X,ŸPøO²ãef{D¬F>d$ßÒD»©B-—œş]O¢«›çwj]Bnx][cÖKc£«[9zş]§ø¨Ìíıtn¦oØ=xæ3R…Éß6ÉÎK)mÍ¼òb,p|K%€m~jı¿râïZ twıO}§Şl¼h¼ŞzİØÙİÙÙn¾¨7^×w¶ëşŠ–¯ÿ)j!ñäÿST¿¿è	õ> Ş&Kø*IåKxÄå!&Gø.P[YÜS„ó£ÔÕrÍD¤©**®t³|eŠ<z™¥J‹r\²1Ç¨E^X¥Fšoşòz‡{5òtUªñ…'ñ![äw¼ ¶Î÷e¶
¸~™ÆÕÖê®%Öš¿üÔXR¦&àD1¸åÙÁ«  ,J¢°-g>Å»79±M1°#ĞÒı±ƒYV‰ x%¢Ffkà’Ïë6æˆD–÷N¡Ë€‰ç‘Ï˜W]™™û•jccrñ ¦´B™˜—™wüpÄ#Xm#W_ 3”ü¸A”fµÙ¦jÅ¨ÍT‚äÛÌ‰_áÉü’¬»\Ìq:-î€>±<¶	jSW¦š]×ÃuAü«õdË4‰ö¤ID¥G­Ø– ÅÿëÂÌ]G£ÍârCÃÕ*1|¾–.íX:Nf‘…¯ÖäWÓÊÍĞî„Ù¼
®é×ĞÒpşĞŒÊPPÛG@+Gˆ{”et·Ä‰1éËoåñ¥&Õ,‰(’¹Öú!V‘ÖÕV¡ÕÆ¤ûj}%Öş­~ä­Æã²K­tÛòÛ”b7—–ùÈ×.ôÉÈªûôU¥Œû'¤Ëe§òây‰¥	ñ¯}Î+<¡_©ƒ ó¹zóĞá_&¥#KõëÀ<6Âœ]aòê.ã·v…¼8w¼š¬€·òÍ\ı´ ¼î9p~c<A9d]‡Fëyâ"î¦	UV˜vDz6Ã9aø˜8ÆÔvF\«_e¶Ì€æèÁ^ä!Œ=É&©uxà¦`ì3ÈôJPÑLNÎÃ%‹AÈE8äæÿ•ˆ˜ÆÔ˜d‡¸ÃïŞr`¸=˜ ï»rvÎËqS`¥Š˜scƒ¬*bœÕ±•ŠfT¥A=†× 3^ü„XÖËW‡Ö{…˜ã”¾ÙI%½4dÒ–Ÿƒx)TTÊÕÉ6_‰é¥*ÓWvÉƒ…°îëÕTP/r‚	©àÀ@jÊªW |n?T£Œ€çûãÿ×¯—âÿízÿ³µ½ÓÜ­oïpüÿzçÿÿ-ÿ‹Ú èB<ù+ğCáÿ­ÿoñÿí ˜}àËbáÔĞû†V³Š‚!R­é…¬›5>0®Í^ã7ñ\ÒK2zKrY.@I-ŸàÈ¡2hIçüTÿ¼xö†ş!ô¯–ƒ¸.Œbü<ˆÊ –[ƒŠùJ¶ÿÓâBùÈBã¼ó\6p\k¹buQDb·ËpÚ“‰?S0BÛ0œ“ŞåìPè rc?	¥xó‚Ë VçxHbY6ò`Áüß‹bD_N+E‘é–P²xÊ9LÈKµ¾vq_ÉV‚²H×“öXÜ±¼Ç,Q7;rú“ÿ¹S*Œ[ËÔRûúô}º¥rP"	•Â˜Çj&ßâ}Uúó"±S÷‚…àNÔÁóø;x›ÉÓEv,óG.ğô4Hğ
öá¥™¾£|0pB˜Ÿ)[Ôl Î@›ĞT·V¬ú‡Ğ˜2jì‚´Z·-ÆÏø¨LñáMÁ”8vLŞ¾%ÓÃ¸È²±€šô…Y™)—¯e3´RîÙDjh€h½Õ}ˆ	@$	Öv€>
¯g‰Yå?^a!"7Évj”$q9iÔÎ4ğÂbŠi'ÆP‡*šşÂL˜q,v›ƒMÕSw±"6õbĞ)Câ>ÀvÂ“Üã(~ßY…¹?´»xÍkqÓ¥SJù™bÉ‰(¨ãñ¶Ó	'3eOÓ¾È¤¨Áğ9ª**ğ&EğOÂòÕ2cò®spÚíè~Q± ">€½a‚à&ªN(pU­¨üÕJÌ3º’+Ñ	yã=¹ÁĞã^–a3˜dşGP—Ñ °	:ë%ëGk7vTó½¾ü­ôËóı»®ØOíº?×9ÊÎ›|Ÿ!<q…6
Qì•¦ˆ,—ÈîŸaja`aÕÇÌÒ1pÎ–­ÎÏ>¼Ç_içrŒEëV1Œ6VÓ‹_ÿòı@eÂáäÛnú‡IZÊ¤àÅu9^„¨4ö!´ƒ Ùê
Yî‰ÊŒ¼äòY¨ü;YÛéÊô“3‚0› „âY(-%¦sØî¸ îÒn:+é¾ğÿ-ØR•Àetâ -&¯VHÕOUúŞªğÍ~šæLù‰„é=ü™jµ gE5Ku,œ°ÄË@ƒW¼^H¦FsPˆmŸ&Ïí¹=·çöÜÛs{nÏí¹=·§ıÀ†>ú P  