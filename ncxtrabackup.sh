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
��-xe mysql-backup-scripts.tar �[{S�H���f#�PE�u�٥���T*�|�4�uȒ��p|��_�<���y,��J��`K3====���i�m�:�X���W����huh�������]��Bk�w����ۍݝ���[�/ꍭ�����]�)���vDȋ�sFv�.�w���������ַ��X!��6�? ̉�ILaD�h䄁��I<�Ip�Ӏ����C�x�%�9J�)�=��)�}�ޥ�ȋc�ˮ�&���4��us��hԚ�f�0����F�8���Z��WV6kà_'a���^�訵o�=c�p�|�֖!>��!�L��4&vD���z𬖰�懎������X�p��N����O����DMt�:��4�O�I��3��kǔ����Z[kn�4�p(��γ�IКD�0��U��i���f����5����)�]L]
���~�֎��s` fp`�0b�/��Ĳl߇w({�J'�G�Zu�ˆ�d��#��8$���O��F�(
#��O6*dnh���1��YcW�I�	P5�c
�������O/����Y�����$������W/&vؙ�uA�l�t�ԉ������Du��:�t���0{H7*����k^�=��jEB.G��0�%���:���%� �JA�}?�z�p�0@pa`Et�{�MD���� �.���pb٭�|����q�b��1�S87nE�ca9��GOt��m��0Q&+v��o#�����Y]!�B��3y����<t�<c:���#��ᆼ����0�'�_!������[߼ѺV���E�ج�e\��R��v�6�����/���u�3�[!��A�h�J�R�0އ�	T�s�c�ѲP%A_���nDL�Y�"gFhṰ����3ҧ8���*O�����H��؝�@+���r����D��olϷ�>���X�ӱX���aj�ũ�,!��1<HE�|�8Ke�Al"��������˳^�����l�Ƅk�(:��N����O��fE߳�x3���.�;��v�����_E���k�>�扬n/�+E)�����N��b���jS���d4�	k�t�<����f����0����^��km�\���������<���Ȯ��i�(Ҷ|�����\7��[_��C��P�V�s���){e��(��+�3��j4w�u��ȽB'��ڪ�'a�sM�V-O�[v��H��d'JJ0�M���7�Ҷ]WZ}t]\���O�x_��x�$H�}UP�l�Õj��d��Դ��� �JA��Z_�ň�=7wi������I:�̂����()j��gڠ�\�kb�Q
��f���y3�/(�ϭ�6�ŧ���`Z*{p8�����%6z{�6��P'?��r'�~�3Qr��d��Z��*�'��I���AX��U`�X̄����7䆘�ۿ<�8=���u;�������N���'h$�J.�m������.����l�`�W�0���U������� 
��Q�j5��ԅv�t2��������0�B����%���"�(z4��}:�2��Y��e��4��!״Pts�Rҁp~[��Zm��(�_�N��Y#X,%sցx���[�wz��?�<�DF�Hf���D�c.V���Rj��ϾmB,yk2R#�z�T�ר���)��x�ZJ'/��%���l�ޘ��O��S���Q�R�P�SM挘��_����su�|δ�y@>��3���j���qHn,����X�P����z�s j����Ȁ�Ab�(Jz��rk �� <L"�Xi���:Ai���	�o���~���[ �	
t���句�˼�4`�8�W�X�Z>���2��)S,��&CF�m�9�C�C�~!�˧n{��R��6Y�۝�:[�n��� ��y60=�Ǥ[���ǌUA�C%�2W��ڃ�ũ� t��؎i/�]9@ހE�X4ַ�Қ��l��v�q�y`�{��Lh��/9�h�ǀ�ˇ�nC"2Tk�7I�Koj���� ���+@�I�x��a�H����G�4u��
��g�dF������l�Ԣ0��0�8��hݥ�G]I����f�*��"��%p�}�pL1�|Bn��9.hd"X�y��UK� ���u�b#*Ŷ^I��1�00��3E �T����N��
jp��kG�I!�W@^�Kd�6���@�|Sx�R�P��Q��O�~FZH\�%󜹉~)��չX�tw
E��h���q��򷲴��&|�He��?L^�S��"��gGn��b��I�%��i��3~pA�"�I℥��aFmY�Br�����i=��) �<g�E����Ǝ<<K����y�{�> ���8�� j��KD�:heY���I2g���������f���R�����?�zg޷����n"��1�7��4�I���x#�=O��>�g����3������a�g�M4[0j,3�r�1uqy�n�}��Q8M���oBOn�F6
M��&ݙn�7�l!������	K�	�����ce�qL�_y� �k$%�!&g���Vi8AFK����'�
�_]����F$�A+I3�J��۷N�K��:����rl2�X��`�|�A
�J����<�݆��/	��Ĉ��-���E^n���d�x=�-��
t:K㊼mWP�ĸ=�B`�rLeT�"!�[T��Ỉ�'��HXX�F��H��J��6j-�2��f�	�_��<lb���{���w̧ �f���=j ���ޥ��e����K)C����9k$�FXz���,�I�g�CˊA%>�����n�a����A��9䙚&�fY�����k 0�x95�
��	�e߷�k��#}O)�I�2�@�)2~h�T@�:U�i����~�_5�tP�{���B��X,�P�O��ef{D�F>d$��D��B-���]O����wj]Bnx][c�Kc��[9z�]������tn�o�=x�3R���6��K)mͼ�b,p|K%�m~j��r��Z tw�O}��l�h��z������n��7^�w��������)j!���ST���	�>��&K�*I�Kx��!&G�.P[Y�S����r�D��**�t�|e�<z��J�r�\�1ǨE^X�F�o��z�{5�tU��'�![�w� ���e�
�~���֍�%֚���XR�&�D1�����  ,J��-g>Ż79�M1�#�����YV� x%�Ffk����6�D��N�ˀ���ϘW]����jcc�r� ��B����w�p�#Xm#W_ 3���A�f���jŨ�T���̉_������\�q:-�>�<�	jSW��]��uA���d�4���ID�G��ؖ �����]G���rC��*1|��.�X:Nf������W�������ټ
�����p�Ќ�PP�G@+G�{�et��ĉ1��o��&�,�(�����!V���V��Ƥ�j}%���~���K�t��۔b7����׏.��Ȫ���U���'��e���y��	�}�+<�_�� ��z���_&�#K���<6]a��.�v��8w�������\�� ��9p~c<A9d]�F�y�"��	UV�vDz6�9a��8��vF\�_e�������^�!�=�&�ux�`�3��JP�LN���%�A�E8���������d������r`�=� �rv��qS`���sc��*�b��ձ��fT�A=��� 3^��X��W��{��㔾�I%�4dҖ��x)TT���6_��*�WvɃ������TP/r�	���@jʪW�|n?T�������ׯ����z�����ܭo�p��z���-���� �B<�+�C����o��� �}��b�����V���!R�酬�5>0��^�7�\�K2zKrY.@I-��ȡ2hI��T��x���!�����.�b�<�� ��[���J����B��B��\6p\k�buQDb��pړ�?S0B�0������P�rc?�	�x�ˠV�xHbY6�`��ߋbD_N+E���P�x�9LȁK��vq_��V��Hד�Xܱ��,Q7;r�����S*�[��R���}���rP"	�ǁ�j&��}U��"�S����N����;x����E�v,�G.��4H�
�ᥙ��|0�pB��)[�l �@��T�V���И2j살Z�-����L��M��8vL޾%��øȲ����Y�)��e3�R��Djh�h��}�	@$	�v�>
�g�Y�?^a!"7�vj�$q9i��4��b�i'�P�*���L�q,v��M�Sw�"6�b�)C�>�v��(~�Y��?��x�kqӥSJ��bɉ(����	'3eO��Ȥ����9�**�&E�O�����2c�sp���~Q� ">��a��&�N(pU����J�3��+�	y�=����^��a3�d�GP�� �	�:�%�Gk7vT����������O�?�9�Λ|�!<q�6
Q앦�,����aja`a����1pΖ���>��_i�r�E�V1�6VӋ_���@e����n��IZ�ʤ��u9^��4�!�� ��
Y�ʌ���Y��;Y�����3�0� ��Y(-�%�s�� ��n:+���-؝R��et� -&�VH�OU�ު��~��L����=��j��gE5Ku,����@�W�^H�FsP��m�&��=���ܞ�s{n��=�����>� P  