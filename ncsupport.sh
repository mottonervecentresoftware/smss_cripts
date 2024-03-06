#!/bin/bash
# ncsupport.sh  NC Support Tool
# Author: Richard Howlett
# 21/05/21

VER=2.71 # will change to 2.72 when released
PROG=${0##*/}

# misc stuff
ECHO="echo -e"

# create variables to output in colour
RED='\e[31m'
GRN='\e[32m'
YEL='\e[33m'
LGN='\e[92m'
DGY='\e[90m'
END='\e[0m'
CYN='\e[36m'

BOLD='\e[1m'
FAINT='\e[2m'
ITALIC='\e[3m'
ULINE='\e[4m'

# these can be combinations of colour and effect eg: $BOLD$RED
ERRCOL="$RED"
WARNCOL=$YEL

# Mirror addresses
UBUNTU16_MIRROR="http://81.138.92.138:8080"
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
                    cp -p ~/$PROG ~/$PROG.prev && chmod 644 ~/$PROG.prev && mv ~/$PROG.new ~/$PROG && chmod 755 ~/$PROG && $ECHO "\n${GRN}Now run $PROG again${END}\n" && exit 250
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


if [ `id -u` -ne 0 ] ; then
    echo "NC Support Tool - v$VER"
    echo "$PROG: will be run as root"
    sudo bash -i $0 $*
    exit $?
fi

################################################################################
#           These variables in this section may need to be tweaked             #
################################################################################

# ca.truststore.jks sums for different NC versions
declare -A CA_TRUSTSTORE_SUMS_ARRAY
CA_TRUSTSTORE_SUMS_ARRAY[5.]="2134ca928a2f20fba0ccf2abdd2302a7"
CA_TRUSTSTORE_SUMS_ARRAY[6.]="4b6c495dfa8091307dba0b8c15ab3678"
CA_TRUSTSTORE_SUMS_ARRAY[7.0.]="79f01c59147f2fac42a26514130641f7"
CA_TRUSTSTORE_SUMS_ARRAY[7.1.]="79f01c59147f2fac42a26514130641f7"
CA_TRUSTSTORE_SUMS_ARRAY[7.2.]="643310239ae4ac31a90e8de324548c23"
CA_TRUSTSTORE_SUMS_ARRAY[8.0.]="3d3a99771487673b77c217864efd9720"

# MySQLdump script name and version
MYSQLDUMP_SCRIPT=mysqlbackup.sh
MYSQLDUMP_SCRIPT_VERSION="1.0"

# Kernel versions against Ubuntu versions - will need to be kept up to date
declare -A KERNEL_VERSION_ARRAY
KERNEL_VERSION_ARRAY[16.04.6]="4.4.0-170-generic"
KERNEL_VERSION_ARRAY[20.04.2]="5.4.0-80-generic"
KERNEL_VERSION_ARRAY[20.04.4]="5.4.0-113-generic"
KERNEL_VERSION_ARRAY[20.04.5]="5.4.0-139-generic"
#KERNEL_VERSION_ARRAY[20.04.6]="5.4.0-155-generic"
KERNEL_VERSION_ARRAY[20.04.6]="5.4.0-169-generic"

# Values are in GibiBytes!!!
# NC and MySQL RAM allocations arrays for a dedicated server for the purpose
declare -a NC_MEMORY_ARRAY
NC_MEMORY_ARRAY[64]="49"
NC_MEMORY_ARRAY[32]="23"
NC_MEMORY_ARRAY[16]="11"
NC_MEMORY_ARRAY[8]="6"
NC_MEMORY_ARRAY[4]="2"

declare -a DB_MEMORY_ARRAY
DB_MEMORY_ARRAY[64]="51"
DB_MEMORY_ARRAY[32]="24"
DB_MEMORY_ARRAY[16]="11"
DB_MEMORY_ARRAY[8]="5"
DB_MEMORY_ARRAY[4]="2"

# NC and MySQL RAM allocations arrays for a combo (single server)
declare -a NC_COMBO_MEMORY_ARRAY
NC_COMBO_MEMORY_ARRAY[64]="21"
NC_COMBO_MEMORY_ARRAY[32]="9"
NC_COMBO_MEMORY_ARRAY[16]="5"
NC_COMBO_MEMORY_ARRAY[8]="3"
NC_COMBO_MEMORY_ARRAY[4]="2"

declare -a DB_COMBO_MEMORY_ARRAY
DB_COMBO_MEMORY_ARRAY[64]="32"
DB_COMBO_MEMORY_ARRAY[32]="16"
DB_COMBO_MEMORY_ARRAY[16]="6"
DB_COMBO_MEMORY_ARRAY[8]="3"
DB_COMBO_MEMORY_ARRAY[4]="1"

# standard OS files
SOURCES=/etc/apt/sources.list
SECURITY_LIMITS=/etc/security/limits.conf
NERVECENTRE_FILE_LIMITS=/etc/security/limits.d/nervecentre.conf
XTRABACKUP_FILE_LIMITS=/etc/security/limits.d/xtrabackup.conf
NTPCONF=/etc/ntp.conf
CHRONYCONF=/etc/chrony/chrony.conf
HOSTS_FILE=/etc/hosts
INTERFACES_FILE=/etc/network/interfaces
RESOLVCONF=/etc/resolv.conf
SSHD_CONFIG=/etc/ssh/sshd_config
PASSWD_FILE=/etc/passwd
LOCALBINDIR=/usr/local/bin
DEFAULT_SYSSTAT=/etc/default/sysstat
SYSSTAT_CRON=/etc/cron.d/sysstat

# standard NC variables and paths etc
NCDIR=/usr/local/nc
NCACTIVEDIR=$NCDIR/nervecentre
LOG_DIR=$NCACTIVEDIR/logs
NCUSER=nervecentreadm
NCHOME=/home/nervecentreadm
# so I can get this machine's IP address and the DR IP address
PROPSFILE=$NCDIR/custdata/customconf/nervecentre.props
NCCONF=$NCDIR/custdata/init/nervecentre.conf
NCCONFDEF=$NCDIR/nervecentre/init/nervecentre.conf
NC_CERTS_DIR=$NCDIR/custdata/Certs
DEFAULT_NC_CERTS_DIR=$NCACTIVEDIR/NCCerts
CA_TRUSTSTORE_JKS=ca.truststore.jks

# MySQL/DB variables
MYCNF=/etc/mysql/my.cnf
MYSQLDCNF=/etc/mysql/mysql.conf.d/mysqld.cnf
# Xtrabackup variables
XTRABACKUP_SCRIPT=ncxtrabackup.sh
DBBACKUPS_DIR=/usr/local/nc/dbbackups
ENCRYPTION_KEY_FILE=$DBBACKUPS_DIR/encryption_key

# Zookeeper and Kafka variables
NCZOOKAF_SCRIPT=nczookaf.sh
ZOOKEEPER_HOME=/opt/zookeeper
ZOOKEEPER_CONFIG=$ZOOKEEPER_HOME/conf/zoo.cfg
KAFKA_HOME=/opt/kafka
KAFKA_CONFIG=$KAFKA_HOME/config/server.properties
ZK_CERTS_DIR=/etc/nervecentre/certificates
KKLATESTVERSION="3.6.0"
ZKLATESTVERSION="3.8.3"

SERVERCONFIGS_DIR=$NCHOME/serverconfigs/

# for development/testing purposes - remove or comment out in production
if [ $(hostname) = "mint20" ] ; then
    LOG_DIR=/home/richard/NC/nclogs
    PROPSFILE=/home/richard/NC/misc_stuff/oneline.props
fi

# extract DR IP address from the Disaster Recovery Database Connection String variable
if [ -r $PROPSFILE ] ; then
    DR_DB_STRING=$(grep ^DisasterRecoveryDatabaseConnString $PROPSFILE |awk -F= '{print $2}')
fi
DR_DB_STRING_PART=${DR_DB_STRING#*//}
DR_IP_ADDRESS=${DR_DB_STRING_PART%%/ncdb*}
VALID_DR_IP_ADDRESS=$(echo $DR_IP_ADDRESS |grep "[1-9].*\.[0-9].*\.[0-9].*\.[1-9].*")
if [ ! "$VALID_DR_IP_ADDRESS" ] ; then
    DR_IP_ADDRESS="cannot find DR server IP address"
fi

# Our scripts - site may not have all
SCRIPTS="ncsupport.sh nccertadmin.sh ncxtrabackup.sh nczookaf.sh prepare_for_os_patch.sh update_mysql_config.sh"

# User accounts considered redundant and should be removed
# DO NOT (I repeat DO NOT) add nervecentreadm to this list
REDUNDANT_ACCOUNTS="ncnetworksetup ncprovision"

# Accounts to ignore when checking for non-chrooted users
IGNORE_ACCOUNT_LIST="$NCUSER ubuntu nxautomation"

# add log names to array below
LOGS_ARRAY=("ncerrors.log*" "nc.log*" "ncstartup.log*" "nchl7*" "ncapnmonitor.log*" "ncchannels.log*" "ncmonitoring.log*" "mesh/*" "ncletters.log*" "jetty-*")

# file size for the health check find command (k, M or G as suffix)
FIND_FILE_SIZE=2G

# maximum percentage of Swap usage allowed
SWAP_PERCENT_USED_MAX=25
# maximum amount of swap that a single process can consume in kB
MAX_SWAP_FOR_SINGLE_PROCESS_KB=500000

# new max devices allowed value
NEW_MAX_DEVICES=10000

# Time zones allowed
TIME_ZONES_LIST="Europe/London Europe/Dublin"

# Maximum number of days a certificate can be valid for (End - Start)
MAX_VALIDITY=397

# This value is always returned when a VM is running on the Azure platform
AZURE_ASSET_TAG="7783-7084-3265-9085-8269-3286-77"

################################################################################

##### Functions #####
create_or_update_bash_aliases()
{
    BASH_ALIASES=$NCHOME/.bash_aliases
    OLD_BASH_ALIASES=/tmp/${NCUSER}.bash_aliases.old
    if [ ! -r $BASH_ALIASES ] ; then
        echo "Creating $BASH_ALIASES ..."
        print_aliases_header > $BASH_ALIASES
    else
        # check if we're at Version 2 of the aliases file
        VERSION2=$(grep 'Version 2' $BASH_ALIASES)
        if [ ! "$VERSION2" ] ; then # upgrade aliases to Version 2
            echo "Adding header to $BASH_ALIASES ..."
            mv $BASH_ALIASES $OLD_BASH_ALIASES
            print_aliases_header > $BASH_ALIASES
            egrep -v "^#.*" $OLD_BASH_ALIASES >> $BASH_ALIASES
            rm -f $OLD_BASH_ALIASES
        fi
    fi
    add_missing_aliases
    if [ "$UPDATED_AN_ALIAS" -o "$UPDATED_A_FUNCTION" ] ; then
        $ECHO "${BOLD}Aliases/functions have been updated - log out and back in again to use them${END}"
    fi
    chown ${NCUSER}: $BASH_ALIASES
}
print_aliases_header()
{
    echo "# Aliases to make our lives just a little easier
# Nervecentre Software Ltd
# RHowlett 01/06/2023
# Version 2"
}
add_missing_aliases()
{
    # Maintains a set of aliases and functions.
    # If the definition of an alias or function changes this code will detect it, remove the current line and write the new line to the file.
    # A definition of "DELETE" will allow us to remove aliases or functions we don't want anymore.

    # Associative arrays are stored in hash order so to process in insertion order we need to store the keys in an indexed array
    # If a new alias is added REMEMBER to add to both arrays
    ALIAS_ORDER_ALL=(bigfiles cdcerts ncsqldump ncrestart ncdisableprovisioning)
    ALIAS_ORDER_NC=(cdnc cdlogs cdconf lessprops followncstartup ncstart ncstop ncenable ncdisable ncstatus)
    ALIAS_ORDER_DB=(ncsql sqlstart sqlstop sqlenable sqldisable sqlstatus)
    ALIAS_ORDER_ZK=(kafstart kafstop kafenable kafdisable kafstatus zoostart zoostop zooenable zoodisable zoostatus)
    declare -A ALIAS_ARRAY
    ALIAS_ARRAY["bigfiles"]+='sudo find / -type f -size +1G 2>/dev/null'
    ALIAS_ARRAY["cdnc"]+="cd /usr/local/nc"
    ALIAS_ARRAY["cdlogs"]+="cd /usr/local/nc/nervecentre/logs"
    ALIAS_ARRAY["cdconf"]+="cd /usr/local/nc/custdata/customconf"
    if [ "$NC" ] ; then
        ALIAS_ARRAY["cdcerts"]+="cd /usr/local/nc/custdata/Certs"
    elif [ "$ZK" ] ; then
        ALIAS_ARRAY["cdcerts"]+="cd /etc/nervecentre/certificates"
    else
        ALIAS_ARRAY["cdcerts"]+="DELETE"
    fi
    ALIAS_ARRAY["lessprops"]+="less /usr/local/nc/custdata/customconf/nervecentre.props"
    ALIAS_ARRAY["followncstartup"]+="tail -n 100 -F /usr/local/nc/nervecentre/logs/ncstartup.log"
    ALIAS_ARRAY["ncstart"]+="sudo systemctl start nervecentre.service"
    ALIAS_ARRAY["ncstop"]+="sudo systemctl stop nervecentre.service"
    ALIAS_ARRAY["ncenable"]+="sudo systemctl enable nervecentre.service"
    ALIAS_ARRAY["ncdisable"]+="sudo systemctl disable nervecentre.service"
    ALIAS_ARRAY["ncstatus"]+="sudo systemctl status nervecentre.service"
    ALIAS_ARRAY["ncsql"]+="mysql -u root -p ncdb"
    ALIAS_ARRAY["sqlstart"]+="sudo systemctl start mysql.service"
    ALIAS_ARRAY["sqlstop"]+="sudo systemctl stop mysql.service"
    ALIAS_ARRAY["sqlenable"]+="sudo systemctl enable mysql.service"
    ALIAS_ARRAY["sqldisable"]+="sudo systemctl disable mysql.service"
    ALIAS_ARRAY["sqlstatus"]+="sudo systemctl status mysql.service"
    ALIAS_ARRAY["kafstart"]+="sudo systemctl start kafka.service"
    ALIAS_ARRAY["kafstop"]+="sudo systemctl stop kafka.service"
    ALIAS_ARRAY["kafenable"]+="sudo systemctl enable kafka.service"
    ALIAS_ARRAY["kafdisable"]+="sudo systemctl disable kafka.service"
    ALIAS_ARRAY["kafstatus"]+="sudo systemctl status kafka.service"
    ALIAS_ARRAY["zoostart"]+="sudo systemctl start zookeeper.service"
    ALIAS_ARRAY["zoostop"]+="sudo systemctl stop zookeeper.service"
    ALIAS_ARRAY["zooenable"]+="sudo systemctl enable zookeeper.service"
    ALIAS_ARRAY["zoodisable"]+="sudo systemctl disable zookeeper.service"
    ALIAS_ARRAY["zoostatus"]+="sudo systemctl status zookeeper.service"
# and now ones we don't want anymore which get the special DELETE definition
    ALIAS_ARRAY["ncsqldump"]+="DELETE"                              # mysqldump -u root -p ncdb
    ALIAS_ARRAY["ncrestart"]+="DELETE"                              # sudo systemctl restart nervecentre.service
    ALIAS_ARRAY["ncdisableprovisioning"]+="DELETE"                  # sudo gpasswd --delete ncprovision sudo ; sudo chage -E0 ncprovision"

    # Update aliases that are appropriate for the system type
    UPDATED_AN_ALIAS=
    for x in "${ALIAS_ORDER_ALL[@]}" ; do
        update_alias $x
    done
    if [ "$NC" ] ; then
        for x in "${ALIAS_ORDER_NC[@]}" ; do
            update_alias $x
        done
    fi
    if [ "$DB" ] ; then
        for x in "${ALIAS_ORDER_DB[@]}" ; do
            update_alias $x
        done
    fi
    if [ "$ZK" ] ; then
        for x in "${ALIAS_ORDER_ZK[@]}" ; do
            update_alias $x
        done
    fi
    # Delete aliases that shouldn't be there because they are on the wrong system type
    if [ ! "$NC" ] ; then
        for x in "${ALIAS_ORDER_NC[@]}" ; do
            delete_alias $x
        done
    fi
    if [ ! "$DB" ] ; then
        for x in "${ALIAS_ORDER_DB[@]}" ; do
            delete_alias $x
        done
    fi
    if [ ! "$ZK" ] ; then
        for x in "${ALIAS_ORDER_ZK[@]}" ; do
            delete_alias $x
        done
    fi

    # functions have to be all on one line so there could be some VERY long lines here!
    FUNCTION_ORDER=(getscript)
    declare -A FUNCTION_ARRAY
    FUNCTION_ARRAY["getscript"]+='{ SOURCES=/etc/apt/sources.list; grep -sq ncepr.co.uk $SOURCES || (echo -e "Error - $SOURCES does not contain our mirror\nRun: ./prepare_for_os_patch.sh 2"; return 72) && case $1 in ncc*) S=nccertadmin.sh;; ncs*) S=ncsupport.sh;; pre*) S=prepare_for_os_patch.sh;; upd*) S=update_mysql_config.sh;; ncx*) S=ncxtrabackup.sh;; ncz*) S=nczookaf.sh;; sav*) S=save_grants.sh;; *) echo -e "Error - need a script name:\nncsupport.sh\nnccertadmin.sh\nprepare_for_os_patch.sh\nupdate_mysql_config.sh\nncxtrabackup.sh\nnczookaf.sh\nsave_grants.sh"; return 24;; esac && wget -O ~/$S $(egrep -o http.*\.uk $SOURCES |head -n 1)/scripts/$S && chmod 755 ~/$S; }'
    UPDATED_A_FUNCTION=
    for x in "${FUNCTION_ORDER[@]}" ; do
        # -F flag tells grep to treat the pattern as a fixed string and ignore special characters
        if [ ! "$(grep -F "function $x() ${FUNCTION_ARRAY[$x]}" $BASH_ALIASES)" ] ; then  # if function not exactly as in array
            sed -i "/function $x() /d" $BASH_ALIASES                                      # remove old function from file
            if [ "${FUNCTION_ARRAY[$x]}" != "DELETE" ] ; then
                echo "function $x() ${FUNCTION_ARRAY[$x]}" >> $BASH_ALIASES && echo "Updated $x function"    # add function to end of file
                UPDATED_A_FUNCTION=Y
            fi
        fi
    done
}
update_alias()
{
    # $1 is the alias from the for loop
    # -F flag tells grep to treat the pattern as a fixed string and ignore special characters
    if [ ! "$(grep -F "alias $1='${ALIAS_ARRAY[$1]}'" $BASH_ALIASES)" ] ; then  # if alias not exactly as in array
        sed -i "/alias $1=/d" $BASH_ALIASES                                     # remove old alias from file
        if [ "${ALIAS_ARRAY[$1]}" != "DELETE" ] ; then
            echo "alias $1='${ALIAS_ARRAY[$1]}'" >> $BASH_ALIASES && echo "Updated $1 alias"    # add alias to end of file
            UPDATED_AN_ALIAS=Y
        fi
    fi
}
delete_alias()
{
    # $1 is the alias from the for loop
    # -F flag tells grep to treat the pattern as a fixed string and ignore special characters
    if [ "$(grep -F "alias $1=" $BASH_ALIASES)" ] ; then  # if alias exists
        sed -i "/alias $1=/d" $BASH_ALIASES               # remove alias from file silently - it shouldn't be there
    fi
}

remove_old_redundant_scripts()
{
    # We don't need these scripts so remove them
    SCRIPTS_DELETE_LIST="prepare-for-os-patch.sh NCpatchv2.1.sh NCpatchv6.sh directmirror.py meta-source-update.sh meta-source-update-https.sh mirrorready.py"
    for SCRIPT in $SCRIPTS_DELETE_LIST ; do
        [ -r $NCHOME/$SCRIPT ] && rm -f $NCHOME/$SCRIPT
    done
}

chmod_755_scripts()
{
    for SCRIPT in $SCRIPTS ; do
        [ -r $NCHOME/$SCRIPT -a ! -x $NCHOME/$SCRIPT ] && chmod 755 $NCHOME/$SCRIPT
        # whilst we're here make sure the .prev backups of the scripts automatically pulled down from mirror are not executable
        [ -r $NCHOME/${SCRIPT}.prev -a -x $NCHOME/${SCRIPT}.prev ] && chmod -x $NCHOME/${SCRIPT}.prev
    done
}

remove_redundant_user_accounts()
{
    for ACCOUNT in $REDUNDANT_ACCOUNTS ; do
        if [ $ACCOUNT != $NCUSER ] ; then      # make sure we don't remove nervecentreadm !!!
            [ -d /home/$ACCOUNT ] && deluser --remove-home $ACCOUNT >/dev/null && echo "Removed redundant user account: $ACCOUNT"
        fi
    done
}

move_open_file_limits_to_new_file()
{
    # if the open file limits are in the original file and not in the new file then delete from original
    # and write out the lines to the new file. This will only be triggered once.
    # If the lines do not exist in either then do nothing and let the healthcheck find and fix the issue.
    FILE_LIMITS_OLD=$(grep -E "^\* (hard nofile|soft nofile) 100000$" $SECURITY_LIMITS |wc -l)
    FILE_LIMITS_NEW=$(grep -E "^\* (hard nofile|soft nofile) 100000$" $NERVECENTRE_FILE_LIMITS 2>/dev/null |wc -l)
    #echo "Old: $FILE_LIMITS_OLD, New: $FILE_LIMITS_NEW"
    if [ "$FILE_LIMITS_OLD" -gt 0 -a "$FILE_LIMITS_NEW" -eq 0 ] ; then
        sed -i '/* \(soft\|hard\) nofile/d' $SECURITY_LIMITS && \
        echo -e "* soft nofile 100000\n* hard nofile 100000" > $NERVECENTRE_FILE_LIMITS
    fi
}


# remove leading and trailing whitespace characters
trim()
{
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"   
    printf '%s' "$var"
}

# function to get input from user (usually y/n or q)
getres()
{
    echo
    $ECHO -n "$1"
    read res
    if [ "$res" = "Q" -o "$res" = "q" ] ; then
        res=q   # always return lowercase q if Q entered - we only check for lowercase q
    else
        case "$2" in            # check 2nd parameter
            l*) res=${res,,}    # if "lowercase" convert anything entered to lowercase
                ;;
            u*) res=${res^^}    # if "uppercase" convert anything entered to uppercase
                ;;
            p*) res=${res^}     # if "pretty" convert to initial capital, rest lowercase
                ;;
        esac
    fi
}


# get hostname or IP address of the server creating the logs
get_this_host()
{
    THIS_HOSTNAME=$(hostname -s)
    if [ "$THIS_HOSTNAME" ] ; then
        THIS_HOST=$THIS_HOSTNAME
    else
        if [ -r $PROPSFILE ] ; then
            THIS_IP_ADDRESS=$(grep ^LocalAddress $PROPSFILE |awk -F= '{print $2}')
        fi
        if [ "$THIS_IP_ADDRESS" ] ; then
            THIS_HOST=$THIS_IP_ADDRESS
        else
            THIS_IP_ADDRESS=$(hostname -I | awk '{print $1}')
            case $THIS_IP_ADDRESS in
            [1-9].*\.[0-9].*\.[0-9].*\.[1-9].*)
                THIS_HOST=$THIS_IP_ADDRESS
                ;;
            ""|*) THIS_HOST=UnknownHost
                ;;
            esac
        fi
    fi
    echo $THIS_HOST
}

####################################################################################################
# Save logs for troubleshooting
###############################

save_logs_for_troubleshooting()
{
    real_save_logs_for_troubleshooting
    $ECHO -n "\nPress Enter to continue "
    read res
}
real_save_logs_for_troubleshooting()
{
    STAT=0
    get_log_file_list   ; [ "$LOG_FILES_SELECTED" = "q" ] && return
    get_ticket_number   ; [ "$TICKET_NUMBER" = "q" ] && return
    get_log_destination ; [ "$DEST_SERVER" = "q" ] && return
    if [ $STAT -ne 0 ] ; then
        return
    fi
# got all the information we need now
    TICKET_NUMBER_AND_HOST=Ticket-${TICKET_NUMBER}_${THIS_HOST}
    TAR_FILE=$NCHOME/$TICKET_NUMBER_AND_HOST.tgz

    if [ $DEST_SERVER != "none" ] ; then
        $ECHO "\nCreating tar file: ${BOLD}$TAR_FILE${END}
containing logs  : ${BOLD}$LOG_FILES_SELECTED${END}
and sending to   : ${BOLD}$DEST_SERVER${END}"
    else
        $ECHO "\nCreating tar file: ${BOLD}$TAR_FILE${END}
containing logs  : ${BOLD}$LOG_FILES_SELECTED${END}"
    fi

    CONTINUE=
    while [ ! "$CONTINUE" ] ; do
        getres "Continue? (y/n): " lowercase
        case $res in
            q)  CONTINUE=q
                ;;
           "")  $ECHO "${ERRCOL}Error - need a y/n answer${END}"
                CONTINUE=
                ;;
            *)  CONTINUE=$res
                ;;
        esac
    done
    if [ "$CONTINUE" = "y" ] ; then
        create_tar_file
        if [ $DEST_SERVER != "none" ] ; then
            save_logs_to_server
            if [ $STAT -eq 0 ] ; then
                show_extract_command
            fi
        fi
    fi
}

# get list of files to save
get_log_file_list()
{
    LOG_FILES_SELECTED=
    while [ ! "$LOG_FILES_SELECTED" ] ; do
        # pre-read to get the count of each log file to build the total for 0/All option
        ALL_LOGS_FILE_COUNT=0
        LONGEST_LOG_NAME=16         # set to 16 initially because this is the length of the string "All groups below"
        LONGEST_DIGIT_COUNT=0
        for LOG_FILE in ${LOGS_ARRAY[@]} ; do
            FILE_COUNT=$(ls $LOG_DIR/$LOG_FILE 2>/dev/null |wc -l)
            (( ALL_LOGS_FILE_COUNT = $ALL_LOGS_FILE_COUNT + $FILE_COUNT ))
            LOG_NAME_LENGTH=$(echo $LOG_FILE |awk ' { if ( length > x ) { x = length } }END{ print x }')
            if [ $LOG_NAME_LENGTH -gt $LONGEST_LOG_NAME ] ; then
                LONGEST_LOG_NAME=$LOG_NAME_LENGTH
            fi
            DIGIT_COUNT=$(echo $FILE_COUNT |awk ' { if ( length > x ) { x = length } }END{ print x }')
            if [ $DIGIT_COUNT -gt $LONGEST_DIGIT_COUNT ] ; then
                LONGEST_DIGIT_COUNT=$DIGIT_COUNT
            fi
        done
        ALL_LOGS_FILE_SIZES=$(cd $LOG_DIR ; du -cm ${LOGS_ARRAY[@]} 2>/dev/null |grep total |awk '{print $1}')
        # this will always be the number of digits in the total file size which makes life easier
        LONGEST_FILE_SIZE=$(echo $ALL_LOGS_FILE_SIZES |awk ' { if ( length > x ) { x = length } }END{ print x }')

        COUNT=0
        $ECHO "\nSelect log file types to save:\n"
        printf "   %2s. %-${LONGEST_LOG_NAME}s  %${LONGEST_DIGIT_COUNT}s %-5s - %${LONGEST_FILE_SIZE}s MB\n" 0 "All groups below" $ALL_LOGS_FILE_COUNT "files" $ALL_LOGS_FILE_SIZES
        for LOG_FILE in ${LOGS_ARRAY[@]} ; do   # display the array preceeded by an incrementing number
            (( COUNT = $COUNT + 1 ))
            FILE_COUNT=$(ls $LOG_DIR/$LOG_FILE 2>/dev/null |wc -l)
            if [ $FILE_COUNT -eq 1 ] ; then
                FILE_TEXT=file
            else
                FILE_TEXT=files
            fi
            FILE_SIZES=$(du -cm $LOG_DIR/$LOG_FILE 2>/dev/null |grep total |awk '{print $1}')
            printf "   %2s. %-${LONGEST_LOG_NAME}s  %${LONGEST_DIGIT_COUNT}s %-5s - %${LONGEST_FILE_SIZE}s MB\n" $COUNT $LOG_FILE $FILE_COUNT $FILE_TEXT $FILE_SIZES
        done

        INVALID_ENTRY=
        getres "Enter log groups to save. For multiple groups separate by a space (eg 1 2 3)\n'all' for all log groups or q to quit: " lowercase
        case $res in
            q)  LOG_FILES_SELECTED=q
                ;;
         0|a*)  LOG_FILES_SELECTED=${LOGS_ARRAY[@]}
                LOG_FILE_COUNT=$ALL_LOGS_FILE_COUNT
                ;;
           "")  $ECHO "${ERRCOL}Error - no logs selected${END}"
                INVALID_ENTRY=Y
                ;;
            *)  for INDEX in $res ; do  # retrieve the logs picked from the array
                    if [ "$INDEX" -eq "$INDEX" ] 2>/dev/null ; then
                        if [ $INDEX -gt ${#LOGS_ARRAY[@]} ] ; then
                            $ECHO "${ERRCOL}Error - invalid log number chosen: $INDEX${END}"
                            INVALID_ENTRY=Y
                        elif [ $INDEX -eq 0 ] ; then
                            $ECHO "${WARNCOL}Error - ignoring 0 (for all logs) in the log file list${END}"
                        else
                            (( ARRINDEX = $INDEX - 1 )) # arrays start at 0 not 1 so subtract 1 to access array
                            LOG_FILES_SELECTED="$LOG_FILES_SELECTED${LOGS_ARRAY[$ARRINDEX]} "
                        fi
                    else
                        $ECHO "${ERRCOL}Error - invalid log number chosen: $INDEX${END}"
                        INVALID_ENTRY=Y
                    fi
                done
                ;;
        esac
        if [ "$INVALID_ENTRY" ] ; then  # if we have had an invalid entry clear the list
            LOG_FILES_SELECTED=
        fi
        if [ "$LOG_FILES_SELECTED" -a "$LOG_FILES_SELECTED" != "q" ] ; then
            $ECHO "\nLog files selected  : $LOG_FILES_SELECTED"
            LOG_FILE_COUNT=$(cd $LOG_DIR ; ls -1 $LOG_FILES_SELECTED | wc -l)
            $ECHO "Log file count      : $LOG_FILE_COUNT files"
            SPACE_REQUIRED=$(cd $LOG_DIR ; du -ch $LOG_FILES_SELECTED | tail -n 1 |awk '{print $1}')
            SPACE_AVAILABLE=$(df --output=avail -BM / | tail -n 1)
            printf "%-22s %7s\n" "Disk space required :" $SPACE_REQUIRED
            printf "%-22s %7s\n" "Disk space available:" $SPACE_AVAILABLE
        fi
    done
}
# get ticket number
get_ticket_number()
{
    TICKET_NUMBER=
    while [ ! "$TICKET_NUMBER" ] ; do
        getres "Enter Support Ticket number or q to quit: "
        case $res in
            q)  TICKET_NUMBER=q
                ;;
           "")  $ECHO "${ERRCOL}Error - ticket number required${END}"
                TICKET_NUMBER=
                ;;
            *)  if [ "$res" -eq "$res" ] 2>/dev/null ; then     # integer check
                    if [ $res -gt 100000 ] ; then               # check it's at least 6 digits
                        TICKET_NUMBER=$res                      # it's passed the checks - yay
                    else
                        $ECHO "${ERRCOL}Error - ticket number must be at least 6 digits${END}"
                    fi
                else
                    $ECHO "${ERRCOL}Error - ticket number must be an integer number${END}"
                fi
                ;;
        esac
    done
}
# ask where to save the logs to
get_log_destination()
{
    DEST_SERVER=
    while [ ! "$DEST_SERVER" ] ; do
        $ECHO "\nWhere should the logs go?\n"
        echo "    1. DR server ($DR_IP_ADDRESS)"
        echo "    2. Another server (IP address required)"
        echo "    3. Keep on this machine"
        getres "Select an option or q to quit: "
        case $res in
            q)  DEST_SERVER=q
                ;;
           "")  $ECHO "${ERRCOL}Error - need a destination${END}"
                ;;
            1)  if [ ! "$VALID_DR_IP_ADDRESS" ] ; then
                    $ECHO "${ERRCOL}Error - cannot extract DR server IP address from props file${END}"
                    DEST_SERVER=    # ask where the logs should go again
                else
                    DEST_SERVER=$DR_IP_ADDRESS
                fi
                ;;
            2)  get_dest_server
                ;;
            3)  DEST_SERVER=none
                ;;
        esac
    done
    if [ "$DEST_SERVER" != "q" -a "$DEST_SERVER" != "none" ] ; then
        echo -e "\nChecking disk space on $DEST_SERVER ..."
        SPACE_AVAILABLE=$(sudo -u $NCUSER ssh $NCUSER@$DEST_SERVER 'df --output=avail -BM / | tail -n 1')
        STAT=$?
        if [ $STAT -ne 0 ] ; then
            $ECHO "\n${RED}There was a problem checking disk space on $DEST_SERVER${END}"
        else
            printf "%-29s %7s\n" "Remote disk space required :" $SPACE_REQUIRED
            printf "%-29s %6s\n" "Remote disk space available:" $SPACE_AVAILABLE
        fi
    fi
}
# if not the DR server then where?
get_dest_server()
{
    DEST_SERVER=
    while [ ! "$DEST_SERVER" ] ; do
        getres "Enter IP address or q to quit: "
        case $res in
            q)  DEST_SERVER=q
                ;;
           "")  $ECHO "${ERRCOL}Error - need an IP address${END}"
                DEST_SERVER=
                ;;
            *)  DEST_SERVER=$res
                PINGABLE=$(ping -c 1 $DEST_SERVER)
                if [ $? -ne 0 ] ; then
                    $ECHO "${ERRCOL}Error - $DEST_SERVER is not pingable${END}"
                    DEST_SERVER=
                fi
                ;;
        esac
    done
}

# create the tar file
create_tar_file()
{
    $ECHO "\nCreating tar file: $TAR_FILE ..."
    cd $LOG_DIR
    tar zcf $TAR_FILE $LOG_FILES_SELECTED
    cd $OLDPWD      # return to previous directory to stop ugly file glob issues
}

# send the log onto the chosen server
save_logs_to_server()
{
    $ECHO "\nSending logs to $DEST_SERVER ..."
    COMMAND="scp $TAR_FILE $NCUSER@$DEST_SERVER:$NCHOME"
    echo "$COMMAND"
    if [ $(hostname) != "mint20" ] ; then
        sudo -u $NCUSER $COMMAND
        STAT=$?
    else
        echo "WOULD RUN THIS: $COMMAND"
        STAT=0
    fi
    if [ $STAT -eq 0 ] ; then
        $ECHO "\n${GRN}Logs successfully sent to $DEST_SERVER${END}"
    else
        $ECHO "\n${RED}There was a problem sending the logs to $DEST_SERVER${END}"
    fi
    
    $ECHO "\nRemoving local copy of $TAR_FILE ..."
    COMMAND="rm -f $TAR_FILE"
    echo "$COMMAND"
    if [ $(hostname) != "mint20" ] ; then
        $COMMAND
    else
        echo "WOULD RUN THIS: $COMMAND"
    fi
}

# show SE the command to run on DR server to extract the contents of the tar file
show_extract_command()
{
    $ECHO "
============================================================

Log on to ${BOLD}$DEST_SERVER${END} and run the command below to extract the contents of the tar file:

${BOLD}mkdir ~/$TICKET_NUMBER_AND_HOST 2>/dev/null ; cd ~/$TICKET_NUMBER_AND_HOST ; tar xvf $TAR_FILE${END}

============================================================"
}

####################################################################################################
# Health check
##############

health_check()
{
    $ECHO "\nRunning health checks ...\n"
    HEALTH_CHECK_REPORT_NAME=/tmp/healthcheck_${THIS_HOST}_$(date +%Y-%m-%d_%H-%M-%S)
    real_health_check | tee $HEALTH_CHECK_REPORT_NAME
    $ECHO -n "\nPress Enter to continue "
    read res
}

health_check_quick()
{
    $ECHO "\nRunning health checks (no disk speed or big files checks) ...\n"
    HEALTH_CHECK_REPORT_NAME=/tmp/healthcheck_${THIS_HOST}_$(date +%Y-%m-%d_%H-%M-%S)
    real_health_check --quick | tee $HEALTH_CHECK_REPORT_NAME
    $ECHO -n "\nPress Enter to continue "
    read res
}

real_health_check()
{
    DISK_SPEED_CHECK_ENABLED=Y
    FIND_BIG_FILES_ENABLED=Y
    case "$1" in
       --quick) DISK_SPEED_CHECK_ENABLED=
                FIND_BIG_FILES_ENABLED=
                ;;
    esac

    # set STAT before the collect_information function is run as this now increments this variable too
    STAT=0

    collect_information
    display_information

    echo

    # Run checks

    check_system_memory_amount
    check_swap_memory_usage
    check_load_average
    check_virtual_tools_available
    check_sar_available
    check_disk_available
    check_open_file_limits
    check_for_non_chrooted_users
    check_omi_version
    check_time_sync_service
    check_time_is_synced
    check_time_sync_not_using_pools
    check_mirror
    check_hosts_file
    check_interfaces_file
    check_dns_operation
    check_reverse_dns_operation
    check_disk_write_speed
    check_for_big_files

    if [ ! "$NC" -a ! "$DB" -a ! "$ZK" ] ; then    # if no flags set then it's not a server we should be running this on really!
        $ECHO "\nThis system is not a Nervecentre App, DB or Zookeeper/Kafka server"
        $ECHO "so no further Health Checks are appropriate"
    fi

    if [ "$NC" ] ; then
        check_nervecentre_conf_file_contents
        check_nc_memory
        check_nc_service_status
        check_curl
        check_ssl_cert_nc
        check_nc_connected_to_db
        check_apple_push_port
        check_android_push_port
        check_maxdevicesperserver
        check_fonts_on_reporting_servers
        check_for_oom_in_logs
        check_for_heap_dumps
        check_old_installs
    fi

    if [ "$DB" ] ; then
        check_mysql_using_std_config
        check_db_memory
        check_mysql_service_status
        check_mysql_is_listening
        check_xtrabackup_or_mysqldump_or_none
        if [ "$BACKUP_METHOD" = "XTRABACKUP" ] ; then
            check_xtrabackup_script_version
            check_xtrabackup_installation
            check_xtrabackup_backups
        elif [ "$BACKUP_METHOD" = "MYSQLDUMP" ] ; then
            check_mysqldump_script_version
            check_mysqldump_using_dump_replica_switch
            check_mysqldump_backups
        fi
    fi

    if [ "$ZK" ] ; then
        check_nczookaf_version
        if [ "$NCZOOKAF_SCRIPT_STATUS" = "HASLATEST" ] ; then
            check_broker_status
            check_red_box_config
            check_replication_factor
        else
            $ECHO "${RED}Download $NCZOOKAF_SCRIPT to enable other Zookeeper/Kafka checks${END}"
        fi
        check_ssl_cert_zookaf
    fi

    if [ $STAT -gt 0 ] ; then
        $ECHO "\nIssues detected: $STAT"
    fi
    $ECHO "\nReport saved as: $HEALTH_CHECK_REPORT_NAME"
}

collect_information()
{
    # Collect information
    UBUNTUVERSION=$(lsb_release -a 2>/dev/null |grep Description |awk -F':' '{print $2}')
    KERNELVERSION=$(uname -r)

    CPUS=$(grep processor </proc/cpuinfo |wc -l)
    CPU_MODEL=$(lscpu |grep "Model name" |awk -F'name:' '{print $2}')
    CPU_MODEL=$(trim $CPU_MODEL)
    ALL_MEMORY_INFO=$(< /proc/meminfo)

    MEMORY_KB=$(grep MemTotal <<< $ALL_MEMORY_INFO |awk '{print $2}')
    MEMORY=$(awk '{val = $1 / 1024000; printf "%2.0f\n", val}' <<< $MEMORY_KB)
    MEMORY_FREE_KB=$(grep MemFree <<< $ALL_MEMORY_INFO |awk '{print $2}')
    (( MEMORY_USED_KB = $MEMORY_KB - $MEMORY_FREE_KB ))
    MEMORY_USED=$(awk '{val = $1 / 1024000; printf "%2.0f\n", val}' <<< $MEMORY_USED_KB)
    MEMORY=$(trim $MEMORY)
    MEMORY_USED=$(trim $MEMORY_USED)

    SWAP_KB=$(grep SwapTotal <<< $ALL_MEMORY_INFO |awk '{print $2}')
    SWAP=$(awk '{val = $1 / 1024000; printf "%2.0f\n", val}' <<< $SWAP_KB)
    SWAP_FREE_KB=$(grep SwapFree <<< $ALL_MEMORY_INFO |awk '{print $2}')
    (( SWAP_USED_KB = $SWAP_KB - $SWAP_FREE_KB ))
    SWAP_USED=$(awk '{val = $1 / 1024000; printf "%2.0f\n", val}' <<< $SWAP_USED_KB)
    SWAP=$(trim $SWAP)
    SWAP_USED=$(trim $SWAP_USED)

    DISK_TOTAL=$(df -h --total |awk '{print $2}' |tail -n 1)
    DISK_FREE=$(df -h / |awk '{print $4}' |tail -n 1)

    DNS_SERVERS=$(grep ^nameserver $RESOLVCONF |awk '{print $2}' |tr '\012' ',')
    DNS_SERVERS=$(echo $DNS_SERVERS |sed "s/.$//g" |sed "s/,/, /g")
    SEARCH_DOMAINS=$(grep ^search $RESOLVCONF |sed "s/^search //" |tr ' ' ',' |sed "s/,/, /g")

    UPTIME=$(uptime |awk -F',' '{print $1}')
    TIME_ZONE=$(timedatectl |grep "Time zone:" |awk -F: '{print $2}' |awk '{print $1}')

    if [ -r $CHRONYCONF ] ; then
        TIME_SERVERS=$(grep ^server $CHRONYCONF |awk '{print $2}' |tr '\012' ',')
        TIME_SERVERS=$(echo $TIME_SERVERS |sed "s/.$//g" |sed "s/,/, /g")
    elif [ -r $NTPCONF ] ; then
        TIME_SERVERS=$(grep ^server $NTPCONF |awk '{print $2}' |tr '\012' ',')
        TIME_SERVERS=$(echo $TIME_SERVERS |sed "s/.$//g" |sed "s/,/, /g")
    fi

    # DON'T MOVE THIS !!!!!!!!!!!!!!!!!!
    # Ensure we always check a system for potential DB files on systems that used to have a DB on them
    # If there's a MySQL config file lying around then there's likely to be data so setting this ensures
    # we exclude any DB files in the MySQL data directory in the large files check
    MYSQL_DATA_DIR=$(egrep '^datadir' $MYCNF $MYSQLDCNF 2>/dev/null |head -n 1 |awk -F= '{print $2}')
    MYSQL_DATA_DIR=$(trim $MYSQL_DATA_DIR)

    # Determine system type
#   RES=$(systemctl status nervecentre.service 2>/dev/null)
#   if [ $? -eq 0 -a -r $PROPSFILE ] ; then         # this is an NC machine
    if [ "$NC" ] ; then         # this is an NC machine
        SERVER_TYPE="NC server"
        NCVERSION=$(curl -sk https://127.0.0.1/ping |grep Version)
        NCVERSION=${NCVERSION#* }
        NCVERSION=$(trim $NCVERSION)

        NCVERSION_PREVIOUS=$(find_previous_version $NCVERSION)
        if [ ! "$NCVERSION_PREVIOUS" ] ; then
            NCVERSION_PREVIOUS="None"
        fi

        NCREALDIR=$(cd $NCACTIVEDIR && pwd -P)
        NC_MEMORY=$(grep ^MAXMEMORY= $NCCONF 2>/dev/null |awk -F= '{print $2}')
        NC_MEMORY=${NC_MEMORY^^}    # convert to uppercase for consistency
        NC_MEMORY_UNITS=${NC_MEMORY: -1}        # last char is either a G or M
        NC_MEMORY=$(trim ${NC_MEMORY%*$NC_MEMORY_UNITS})
        # we are now using GibiBytes for NC RAM allocation so if we see a MebiBytes value divide by 1024
        case $NC_MEMORY_UNITS in
#########M) (( NC_MEMORY_GIB = $NC_MEMORY / 1024 ))
         M) NC_MEMORY_GIB=$(awk '{val = $1 / 1024; printf "%2.3f\n", val}' <<< $NC_MEMORY)
            ;;
         G) NC_MEMORY_GIB=$NC_MEMORY
            ;;
        esac
        NCSERVERROLE=$(grep ^ServerRole= $PROPSFILE |awk -F= '{print $2}')
        NCSERVERID=$(grep ^ServerId= $PROPSFILE |awk -F= '{print $2}')

        DEFAULT_NC_CA_TRUSTSTORE_JKS_SUM=$(md5sum $DEFAULT_NC_CERTS_DIR/$CA_TRUSTSTORE_JKS 2>/dev/null |awk '{print $1}')
        NC_CA_TRUSTSTORE_JKS_NOT_EXIST=
        NC_CA_TRUSTSTORE_JKS_SUM=$(md5sum $NC_CERTS_DIR/$CA_TRUSTSTORE_JKS 2>/dev/null |awk '{print $1}')
        if [ ! "$NC_CA_TRUSTSTORE_JKS_SUM" ] ; then
            NC_CA_TRUSTSTORE_JKS_NOT_EXIST=Y
        fi

        NC_SERVER_KEY_STORE_LOC=$(grep ^ServerStoreLoc= $PROPSFILE |awk -F= '{print $2}')
        # if this is commented out in props file then the command above will return nothing
        if [ "$NC_SERVER_KEY_STORE_LOC" ] ; then
            NC_SERVER_KEY_STORE_LOC=$NC_CERTS_DIR/$NC_SERVER_KEY_STORE_LOC
            NC_SERVER_KEY_STORE_SUM=$(md5sum $NC_SERVER_KEY_STORE_LOC 2>/dev/null |awk '{print $1}')
        else
            NC_SERVER_KEY_STORE_LOC="Not in use"
            NC_SERVER_KEY_STORE_SUM=""
        fi
    fi

    if [ "$DB" ] ; then          # this is a DB machine
        SERVER_TYPE="DB server"
        MYSQLVERSION=$(mysql --version |awk '{print $3}')
        MYSQLSERVERID=$(grep ^server_id $MYCNF $MYSQLDCNF 2>/dev/null |head -n 1 |awk -F= '{print $2}')
        MYSQL_MEMORY=$(egrep '^innodb_buffer_pool_size' $MYCNF $MYSQLDCNF 2>/dev/null |head -n 1 |awk -F= '{print $2}')
        MYSQL_MEMORY=${MYSQL_MEMORY^^}    # convert to uppercase for consistency
        MYSQL_MEMORY_UNITS=${MYSQL_MEMORY: -1}      # last char is either a G or M
        MYSQL_MEMORY=$(trim ${MYSQL_MEMORY%*$MYSQL_MEMORY_UNITS})
        # we are now using GibiBytes for MySQL RAM allocation so if we see a MebiBytes value divide by 1024
        case $MYSQL_MEMORY_UNITS in
         M) MYSQL_MEMORY_GIB=$(awk '{val = $1 / 1024; printf "%2.3f\n", val}' <<< $MYSQL_MEMORY)
            ;;
         G) MYSQL_MEMORY_GIB=$MYSQL_MEMORY
            ;;
        esac
    fi

    COMBO=
    if [ "$NC" -a "$DB" ] ; then    # if both flags set then it's a combo server (NC and DB combined)
        SERVER_TYPE="NC & DB server (Combo)"
        COMBO=Y
        for i in 64 32 16 8 4 ; do
            NC_MEMORY_ARRAY[$i]=${NC_COMBO_MEMORY_ARRAY[$i]}
            DB_MEMORY_ARRAY[$i]=${DB_COMBO_MEMORY_ARRAY[$i]}
        done
    fi

    if [ "$ZK" ] ; then  # this is a Zookeeper/Kafka box
        SERVER_TYPE="Zookeeper/Kafka server"
        #ZKVERSION=$($KAFKA_HOME/bin/kafka-run-class.sh org.apache.zookeeper.Version)
        ZKVERSION=$(curl -s http://localhost:8080/commands/envi |grep zookeeper.version |awk -F'"' '{print $4}')
        ZKVERSION=${ZKVERSION%%-*}
        KKVERSION=$($KAFKA_HOME/bin/kafka-topics.sh --version |awk '{print $1}')

        THIS_SERVER_ID=$(get_this_server_id)
        ALL_SERVERS=$(grep ^zookeeper.connect= $KAFKA_CONFIG |awk -F= '{print $2}' |tr ',' ' ')
        SERVER_ARRAY=($ALL_SERVERS)
        SERVER_COUNT=${#SERVER_ARRAY[@]}
        (( ARRAY_INDEX = $THIS_SERVER_ID - 1 ))
        SERVER=${SERVER_ARRAY[$ARRAY_INDEX]%:*}
        ZOOKEEPER_CONNECT_PORT=${SERVER_ARRAY[$ARRAY_INDEX]##*:}

        case $ZOOKEEPER_CONNECT_PORT in
          2281) ZOOKAF_SSL=Y
                ZK_CA_TRUSTSTORE_JKS_SUM=$(md5sum $ZK_CERTS_DIR/$CA_TRUSTSTORE_JKS 2>/dev/null |awk '{print $1}')
                ZK_SERVER_KEY_STORE_LOC=$(grep ssl.keyStore.location= $ZOOKEEPER_CONFIG |awk -F= '{print $2}')
                ZK_SERVER_KEY_STORE_SUM=$(md5sum $ZK_SERVER_KEY_STORE_LOC 2>/dev/null |awk '{print $1}')
                ;;
          2181) ZOOKAF_SSL=
                ;;
        esac
    fi

    if [ ! "$NC" -a ! "$DB" -a ! "$ZK" ] ; then    # if none of NC, DB or ZK flags set then it's not a server we should be running this on really!
        SERVER_TYPE="${RED}Not a Nervecentre App, DB or Zookeeper/Kafka server${END}"
    fi
}

display_information()
{
    # Display information
    $ECHO "Health Check Report - v$VER\n"
    echo "Date run     : $(date)"
    echo "Hostname     : $(hostname)"
    echo "FQDN         : $(nslookup $(hostname) |grep Name: |awk '{print $2}')"
    echo "IP address   : $(hostname -I)"
    echo "DNS servers  : ${DNS_SERVERS}"
    echo "SearchDomains: ${SEARCH_DOMAINS}"
    echo "Ubuntu ver   : $(trim $UBUNTUVERSION)"
    echo -n "Kernel ver   : $(trim $KERNELVERSION)"
    UBUNTUVERSION_JUST_NUMBERS=$(tr -d '[ A-z]' <<< $UBUNTUVERSION)
    UBUNTUVERSION_JUST_NUMBERS=$(trim $UBUNTUVERSION_JUST_NUMBERS)
    EXPECTED_KERNEL_VERSION=${KERNEL_VERSION_ARRAY[$UBUNTUVERSION_JUST_NUMBERS]}
    if [ $KERNELVERSION = $EXPECTED_KERNEL_VERSION ] ; then
        $ECHO "${GRN} (OK - Latest kernel for this Ubuntu release)${END}"
    else
        $ECHO "${YEL} (Warning - Not on latest kernel for this Ubuntu release)${END}"
        (( STAT = $STAT + 1 ))
    fi
    echo "Uptime       : $(trim $UPTIME)"

    echo "CPU count    : $CPUS CPUs (Model: $CPU_MODEL)"
    printf "System RAM   : %2s GB (Used: %2s GB)\n" $MEMORY $MEMORY_USED
    printf "Swap RAM     : %2s GB (Used: %2s GB)\n" $SWAP $SWAP_USED

    DISK_TOTAL_LEN=${#DISK_TOTAL}
    printf "Disk total   : %${DISK_TOTAL_LEN}sB (all partitions)\n" $DISK_TOTAL
    printf "Disk free    : %${DISK_TOTAL_LEN}sB (Root partition)\n" $DISK_FREE
    $ECHO "Time zone    : ${TIME_ZONE}${CYN} (*** Check if correct ***)${END}"
    echo "Time servers : ${TIME_SERVERS}"

    $ECHO "\nSystem type  : $SERVER_TYPE"
    if [ "$NC" ] ; then
        echo "NC ver       : $(trim $NCVERSION)  (Prev: $NCVERSION_PREVIOUS)"
        echo "NC RAM alloc : $NC_MEMORY_GIB GiB"
        echo "Location     : $NCREALDIR"
        echo "Server Role  : $(trim $NCSERVERROLE)"
        echo "Server Id    : $(trim $NCSERVERID)"
        echo -n "CA sum       : "
        if [ "$NC_CA_TRUSTSTORE_JKS_NOT_EXIST" ] ; then
            echo "Cannot find: $CA_TRUSTSTORE_JKS"
        else
            echo -n "$NC_CA_TRUSTSTORE_JKS_SUM"
            check_if_ca_truststore_been_modified
            case $NC_CA_TRUSTSTORE_STATUS in
            MODIFIED)   $ECHO "${YEL} (Warning - $CA_TRUSTSTORE_JKS modified from NC supplied one)${END}"
                        (( STAT = $STAT + 1 ))
                        ;;
            FROM_*)     $ECHO "${YEL} (Warning - $CA_TRUSTSTORE_JKS is from version ${NC_CA_TRUSTSTORE_STATUS#*FROM_}x)${END}"
                        (( STAT = $STAT + 1 ))
                        ;;
            CURRENT)    $ECHO "${GRN} (OK - $CA_TRUSTSTORE_JKS same as NC supplied one)${END}"
                        ;;
            UNKNOWN)    $ECHO "${YEL} (Warning - Unknown status for this $CA_TRUSTSTORE_JKS)${END}"
                        (( STAT = $STAT + 1 ))
                        ;;
            esac
        fi
        echo "KeyStore sum : $NC_SERVER_KEY_STORE_SUM"
        echo "KeyStore loc : $NC_SERVER_KEY_STORE_LOC"
    fi
    if [ "$DB" ] ; then
        echo "MySQL ver    : $MYSQLVERSION"
        echo "MySQL RAM    : $MYSQL_MEMORY_GIB GiB"
        echo "MySQL dir    : $(trim $MYSQL_DATA_DIR)"
        echo "Server Id    : $(trim $MYSQLSERVERID)"
    fi
    if [ "$ZK" ] ; then
        echo -n "Zookeeper ver: $ZKVERSION"
        if [ $ZKVERSION != $ZKLATESTVERSION ] ; then
            $ECHO "${YEL} (Warning - Should be $ZKLATESTVERSION)${END}"
            (( STAT = $STAT + 1 ))
        else
            $ECHO "${GRN} (OK - up-to-date)${END}"
        fi
        echo -n "Kafka ver    : $KKVERSION"
        if [ $KKVERSION != $KKLATESTVERSION ] ; then
            $ECHO "${YEL} (Warning - Should be $KKLATESTVERSION)${END}"
            (( STAT = $STAT + 1 ))
        else
            $ECHO "${GRN} (OK - up-to-date)${END}"
        fi
        echo "Server Id    : $(trim $THIS_SERVER_ID) of $SERVER_COUNT"
        echo -n "Uses SSL?    : "
        case $ZOOKAF_SSL in
         Y) echo "Yes";;
         *) echo "No";;
        esac
        echo "Server List  : ${SERVER_ARRAY[@]%:*}"
        echo "CA sum       : $ZK_CA_TRUSTSTORE_JKS_SUM"
        echo "KeyStore sum : $ZK_SERVER_KEY_STORE_SUM"
        echo "KeyStore loc : $ZK_SERVER_KEY_STORE_LOC"
    fi
}

find_previous_version()
{
    if [ -r $NCDIR/nervecentre/ncpatch*/ncpatch.log ] ; then
        FPV=$(grep "current version details" $NCDIR/nervecentre/ncpatch*/ncpatch.log |awk -F'->' '{print $2}')
    else
        FPV=
    fi
    echo $(trim ${FPV##*/})
}
check_if_ca_truststore_been_modified()
{
    NC_CA_TRUSTSTORE_STATUS=UNKNOWN
    # if sum of truststore in props = sum of NCCerts supplied truststore then truststore is CURRENT
    if [ $NC_CA_TRUSTSTORE_JKS_SUM = $DEFAULT_NC_CA_TRUSTSTORE_JKS_SUM ] ; then
        NC_CA_TRUSTSTORE_STATUS=CURRENT
    else
        NC_CA_TRUSTSTORE_JKS_SUM_IN_ARRAY=$(printf '%s\n' "${CA_TRUSTSTORE_SUMS_ARRAY[@]}" | grep -F -x "$NC_CA_TRUSTSTORE_JKS_SUM")
        # if sum of truststore in props is NOT in the array then truststore is MODIFIED
        if [ ! "$NC_CA_TRUSTSTORE_JKS_SUM_IN_ARRAY" ] ; then
            NC_CA_TRUSTSTORE_STATUS=MODIFIED
        else
            # if neither condition above is true then we have a truststore from a previous version of NC
            for VER_ALT in ${!CA_TRUSTSTORE_SUMS_ARRAY[@]} ; do
                if [ $NC_CA_TRUSTSTORE_JKS_SUM = ${CA_TRUSTSTORE_SUMS_ARRAY[$VER_ALT]} ] ; then
                    NC_CA_TRUSTSTORE_STATUS=FROM_${VER_ALT}
                fi
            done
        fi
    fi
}

check_system_memory_amount()
{
    $ECHO -n "Checking System RAM amount ... "
    VALID_AMOUNT_OF_MEMORY=${NC_MEMORY_ARRAY[$MEMORY]}
    if [ ! "$VALID_AMOUNT_OF_MEMORY" ] ; then
        $ECHO "${YEL}Warning - System has $MEMORY GB - should be 4, 8, 16, 32 or 64${END}"
        (( STAT = $STAT + 1 ))
    else
        $ECHO "${GRN}OK - Standard amount of System RAM ($MEMORY GB)${END}"
    fi
}
check_swap_memory_usage()
{
    $ECHO -n "Checking Swap Memory usage ... "
    # $SWAP_MEMORY_KB and $SWAP_USED_KB calculated in header block above
    (( SWAP_PERCENT_USED = ( $SWAP_USED_KB * 100 ) / $SWAP_KB ))
    if [ $SWAP_PERCENT_USED -gt $SWAP_PERCENT_USED_MAX ] ; then
        $ECHO "${RED}Fail - Exceeds ${SWAP_PERCENT_USED_MAX}% threshold${END}"
        TOP_TEN_SWAP_HOGS=$(for file in /proc/*/status ; do [[ -r $file ]] && awk '/VmSwap|Name/{printf $2 " " $3}END{ print ""}' $file; done | sort -k 2 -n -r | head -n 10)
        while IFS=' ' read PROCESS SWAP_USED_BY_PROCESS UNITS ; do
            if [ "$SWAP_USED_BY_PROCESS" ] ; then
                if [ $SWAP_USED_BY_PROCESS -gt $MAX_SWAP_FOR_SINGLE_PROCESS_KB ] ; then
                    echo $PROCESS $SWAP_USED_BY_PROCESS $UNITS
                fi
            fi
        done <<< $TOP_TEN_SWAP_HOGS
        (( STAT = $STAT + 1 ))
    else
        $ECHO "${GRN}OK - Within limits${END}"
    fi
}
check_load_average()
{
    # uptime / loadaverage (check against number of CPUs, if greater than CPU count display warning)
    $ECHO -n "Checking 1 minute load average ... " 
    CPUS=`grep processor </proc/cpuinfo |wc -l`
    LA=`uptime |awk -F'average: ' '{print $2}'`
    ONEMIN=`echo $LA |awk -F'.' '{print $1}'`
    if [ $ONEMIN -lt $CPUS ] ; then
        $ECHO "${GRN}OK - Load average within limit${END}"
    else
        $ECHO "${YEL}Warning - Load average high - system could be overloaded${END}"
        (( STAT = $STAT + 1 ))
    fi
}
check_virtual_tools_available()
{
    $ECHO -n "Checking virtual platform tools ... "
    DMI_SYSTEM_INFO=$(dmidecode -H1 2>/dev/null)
    case "$DMI_SYSTEM_INFO" in
    *Microsoft*)
        if [ ! "$(dmidecode --string chassis-asset-tag |grep "$AZURE_ASSET_TAG")" ] ; then
            VIRTUAL_PLATFORM="HyperV"
        fi
        ;;
    *VMware*)
        VIRTUAL_PLATFORM="VMware"
        ;;
    esac
    if [ "$VIRTUAL_PLATFORM" ] ; then
        VMTOOLS_STAT=0
        case "$VIRTUAL_PLATFORM" in     # check for the VM tools daemon running
        HyperV) if [ ! "$(ps -fe |grep 'hv_vss_daemo[n]')" ] ; then
                    VMTOOLS_STAT=1
                fi
                ;;
        VMware) if [ ! "$(ps -fe |grep 'vmtools[d]')" ] ; then
                    VMTOOLS_STAT=2
                fi
                ;;
        esac
        case $VMTOOLS_STAT in
         0) $ECHO "${GRN}OK - $VIRTUAL_PLATFORM tools running${END}"
            ;;
         *) $ECHO "${YEL}Warning - $VIRTUAL_PLATFORM tools not running${END}"
            (( STAT = $STAT + 1 ))
            ;;
        esac
    else
        $ECHO "${GRN}OK - Not VMware or HyperV${END}"
    fi
}
check_sar_available()
{
    $ECHO -n "Checking sar ... "
    SAR_INSTALLED=$(which sar)
    if [ ! "$SAR_INSTALLED" ] ; then
        $ECHO "${YEL}Warning - sar is not installed${END}"
        (( STAT = $STAT + 1 ))
    else
        SAR_ENABLED=$(grep 'ENABLED.*true' $DEFAULT_SYSSTAT)
        if [ ! "$SAR_ENABLED" ] ; then
            $ECHO "${YEL}Warning - sar is installed but not enabled${END}"
            (( STAT = $STAT + 1 ))
        else
            SAR_CRON_ENTRY=$(grep debian-sa1 $SYSSTAT_CRON 2>/dev/null)
            if [ ! "$SAR_CRON_ENTRY" ] ; then
                $ECHO "${YEL}Warning - sar is enabled but not scheduled in cron${END}"
                (( STAT = $STAT + 1 ))
            else
                SAR_CRON_5_MIN_INTERVAL=$(grep '*/5' <<< $SAR_CRON_ENTRY)
                if [ ! "$SAR_CRON_5_MIN_INTERVAL" ] ; then
                    $ECHO "${YEL}Warning - sar is enabled but schedule is incorrect${END}"
                    (( STAT = $STAT + 1 ))
                else
                    $ECHO "${GRN}OK - sar is installed and enabled${END}"
                fi
            fi
        fi
    fi
}

check_disk_available()
{
    $ECHO -n "Checking disk space available ... "
    # $MIN_AVAILABLE is a value in GB
    if [ "$DB" ] ; then             # if combo server $NC and $DB will be set. We need to use DB value
        MIN_AVAILABLE=100
    fi
    if [ "$NC" ] ; then
        MIN_AVAILABLE=40
        if [ $NCSERVERROLE = "Media" ] ; then
            MIN_AVAILABLE=100       # special case for Media servers - use DB value for these
        fi
    fi
    if [ "$ZK" ] ; then
        MIN_AVAILABLE=40
    fi
    if [ ! "$MIN_AVAILABLE" ] ; then    # this should never happen on a real NC or DB box
        MIN_AVAILABLE=100
    fi
    # examine the last character of $DISK_FREE and set $ACTUAL_AVAILABLE to a value in GB
    case $DISK_FREE in
    *T) ACTUAL_AVAILABLE=$(echo $DISK_FREE |tr -d "T" |awk '{val = $1 * 1024; printf "%2.0f\n", val}');;
    *G) ACTUAL_AVAILABLE=$(echo $DISK_FREE |tr -d "G");;
    *M) ACTUAL_AVAILABLE=$(echo $DISK_FREE |tr -d "M" |awk '{val = $1 / 1024; printf "%2.0f\n", val}');;
    esac
    # always do comparison using GB and using awk means it can handle decimals
    # awk returns 1 (True) if the comparison is successful, 0 if not
    if [[ $(echo "$ACTUAL_AVAILABLE $MIN_AVAILABLE" | awk '{print ($1 > $2)}') == 1 ]] ; then
        # and this case statement means I can display the value available in the same units as the "df -h" reports
        case $DISK_FREE in
        *T) $ECHO "${GRN}OK - Server has ${DISK_FREE/T/ T}B available${END}";;
        *G) $ECHO "${GRN}OK - Server has ${DISK_FREE/G/ G}B available${END}";;
        # don't need a MB line because if $DISK_FREE is in MB then there's much less space than allowed
        esac
    else
        case $DISK_FREE in
        *T) $ECHO "${RED}Fail - Server has ${DISK_FREE/T/ T}B available, minimum allowed is $MIN_AVAILABLE GB${END}";;
        *G) $ECHO "${RED}Fail - Server has ${DISK_FREE/G/ G}B available, minimum allowed is $MIN_AVAILABLE GB${END}";;
        *M) $ECHO "${RED}Fail - Server has ${DISK_FREE/M/ M}B available, minimum allowed is $MIN_AVAILABLE GB${END}";;
        esac
        (( STAT = $STAT + 1 ))
    fi
}
check_open_file_limits()
{
    $ECHO -n "Checking open file limits ... "   # 14
    FILE_LIMITS_NEW=$(grep -E "^\* (hard nofile|soft nofile) 100000$" $NERVECENTRE_FILE_LIMITS |wc -l)
    if [ "$FILE_LIMITS_NEW" -eq 2 ] ; then
        $ECHO "${GRN}OK - Open file limits configured${END}"
    else
        $ECHO "${YEL}Warning - Open file limits have not yet been configured${END}"
        (( STAT = $STAT + 1 ))
    fi
}
check_for_non_chrooted_users()
{
    $ECHO -n "Checking for non-chrooted users ... " # 16
    declare NON_CHROOTED_ACCOUNTS
#    for ACCOUNT in $(ls /home) ; do
#    for ACCOUNT in `grep ":[0-9][0-9][0-9][0-9]:" /etc/passwd |awk -F':' '{print $1}'` ; do
# finds accounts with UID and GID >= 1000 and looks for them in sshd_config file
    for ACCOUNT in `grep ".*:.*:[0-9]\{4\}:[0-9]\{4\}:" $PASSWD_FILE |awk -F':' '{print $1}'` ; do
        echo $IGNORE_ACCOUNT_LIST |grep -w -q $ACCOUNT
        if [ $? -ne 0 ] ; then  # it's NOT in the ignore list
#            if [ "$(grep $ACCOUNT $PASSWD_FILE)" -a ! "$(grep -i "Match User $ACCOUNT" $SSHD_CONFIG)" ] ; then
            if [ ! "$(grep -i "Match User $ACCOUNT" $SSHD_CONFIG)" ] ; then
                AT_LEAST_ONE_PROBLEM_LINE=Y
                NON_CHROOTED_ACCOUNTS+=( $ACCOUNT )
            fi
        fi
    done
    if [ "$AT_LEAST_ONE_PROBLEM_LINE" ] ; then
        $ECHO "${YEL}Warning - Non-chrooted accounts exist: ${#NON_CHROOTED_ACCOUNTS[@]} ( ${NON_CHROOTED_ACCOUNTS[@]} )${END}"
        #$ECHO "${YEL}Warning - Non-chrooted accounts exist: ${#NON_CHROOTED_ACCOUNTS[@]}${END}"    # to print users on a line of their own
        #$ECHO "${NON_CHROOTED_ACCOUNTS[@]}" |\
        #while read LINE ; do
        #    printf "  %s\n" "$LINE"
        #done
        (( STAT = $STAT + 1 ))
    else
        $ECHO "${GRN}OK - No non-chrooted accounts found${END}"
        check_chrooted_users
    fi
}
check_chrooted_users()
{
    $ECHO -n "Checking chrooted users configured correctly ... " # 16
    declare MISCONFIGURED_CHROOTED_ACCOUNTS
    for ACCOUNT in `grep ".*:.*:[0-9]\{4\}:[0-9]\{4\}:" $PASSWD_FILE |awk -F':' '{print $1}'` ; do
        echo $IGNORE_ACCOUNT_LIST |grep -w -q $ACCOUNT
        if [ $? -ne 0 ] ; then  # it's NOT in the ignore list
            CHROOT_DIRECTORY=$(grep -A6 -i "Match User $ACCOUNT" $SSHD_CONFIG |grep -i "ChrootDirectory" |awk '{print $2}')
            if [ "$(grep '$NCDIR' <<< $CHROOT_DIRECTORY )" ] ; then
                AT_LEAST_ONE_PROBLEM_LINE=Y
                MISCONFIGURED_CHROOTED_ACCOUNTS+=( $ACCOUNT )
            fi
        fi
    done
    if [ "$AT_LEAST_ONE_PROBLEM_LINE" ] ; then
        $ECHO "${YEL}Warning - Misconfigured chrooted accounts exist: ${#MISCONFIGURED_CHROOTED_ACCOUNTS[@]} ( ${MISCONFIGURED_CHROOTED_ACCOUNTS[@]} )${END}"
        #$ECHO "${YEL}Warning -  Misconfiguredchrooted accounts exist: ${#MISCONFIGURED_CHROOTED_ACCOUNTS[@]}${END}"    # to print users on a line of their own
        #$ECHO "${MISCONFIGURED_CHROOTED_ACCOUNTS[@]}" |\
        #while read LINE ; do
        #    printf "  %s\n" "$LINE"
        #done
        (( STAT = $STAT + 1 ))
    else
        $ECHO "${GRN}OK - All chrooted accounts configured correctly${END}"
    fi
}
check_omi_version()
{
    $ECHO -n "Checking OMI version ... " 
    OMI_ISSUE=NONE
    OMIVER=$(dpkg -l |grep " omi " |awk '{print $3}')
    if [ ! "$OMIVER" ] ; then
        OMI_ISSUE="NOTINST"
    else
        OMIVER_SPLIT=$(echo $OMIVER |sed "s/\./ /g")
        OMIVER_ARRAY=($OMIVER_SPLIT)
        if [ ${OMIVER_ARRAY[0]} -eq 1 ] ; then
            if [ ${OMIVER_ARRAY[1]} -eq 6 -a ${OMIVER_ARRAY[2]} -le 8 ] ; then
                (( STAT = $STAT + 1 ))
                OMI_ISSUE=EXPLOIT
            fi
            if [ ${OMIVER_ARRAY[1]} -eq 6 -a ${OMIVER_ARRAY[2]} -eq 9 -a ${OMIVER_ARRAY[3]} -eq 1 ] ; then
                (( STAT = $STAT + 1 ))
                OMI_ISSUE=MEMLEAK
            fi
        fi
    fi
    case "$OMI_ISSUE" in
       EXPLOIT) $ECHO "${YEL}Warning - OMI v$OMIVER has an exploit - upgrade OMI${END}";;
       MEMLEAK) $ECHO "${YEL}Warning - OMI v$OMIVER has a memory leak - upgrade OMI${END}";;
       NOTINST) $ECHO "${GRN}OK - OMI not installed${END}";;
          NONE) $ECHO "${GRN}OK - OMI v$OMIVER has no issues${END}";;
    esac
}
check_time_sync_service()
{
    $ECHO -n "Checking time sync service status ... " 
    RES=$(systemctl status ntp 2>/dev/null)
    NTP_STAT=$?
    RES=$(systemctl status chrony 2>/dev/null)
    CHRONY_STAT=$?
    if [ $NTP_STAT -eq 0 ] ; then
        $ECHO "${GRN}OK - NTP service running${END} "
    elif [ $CHRONY_STAT -eq 0 ] ; then
        $ECHO "${GRN}OK - Chrony service running${END} "
    else
        $ECHO "${RED}Fail - No time sync service is running${END}"
        (( STAT = $STAT + 1 ))
    fi
}
check_time_is_synced()
{
    if [ $NTP_STAT -eq 0 ] ; then
        $ECHO -n "Checking time is synced (NTP) ... " 
        #case $UBUNTUVERSION in
        #*16.04*) NTP_SYNCED=$(timedatectl |grep "NTP synchronized:" |grep "yes");;
        #      *) NTP_SYNCED=$(timedatectl |grep "synchronized:" |grep "yes");;
        #esac
        NTP_SYNCED=$(ntpq -pn |grep '^\*')
        if [ "$NTP_SYNCED" ] ; then
            $ECHO "${GRN}OK - Time synced (NTP)${END}"
        else
            $ECHO "${RED}Fail - Time not synced (NTP)${END}"
            (( STAT = $STAT + 1 ))
        fi
    elif [ $CHRONY_STAT -eq 0 ] ; then
        $ECHO -n "Checking time is synced (Chrony) ... " 
        CHRONY_SYNCED=$(timedatectl |grep "synchronized:" |grep "yes")
        if [ "$CHRONY_SYNCED" ] ; then
            $ECHO "${GRN}OK - Time synced (Chrony)${END}"
        else
            $ECHO "${RED}Fail - Time not synced (Chrony)${END}"
            (( STAT = $STAT + 1 ))
        fi
    fi
}
check_time_sync_not_using_pools()
{
    if [ -r $CHRONYCONF ] ; then
        $ECHO -n "Checking time sync not using pools (Chrony) ... "
        TIME_SYNC_CONF=$CHRONYCONF
    elif [ -r $NTPCONF ] ; then
        $ECHO -n "Checking time sync not using pools (NTP) ... "
        TIME_SYNC_CONF=$NTPCONF
    fi
    if [ "$TIME_SYNC_CONF" ] ; then
        USING_POOLS=$(grep '^pool ' $TIME_SYNC_CONF 2>/dev/null)
        if [ ! "$USING_POOLS" ] ; then
            $ECHO "${GRN}OK - not using pools${END} "
        else
            $ECHO "${YEL}Warning - using pools${END}"
            (( STAT = $STAT + 1 ))
        fi
    else
        $ECHO "${RED}Fail - can't find either an NTP or Chrony config file${END}"
    fi
}
check_mirror()
{
    $ECHO -n "Checking $SOURCES for correct mirror ... " 
    case $UBUNTUVERSION in
    *16.04*) MIRROR=$UBUNTU16_MIRROR;;
          *) MIRROR=$UBUNTU20_MIRROR;;
    esac
    JUST_IP=${MIRROR##*//}
    JUST_IP=${JUST_IP%:*}     
    CORRECT_MIRROR=$(grep $JUST_IP $SOURCES 2>/dev/null)
    if [ "$CORRECT_MIRROR" ] ; then
        $ECHO "${GRN}OK - File is correct${END}"
    else
        if [ ! -r $SOURCES ] ; then
            $ECHO "${YEL}Warning - File doesn't exist${END}"
        else
            $ECHO "${YEL}Warning - File is incorrect${END}"
        fi
        (( STAT = $STAT + 1 ))
    fi
}
check_hosts_file()
{
    $ECHO -n "Checking $HOSTS_FILE file ... "
    HOSTS_STAT=0
    RESULTS=
    IP=$(trim $(hostname -I))
    [[ "$(egrep "127.0.0.1\s+localhost" $HOSTS_FILE)" ]]      || (( HOSTS_STAT = $HOSTS_STAT + 256 ))
    if [ ! "$(egrep -i "127.0.1.1\s+$(hostname)$" $HOSTS_FILE)" ] ; then
        if [ ! "$(egrep -i "${IP}\s+$(hostname)$" $HOSTS_FILE)" ] ; then
            # neither 127 or IP address line exists - bad
            RESULTS="NONE"
            (( HOSTS_STAT = $HOSTS_STAT + 128 ))
        else
            # just the IP line is there - OK but not ideal
            RESULTS="IP"
            (( HOSTS_STAT = $HOSTS_STAT + 128 ))
        fi
    else
        if [ ! "$(egrep -i "${IP}\s+$(hostname)$" $HOSTS_FILE)" ] ; then
            # just 127 line exists - good
            RESULTS="127"
        else
            # both exist - bad
            RESULTS="BOTH"
            (( HOSTS_STAT = $HOSTS_STAT + 128 ))
        fi
    fi
    [[ "$(egrep -i "${IP}\s+$(hostname)\..*" $HOSTS_FILE)" ]]  && (( HOSTS_STAT = $HOSTS_STAT + 64 ))

    if [ $HOSTS_STAT -eq 0 ] ; then
        $ECHO "${GRN}OK - Conforms to standard${END}"
    else
        $ECHO "${YEL}Warning - Non standard - manual review required${END}"
        if [ $HOSTS_STAT -ge 256 ] ; then
            echo "  Missing or incorrect '127.0.0.1  localhost' line"
            (( HOSTS_STAT = $HOSTS_STAT - 256 ))
        fi
        if [ $HOSTS_STAT -ge 128 ] ; then
            case $RESULTS in
              NONE) echo "  Missing or incorrect '127.0.1.1  $(hostname)' line";;
                IP) echo "  Contains '$(egrep -i "${IP}\s+$(hostname)$" $HOSTS_FILE)' - '127.0.1.1  $(hostname)' preferred";;
              BOTH) echo "  Contains a 127.0.1.1 and IP address line for $(hostname)";;
            esac
            (( HOSTS_STAT = $HOSTS_STAT - 128 ))
        fi
        if [ $HOSTS_STAT -ge 64 ] ; then
            echo "  Contains a FQDN line which could cause issues"
            (( HOSTS_STAT = $HOSTS_STAT - 64 ))
        fi
        (( STAT = $STAT + 1 ))
    fi
}
check_interfaces_file()
{
    $ECHO -n "Checking network config ... " # 24
    # set this to blank so we can tell later if this line is missing which causes the nslookup to fail
    DNS_SEARCH_DOMAIN_MISSING=
    INTERFACE_NAME=$(lshw -class network 2>/dev/null |grep "logical name" |awk -F': ' '{print $2}' |head -n 1)
    if [ ! "$INTERFACE_NAME" ] ; then
        INTERFACE_NAME=$(ifconfig |grep -B1 $(hostname -I) |grep -o '^[a-zA-Z0-9]*')
    fi
    # Possible command to include in check but at present don't have a 100% non-Netplan VM to test with 01/12/23
    #USING_NETWORKD=$(netplan generate --mapping $INTERFACE_NAME |grep 'backend=networkd')
    IFSTATE_OUTPUT="[$(cat /run/network/ifstate 2>/dev/null)]"
    if [ $? -eq 0 -a "$(grep $INTERFACE_NAME <<< $IFSTATE_OUTPUT)" ] ; then # if IFSTATE_OUTPUT contains our interface name then ...
        real_check_interfaces_file              # ... we're using interfaces file
    else
        $ECHO "${GRN}OK - Using Netplan${END}"  # else we're using Netplan
    fi
}
real_check_interfaces_file()
{
    CONFIG_NO_COMMENTS=/tmp/$PROG.$$.interfaces_no_comments
    CONFIG_TO_CHECK=
    # check if there is a source line in the interfaces file
    SOURCE_FROM=$(grep '^source .*' $INTERFACES_FILE |awk '{print $2}')
    # if there is then grep for our interface name in all of them and grab the 1st one
    if [ "$SOURCE_FROM" ] ; then
        CONFIG_TO_CHECK=$(grep -l "^iface $INTERFACE_NAME .*" $SOURCE_FROM 2>/dev/null |head -n 1)
    fi
    # if we don't have a CONFIG_TO_CHECK yet then our interface name wasn't in any of the
    # file(s) searched so set CONFIG_TO_CHECK to the name if the standard interfaces file
    if [ ! "$CONFIG_TO_CHECK" ] ; then
        CONFIG_TO_CHECK=$INTERFACES_FILE
    fi
    #CONFIG_TO_CHECK=~/NC/misc_stuff/interfaces_testfile    # uncomment to test on my system
    # remove any line that has a # before some text
    grep '^[[:blank:]]*[^[:blank:]#]' $CONFIG_TO_CHECK > $CONFIG_NO_COMMENTS
    IF_STAT=0
    if [ "$(grep -E "iface $INTERFACE_NAME inet dhcp" $CONFIG_NO_COMMENTS)" ] ; then
        $ECHO "${GRN}OK - Using DHCP ($CONFIG_TO_CHECK)${END}"
    elif [ "$(grep -E "iface .* inet dhcp" $CONFIG_NO_COMMENTS)" ] ; then
        $ECHO "${YEL}Warning - interface in use ($INTERFACE_NAME) does not match $CONFIG_TO_CHECK${END}"
        (( STAT = $STAT + 1 ))
    else
        IP_ADDRESS_REGEXP='\b((([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\.)){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]))\b'
        [[ "$(grep -E "auto +$INTERFACE_NAME" $CONFIG_NO_COMMENTS)" ]]                       || (( IF_STAT = $IF_STAT + 256 ))
        [[ "$(grep -E "iface +$INTERFACE_NAME inet static" $CONFIG_NO_COMMENTS)" ]]          || (( IF_STAT = $IF_STAT + 128 ))
        [[ "$(grep -E "address +$IP_ADDRESS_REGEXP$" $CONFIG_NO_COMMENTS)" ]]                || (( IF_STAT = $IF_STAT + 64 ))
        [[ "$(grep -E "netmask +$IP_ADDRESS_REGEXP$" $CONFIG_NO_COMMENTS)" ]]                || (( IF_STAT = $IF_STAT + 32 ))
        [[ "$(grep -E "network +$IP_ADDRESS_REGEXP$" $CONFIG_NO_COMMENTS)" ]]                || (( IF_STAT = $IF_STAT + 16 ))
        [[ "$(grep -E "broadcast +$IP_ADDRESS_REGEXP$" $CONFIG_NO_COMMENTS)" ]]              || (( IF_STAT = $IF_STAT + 8 ))
        [[ "$(grep -E "gateway +$IP_ADDRESS_REGEXP$" $CONFIG_NO_COMMENTS)" ]]                || (( IF_STAT = $IF_STAT + 4 ))
        WORD_COUNT=$(grep -E "dns-nameservers +$IP_ADDRESS_REGEXP" $CONFIG_NO_COMMENTS |wc -w)
        (( DNS = WORD_COUNT - 1 ))  # subtract 1 for the "dns-nameservers" part of the line
        [[ $DNS -lt 1 ]] && DNS=1   # if DNS is less than 1 set it to 1. Can't match on zero IP addresses!
        [[ "$(grep -E "dns-nameservers( +$IP_ADDRESS_REGEXP){$DNS}" $CONFIG_NO_COMMENTS)" ]] || (( IF_STAT = $IF_STAT + 2 ))
        [[ "$(grep -E "dns-search +[a-z]*" $CONFIG_NO_COMMENTS)" ]]                          || (( IF_STAT = $IF_STAT + 1 ))
        if [ $IF_STAT -eq 0 ] ; then
            $ECHO "${GRN}OK - Conforms to standard ($CONFIG_TO_CHECK)${END}"
        else
            $ECHO "${YEL}Warning - Non standard ($CONFIG_TO_CHECK)${END}"
            if [ $IF_STAT -ge 256 ] ; then
                echo "  Missing or incorrect 'auto $INTERFACE_NAME' line"
                (( IF_STAT = $IF_STAT - 256 ))
            fi
            if [ $IF_STAT -ge 128 ] ; then
                echo "  Missing or incorrect 'iface $INTERFACE_NAME inet static' line"
                (( IF_STAT = $IF_STAT - 128 ))
            fi
            if [ $IF_STAT -ge 64 ] ; then
                echo "  Missing or incorrect 'address IP-ADDRESS' line"
                (( IF_STAT = $IF_STAT - 64 ))
            fi
            if [ $IF_STAT -ge 32 ] ; then
                echo "  Missing or incorrect 'netmask NETMASK' line"
                (( IF_STAT = $IF_STAT - 32 ))
            fi
            if [ $IF_STAT -ge 16 ] ; then
                echo "  Missing or incorrect 'network NETWORK' line"
                (( IF_STAT = $IF_STAT - 16 ))
            fi
            if [ $IF_STAT -ge 8 ] ; then
                echo "  Missing or incorrect 'broadcast BROADCAST' line"
                (( IF_STAT = $IF_STAT - 8 ))
            fi
            if [ $IF_STAT -ge 4 ] ; then
                echo "  Missing or incorrect 'gateway GATEWAY' line"
                (( IF_STAT = $IF_STAT - 4 ))
            fi
            if [ $IF_STAT -ge 2 ] ; then
                echo "  Missing or incorrect 'dns-nameservers NAME-SERVER [ NAME-SERVER ]' line"
                (( IF_STAT = $IF_STAT - 2 ))
            fi
            if [ $IF_STAT -ge 1 ] ; then
                echo "  Missing or incorrect 'dns-search DNS-SEARCH-DOMAIN' line"
                DNS_SEARCH_DOMAIN_MISSING=Y
                (( IF_STAT = $IF_STAT - 1 ))
            fi
            (( STAT = $STAT + 1 ))
        fi
    fi
    rm -f $CONFIG_NO_COMMENTS
}
check_dns_operation()
{
    $ECHO -n "Checking DNS operation ... "   # 17
    which nslookup >/dev/null
    if [ $? -eq 0 ] ; then
        NSLOOKUP_THIS_BOX=$(nslookup $(hostname))
        NSLOOKUP_STAT=$?
        GOT_SERVFAIL=$(grep "SERVFAIL reply" <<< $NSLOOKUP_THIS_BOX)
        if [ $NSLOOKUP_STAT -eq 0 -a ! "$GOT_SERVFAIL" ] ; then
            $ECHO "${GRN}OK - DNS can resolve $(hostname)${END}"
        else
            $ECHO -n "${RED}Fail - DNS cannot resolve $(hostname)${END}"
            (( STAT = $STAT + 1 ))
            if [ "$GOT_SERVFAIL" ] ; then
                $ECHO "${RED} - check DNS server(s)${END}" 
            else
                if [ "$DNS_SEARCH_DOMAIN_MISSING" ] ; then
                    $ECHO "${RED} - check dns-search line${END}" 
                else
                    echo
                fi
            fi
        fi
    else
        $ECHO "${RED}Fail - DNS check impossible (nslookup not installed)${END}"
        (( STAT = $STAT + 1 ))
    fi
}
check_reverse_dns_operation()
{
    $ECHO -n "Checking Reverse DNS operation ... "   # 17 on steroids!
    which nslookup >/dev/null
    if [ $? -eq 0 ] ; then
        REV_NSLOOKUP_THIS_BOX=$(nslookup $(hostname -I))
        if [ $? -eq 0 ] ; then
            FQDN=$(nslookup $(hostname) |grep Name: |awk '{print $2}')
            REV_FQDN=$(trim $(nslookup $(hostname -I) |awk -F'=' '{print $2}'))
            REV_FQDN=${REV_FQDN%.*}
            if [ "${FQDN,,}" != "${REV_FQDN,,}" -a ! "$DNS_SEARCH_DOMAIN_MISSING" ] ; then
                $ECHO "${YEL}Warning - DNS can reverse resolve but FQDNs differ${END}"
                echo "  Lookup of hostname  : $FQDN"
                echo "  Lookup of IP address: $REV_FQDN"
                (( STAT = $STAT + 1 ))
            else
                $ECHO "${GRN}OK - DNS can reverse resolve $(trim $(hostname -I))${END}"
            fi
        else
            $ECHO "${RED}Fail - DNS cannot reverse resolve $(hostname -I)${END}"
            (( STAT = $STAT + 1 ))
        fi
    else
        $ECHO "${RED}Fail - DNS check impossible (nslookup not installed)${END}"
        (( STAT = $STAT + 1 ))
    fi
}
check_disk_write_speed()
{
    $ECHO -n "Checking disk write speed ... "   # 17
    if [ "$DISK_SPEED_CHECK_ENABLED" ] ; then
# Googled for reliable methods to check disk write speed RCH 09/02/22
# https://askubuntu.com/questions/87035/how-to-check-hard-disk-performance
        DISK_FREE_INT=${DISK_FREE//[!0-9]/}
        ENOUGH_SPACE=Y
        case $DISK_FREE in
        *G) if [ $DISK_FREE_INT -lt 6 ] ; then
                $ECHO "${RED}Fail - Not enough free disk space to run test${END}"
                ENOUGH_SPACE=
            fi
            ;;
        *M) $ECHO "${RED}Fail - Not enough free disk space to run test${END}"
            ENOUGH_SPACE=
            ;;
        esac
    else
        $ECHO "${GRN}Skipped - Disk write speed check skipped${END}"
        ENOUGH_SPACE=
    fi
    if [ "$ENOUGH_SPACE" ] ; then
        INPATH=/dev/zero
        OUTPATH=/tmp/TestDiskWriteSpeed.output
#        DD_OUTPUT=$(dd if=$INPATH of=$OUTPATH bs=1M count=1024 oflag=dsync 2>&1)
        DD_OUTPUT=$(dd if=$INPATH of=$OUTPATH conv=fdatasync bs=1M count=1k 2>&1)
        rm -f $OUTPATH
        WRITE_SPEED_LINE=$(echo "$DD_OUTPUT" |tail -n 1)                # pick out last line of output
        WRITE_SPEED_FULL=${WRITE_SPEED_LINE##*,}                        # pick out just last part after ,
        WRITE_SPEED_FP=$(echo "$WRITE_SPEED_FULL" |awk '{print $1}')    # now just pick out the numeric value
        WRITE_SPEED_UNIT=$(echo "$WRITE_SPEED_FULL" |awk '{print $2}')  # pick out the unit (MB/s or GB/s)
        case $WRITE_SPEED_UNIT in
          MB/s) WRITE_SPEED_INT=${WRITE_SPEED_FP%.*}                    # remove any decimal part
                if [ "$WRITE_SPEED_INT" -ge 75 ] ; then
                    $ECHO "${GRN}OK - Disk write speed OK ($WRITE_SPEED_FP MB/s)${END}"
                else
                    $ECHO "${YEL}Warning - Disk write speed LOW ($WRITE_SPEED_FP MB/s)${END}"
                    (( STAT = $STAT + 1 ))
                fi
                ;;
          GB/s) $ECHO "${GRN}OK - Disk write speed OK ($WRITE_SPEED_FP GB/s)${END}"
                ;;
        esac
    fi
}
check_for_big_files()
{
    $ECHO -n "Checking for files greater than ${FIND_FILE_SIZE}B ... "
    if [ "$FIND_BIG_FILES_ENABLED" ] ; then
        FIND_TEMP=/tmp/$PROG.$$
        FIND_TEMP2=/tmp/$PROG.$$.2
        if [ "$MYSQL_DATA_DIR" ] ; then
            find / -type f -size +${FIND_FILE_SIZE} ! -path "$MYSQL_DATA_DIR/*" >$FIND_TEMP 2>/dev/null
        else
            find / -type f -size +${FIND_FILE_SIZE} >$FIND_TEMP 2>/dev/null
        fi
        # we don't want to include anything in /proc
        # or that could possibly be in a DB backup folder 
        egrep -v '(^/proc|dbback)' $FIND_TEMP > $FIND_TEMP2
        mv $FIND_TEMP2 $FIND_TEMP
        # code below runs "file" against each file still present to check file type
        # we want to ignore files of type: swap
        # there may be others we find - add here
        > $FIND_TEMP2
        for FILE in $(cat $FIND_TEMP) ; do
            FILETYPE=$(file $FILE)
            if [ ! "$(echo $FILETYPE |grep swap)" ] ; then
                echo $FILE >> $FIND_TEMP2
            fi
        done
        mv $FIND_TEMP2 $FIND_TEMP
        if [ ! -s $FIND_TEMP ] ; then
            $ECHO "${GRN}OK - No large files found${END}"
        else
            LEN=$(wc -l < $FIND_TEMP)
            $ECHO "${YEL}Warning - Large files found: $LEN${END}"
            cat $FIND_TEMP |xargs ls -l |\
            while read LINE ; do
                printf "  %s\n" "$LINE"
            done

            (( STAT = $STAT + 1 ))
        fi
        rm -f $FIND_TEMP $FIND_TEMP2
    else
        $ECHO "${GRN}Skipped - Big files check skipped${END}"
    fi
}

#################################################### NC checks ####################################################

check_nervecentre_conf_file_contents()
{
    AT_LEAST_ONE_PROBLEM_LINE=
    LINES_PROBLEM=
    if [ -r $NCCONF ] ; then
        $ECHO -n "Checking ${NCCONF##*/} ... "
        while read LINE ; do
            if [ "$LINE" -a "${LINE:0:1}" != "#" -a "${LINE:0:10}" != "MAXMEMORY=" ] ; then
                if [ "$(grep ^$LINE$ $NCCONFDEF)" ] ; then
                    AT_LEAST_ONE_PROBLEM_LINE=Y
                    LINES_PROBLEM="${LINES_PROBLEM}Superfluous (in custom and build): $LINE\n"
                else
                    AT_LEAST_ONE_PROBLEM_LINE=Y
                    LINES_PROBLEM="${LINES_PROBLEM}Unexpected (in custom, not build): $LINE\n"
                fi
            fi
        done < $NCCONF
        if [ "$AT_LEAST_ONE_PROBLEM_LINE" ] ; then
            LEN=$(wc -l <<< $(echo -e "$LINES_PROBLEM"))
            $ECHO "${YEL}Warning - Superfluous or unexpected lines found: $LEN${END}"
            $ECHO "$LINES_PROBLEM" |awk 'NF' |\
            while read LINE ; do
                printf "  %s\n" "$LINE"
            done
            (( STAT = $STAT + 1 ))
        else
            $ECHO "${GRN}OK - Contains recommended lines${END}"
        fi
    else
        $ECHO "${YEL}Warning - File does not exist - run Menu option 5 to create it${END}"
        (( STAT = $STAT + 1 ))
    fi
}
check_nc_memory()
{
    $ECHO -n "Checking NC RAM allocation "
    if [ "$COMBO" ] ; then
        $ECHO -n "(Combo) ... "
    else
        $ECHO -n "... "
    fi
    # NC_MEMORY_GIB now calculated further up
    if [ ! -r $NCCONF ] ; then
        $ECHO "${RED}Fail - Can't find $NCCONF${END}"
        (( STAT = $STAT + 1 ))
    elif [ ! "$NC_MEMORY_GIB" ] ; then
        $ECHO "${RED}Fail - Variable MAXMEMORY not set${END}"
        (( STAT = $STAT + 1 ))
    elif [ ! "${NC_MEMORY_ARRAY[$MEMORY]}" ] ; then
        $ECHO "${YEL}Warning - Allocated ${NC_MEMORY_GIB} GiB but System RAM non-standard amount so can't complete check${END}"
        (( STAT = $STAT + 1 ))
####elif [ $NC_MEMORY_GIB -ne "${NC_MEMORY_ARRAY[$MEMORY]}" ] ; then
    elif [[ $(echo "$NC_MEMORY_GIB ${NC_MEMORY_ARRAY[$MEMORY]}" | awk '{print ($1 != $2)}') == 1 ]] ; then
        $ECHO "${RED}Fail - Allocated ${NC_MEMORY_GIB} GiB but recommended to have ${NC_MEMORY_ARRAY[$MEMORY]} GiB${END}"
        (( STAT = $STAT + 1 ))
#   elif [ ${NC_MEMORY_RAW: -1} = "M" ] ; then
#       $ECHO "${RED}Fail - Variable MAXMEMORY is in GB - must be in MiB${END}"
#        (( STAT = $STAT + 1 ))
    else
        $ECHO "${GRN}OK - Allocated ${NC_MEMORY_GIB} GiB${END}"
    fi
}
check_nc_service_status()
{
    $ECHO -n "Checking NC service status ... "
    RES=$(systemctl status nervecentre.service |egrep '(Active:|.service)' |grep -v CGroup)
    if [ "$(echo $RES |grep ' active')" ] ; then
        $ECHO "${GRN}OK - Nervecentre service is active${END}"
    else
        $ECHO "${RED}Fail - Nervecente service not active on this server${END}"
        (( STAT = $STAT + 1 ))
    fi
}
check_curl()
{
    $ECHO -n "Checking \"curl -sk https://127.0.0.1/ping\" ... "
    RES=$(curl -sk https://127.0.0.1/ping)
    CURL_STAT=$?
    if [ "$CURL_STAT" -eq 0 ] ; then
        VERSION=$(echo "$RES" |grep Version)
        $ECHO "${GRN}OK - Command succeeded${END}"
    else
        $ECHO "${RED}Fail - Command failed${END}"
        (( STAT = $STAT + 1 ))
    fi
}
check_ssl_cert_nc()
{
    $ECHO -n "Checking SSL certificate expiry ... "
    RES=$(curl -vk https://127.0.0.1/ping 2>&1)
    EXPIRE_DATE=$(echo "$RES" | grep '\*.*expire date:' |awk '{print $4, $5, $7, $6}')
    if [ ! "$EXPIRE_DATE" ] ; then
        EXPIRE_DATE=$(echo "$RES" |grep -A4 '\*.*expire date:' |grep expire |awk '{print $6, $5, $7, $8}')
    fi
    EXPIRE_SECS=$(date --date="$EXPIRE_DATE" +"%s") # convert to an epoch value
    START_DATE=$(echo "$RES" |grep '\*.*start date:' |awk '{print $4, $5, $7, $6}')
    if [ ! "$START_DATE" ] ; then
        START_DATE=$(echo "$RES" |grep -A4 '\*.*start date:' |grep start |awk '{print $6, $5, $7, $8}')
    fi
    START_SECS=$(date --date="$START_DATE" +"%s") # convert to an epoch value
    TODAY_DATE=$(date +"%b %d %Y %T")               # todays's date in "Mmm DD YYYY hh:mm:ss" format
    TODAY_SECS=$(date --date="$TODAY_DATE" +"%s")   # convert to an epoch value
    (( EXPIRE_DAYS = ( $EXPIRE_SECS - $TODAY_SECS ) / 86400 ))        # seconds to days
    (( VALID_DAYS = ( $EXPIRE_SECS - $START_SECS ) / 86400 ))         # seconds to days
    NC_ISSUER=$(echo "$RES" |grep '\*.*issuer:.*nervecentresoftware.com')
    if [ "$NC_ISSUER" ] ; then
        CERT_EXTRA="(Out of the box cert)"
    fi
    if [ "$EXPIRE_SECS" -lt "$TODAY_SECS" ] ; then
        CERT_STATUS="${RED}Fail - Expired $EXPIRE_DATE $CERT_EXTRA${END}"
        (( STAT = $STAT + 1 ))
    else
        (( TODAY_PLUS_30_DAYS = $TODAY_SECS + 2592000 ))    # add 30 days of seconds
        if [ "$EXPIRE_SECS" -lt "$TODAY_PLUS_30_DAYS" ] ; then
            CERT_STATUS="${YEL}Warning - Expires $EXPIRE_DATE ($EXPIRE_DAYS days) $CERT_EXTRA${END}"
            (( STAT = $STAT + 1 ))
        else
            if [ "$VALID_DAYS" -gt $MAX_VALIDITY ] ; then
                CERT_STATUS="${YEL}Warning - Certificate validity length > $MAX_VALIDITY days (Apple devices only)${END}"
                (( STAT = $STAT + 1 ))
            else
                CERT_STATUS="${GRN}OK - Expires $EXPIRE_DATE ($EXPIRE_DAYS days) $CERT_EXTRA${END}"
            fi
        fi
        $ECHO "$CERT_STATUS"
    fi
}
check_nc_connected_to_db()
{
    $ECHO -n "Checking NC is connected to DB server ... "
    MYSQL_ESTABLISHED=$(netstat -tapn |grep 3306 |grep ESTABLISHED |grep 'tcp ')
    if [ "$MYSQL_ESTABLISHED" ] ; then
        $ECHO "${GRN}OK - NC is connected to DB server${END}"
    else
        $ECHO "${RED}Fail - NC is not connected to DB server${END}"
        (( STAT = $STAT + 1 ))
    fi
}
check_apple_push_port()
{
    $ECHO -n "Checking connectivity to Apple Push Notification port ... "   # 10
    APN_LISTENING=$(nc -z -w3 api.push.apple.com 443)
    if [ $? -eq 0 ] ; then
        $ECHO "${GRN}OK - Apple Push Notification port is open${END}"
    else
        $ECHO "${RED}Fail - Apple Push Notification port is NOT open${END}"
        (( STAT = $STAT + 1 ))
    fi
}
check_android_push_port()
{
    $ECHO -n "Checking connectivity to Android Push Notification port ... "   # 10
    APN_LISTENING=$(curl -m 3 https://fcm.googleapis.com/fcm/send 2>/dev/null)
    if [ $? -eq 0 -a "$(grep 'cloud-messaging/http-server-ref' <<< $APN_LISTENING)" ] ; then
        $ECHO "${GRN}OK - Android Push Notification port is open${END}"
    else
        $ECHO "${RED}Fail - Android Push Notification port is NOT open${END}"
        (( STAT = $STAT + 1 ))
    fi
}
check_maxdevicesperserver()
{
    $ECHO -n "Checking MaxDevicesPerServer value ... "
    MAX_DEVICES=$(grep ^MaxDevicesPerServer $PROPSFILE 2>/dev/null |awk -F= '{print $2}')
    if [ ! "$MAX_DEVICES" ] ; then
        MAX_DEVICES=0
    fi
    if [ "$MAX_DEVICES" -eq $NEW_MAX_DEVICES ] ; then
        $ECHO "${GRN}OK - Value is correct ($MAX_DEVICES)${END}"
    else
        $ECHO "${RED}Fail - Value is not correct ($MAX_DEVICES) - should be $NEW_MAX_DEVICES${END}"
        (( STAT = $STAT + 1 ))
    fi
}
check_fonts_on_reporting_servers()
{
    if [[ $NCSERVERROLE == "Reporting"* ]] ; then
        $ECHO -n "Checking if fonts installed ... " 
        FONTS=$(dpkg -l |grep " fontconfig ")
        if [ "$FONTS" ] ; then
            $ECHO "${GRN}OK - Fonts installed${END}"
        else
            $ECHO "${YEL}Warning - Fonts not installed${END}"
            (( STAT = $STAT + 1 ))
        fi
    fi
}
check_for_oom_in_logs()
{
    $ECHO -n "Checking for Out of Memory messages in logs ... "   # 21
    OOMS=$(grep "OutOfMemory" $LOG_DIR/ncstartup.log 2>/dev/null && grep "OutOfMemory" $LOG_DIR/ncerrors* 2>/dev/null)
    if [ ! "$OOMS" ] ; then
        $ECHO "${GRN}OK - No Out of Memory messages found${END}"
    else
        $ECHO "${YEL}Warning - Messages found - further investigation required:${END}"
        echo $OOMS
        (( STAT = $STAT + 1 ))
    fi
}
check_for_heap_dumps()
{
    $ECHO -n "Checking for heap dump files ... "
    # check for heapdumps in /usr/local/nc/nervecentre with ext .hprof
#   HEAPDUMPS=$(ls -l $NCACTIVEDIR/*.hprof 2>/dev/null)
# find \( -path "./tmp" -o -path "./scripts" \) -prune -o  -name "*_peaks.bed" -print
    cd $NCDIR
    HEAPDUMPS=$(find -path "./custdata" -prune -o -name "*.hprof" -print 2>/dev/null)
    if [ ! "$HEAPDUMPS" ] ; then
        $ECHO "${GRN}OK - No heap dumps found${END}"
    else
        COUNT_HEAPDUMPS=$(wc -l <<< "$HEAPDUMPS")
        $ECHO "${YEL}Warning - Heap dumps exist: $COUNT_HEAPDUMPS${END}"
        $ECHO "$HEAPDUMPS" |\
        while read LINE ; do
            printf "  %s\n" "$LINE"
        done
        (( STAT = $STAT + 1 ))
    fi
    cd $OLDPWD      # return to previous directory to stop ugly file glob issues
}
check_old_installs()
{
    # get a list of directories containing nervecentre.jar files and remove lines that contain current version, previous version
    # and nervecentre (the symlink). We will never offer to remove current version, previous version or nervecentre (the symlink).
    $ECHO -n "Checking for old installs to remove ... " # 19
    CURRENT_INSTALL_DIR=$(cd $NCDIR/nervecentre && pwd -P)
    CURRENT_INSTALL_DIR=${CURRENT_INSTALL_DIR##*/}      # eg 7.2.7
    PREVIOUS_INSTALL_DIR=$NCVERSION_PREVIOUS            # eg 7.2.3 or the word "None"
    NC_DIRS_TO_REMOVE=$(cd $NCDIR && ls -1 */nervecentre.jar 2>/dev/null |sed -e 's,/nervecentre.jar,,' |egrep -v "($CURRENT_INSTALL_DIR|$PREVIOUS_INSTALL_DIR|nervecentre)$")
    COUNT_TOTAL_JAR_FILES=$(cd $NCDIR && ls -1 */nervecentre.jar 2>/dev/null |sed -e 's,/nervecentre.jar,,' |grep -c '^')
    REMOVE_FROM_COUNT=3     # the number of directories with jar files for a box with a current install, symlink to it and an old install (Eg: 7.2.7 , nervecentre , 7.2.3)
    if [ "$PREVIOUS_INSTALL_DIR" = "None" ] ; then
        REMOVE_FROM_COUNT=2 # if no previous install then we just have 2 knowns (Eg: 7.2.7 , nervecentre)
    fi
    (( COUNT_JAR_FILES_EXCLUDING_KNOWN = COUNT_TOTAL_JAR_FILES - REMOVE_FROM_COUNT ))
    COUNT_NC_DIRS_TO_REMOVE=$(echo -n "$NC_DIRS_TO_REMOVE" |grep -c '^')
    if [ $COUNT_JAR_FILES_EXCLUDING_KNOWN -ne $COUNT_NC_DIRS_TO_REMOVE ] ; then
        $ECHO "${YEL}Warning - Unexpected number of jar files - manual intervention required${END}"
        (( STAT = $STAT + 1 ))
    else
        remove_dirs_from_list_we_want_to_keep
        if [ ! "$NC_DIRS_TO_REMOVE" ] ; then
            $ECHO "${GRN}OK - No old installs${END}"
        else
            #COUNT_NC_DIRS_TO_REMOVE=$(echo -n "$NC_DIRS_TO_REMOVE" |grep -c '^')
            $ECHO "${YEL}Warning - Old installs present: $COUNT_NC_DIRS_TO_REMOVE${END}"
            echo "  "$NC_DIRS_TO_REMOVE
            (( STAT = $STAT + 1 ))
        fi
    fi
}
remove_dirs_from_list_we_want_to_keep()
{
    # This function will remove any entries from $NC_DIRS_TO_REMOVE that have a directory creation date
    # newer than the creation date of the current version directory.
    # This will prevent the healthcheck offering to remove a directory with a pre-deploy in.
    # In other words if you do a healthcheck between doing a pre deploy and the post deploy it will offer to remove
    # your pre deploy directory. The code below removes the pre deploy directory from the list of directories to remove.

    LOOPING_NC_DIRS_TO_REMOVE=$NC_DIRS_TO_REMOVE
    for i in $LOOPING_NC_DIRS_TO_REMOVE ; do
        if [ "$NCDIR/$i" -nt "$NCDIR/$CURRENT_INSTALL_DIR" ] ; then
            NEW_NC_DIRS_TO_REMOVE=$(sed "/"$i"$/d" <<< $NC_DIRS_TO_REMOVE)
            NC_DIRS_TO_REMOVE=$NEW_NC_DIRS_TO_REMOVE
            (( COUNT_NC_DIRS_TO_REMOVE = $COUNT_NC_DIRS_TO_REMOVE - 1 ))
        fi
    done
}

#################################################### MySQL / DB checks ####################################################

check_mysql_using_std_config()
{
    $ECHO -n "Checking MySQL is using standard config files ... "
#   MYSQL_STD_MYSQLDCNF=$(egrep "Nervecentre mysql.* config file" $MYSQLDCNF)
    if [ -r $MYSQLDCNF ] ; then
        MYSQL_STD_MYSQLDCNF=$(head -n 1 $MYSQLDCNF |grep "^# Nervecentre")
    fi
    MYSQL_STD_MYCNF=$(tail -n 2 $MYCNF |grep "\!includedir")
    if [ "$MYSQL_STD_MYSQLDCNF" -a "$MYSQL_STD_MYCNF" ] ; then
        $ECHO "${GRN}OK - Standard config in use${END}"
    else
        $ECHO "${RED}Fail - Not using our standard config${END}"
        (( STAT = $STAT + 1 ))
    fi
}
check_db_memory()
{
    $ECHO -n "Checking MySQL RAM allocation "
    if [ "$COMBO" ] ; then
        $ECHO -n "(Combo) ... "
    else
        $ECHO -n "... "
    fi
    # MYSQL_MEMORY_GIB now calculated further up
    if [ ! -r $MYCNF -a ! -r $MYSQLDCNF ] ; then
        $ECHO "${RED}Fail - Can't find either $MYCNF or $MYSQLDCNF${END}"
        (( STAT = $STAT + 1 ))
    elif [ ! "$MYSQL_MEMORY_GIB" ] ; then
        $ECHO "${RED}Fail - Variable innodb_buffer_pool_size not set${END}"
        (( STAT = $STAT + 1 ))
    elif [ ! "${DB_MEMORY_ARRAY[$MEMORY]}" ] ; then
        $ECHO "${YEL}Warning - Allocated ${MYSQL_MEMORY_GIB} GiB but System RAM non-standard amount so can't complete check${END}"
        (( STAT = $STAT + 1 ))
####elif [ $MYSQL_MEMORY_GIB -ne "${DB_MEMORY_ARRAY[$MEMORY]}" ] ; then
    elif [[ $(echo "$MYSQL_MEMORY_GIB ${DB_MEMORY_ARRAY[$MEMORY]}" | awk '{print ($1 != $2)}') == 1 ]] ; then
        $ECHO "${RED}Fail - Allocated ${MYSQL_MEMORY_GIB} GiB but recommended to have ${DB_MEMORY_ARRAY[$MEMORY]} GiB${END}"            
        (( STAT = $STAT + 1 ))
    else
        $ECHO "${GRN}OK - Allocated ${MYSQL_MEMORY_GIB} GiB${END}"
    fi
}
check_mysql_service_status()
{
    $ECHO -n "Checking MySQL service status ... "
    RES=$(systemctl status mysql.service |egrep '(Active:|.service)' |grep -v CGroup)
    if [ "$(echo $RES |grep ' active')" ] ; then
        $ECHO "${GRN}OK - MySQL service is active${END}"
    else
        $ECHO "${RED}Fail - MySQL service not active on this server${END}"
        (( STAT = $STAT + 1 ))
    fi
}
check_mysql_is_listening()
{
    $ECHO -n "Checking MySQL is listening on port 3306 ... "
    MYSQL_LISTENING=$(netstat -tapn |grep 3306 |egrep '(LISTEN|ESTABLISHED)' |grep 'tcp')
    if [ "$MYSQL_LISTENING" ] ; then
        $ECHO "${GRN}OK - MySQL is listening on port 3306${END}"
    else
        $ECHO "${RED}Fail - MySQL not listening on port 3306${END}"
        (( STAT = $STAT + 1 ))
    fi
}
check_xtrabackup_or_mysqldump_or_none()
{
    if [ -r $ENCRYPTION_KEY_FILE -a -r $LOCALBINDIR/backup-mysql.sh ] ; then
        BACKUP_METHOD=XTRABACKUP
    elif [ -r $DBBACKUPS_DIR/$MYSQLDUMP_SCRIPT ] ; then
        BACKUP_METHOD=MYSQLDUMP
    else
        BACKUP_METHOD=NONE
    fi
}
check_xtrabackup_script_version()
{
    check_customer_script_version $XTRABACKUP_SCRIPT
    # Sets $CHECK_STATUS and SCRIPT_VER on exit
}
check_xtrabackup_installation()
{
    # have to check version of ncxtrabackup.sh is not 1.15 which is the version right before
    # the verify code was added so when testing before ncxtrabackup.sh 1.16 is released and the
    # code finds it has latest (which is true during testing) it doesn't try to run the verify
    $ECHO -n "Checking Xtrabackup installation ... "
    if [ "$CHECK_STATUS" = "HASLATEST" -a "$SCRIPT_VER" != "1.15" ] ; then
        $ECHO "Calling './$XTRABACKUP_SCRIPT verify' ..."
        ./$XTRABACKUP_SCRIPT verify --from-ncsupport
        ISSUES_FROM_CHECK=$?
        (( STAT = $STAT + $ISSUES_FROM_CHECK ))
    else
        $ECHO "Download latest $XTRABACKUP_SCRIPT to enable this check"
        # Not a warning as such as we have that already from previous check
        # so don't increment STAT here. We've already done it for ncxtrabackup.sh
        # being old above 
    fi
}
check_xtrabackup_backups()
{
    $ECHO -n "Checking Xtrabackup backup status ... "
    TODAY=$(date +%Y-%m-%d)
    if [ -d $DBBACKUPS_DIR/$TODAY -a "$(tail -n 1 $DBBACKUPS_DIR/backup.log 2>/dev/null |grep 'Starting backup')" ] ; then
        $ECHO "${GRN}OK - Backup is currently running${END}"
    else
        if [ -d $DBBACKUPS_DIR/$TODAY -a "$(tail -n 1 $DBBACKUPS_DIR/$TODAY/backup-progress*.log 2>/dev/null |grep 'completed OK')" ] ; then
            $ECHO "${GRN}OK - Backups have completed successfully today${END}"
        else
            if [ "$(crontab -l 2>/dev/null |egrep '^#[ 0-9].*backup-mysql.sh')" ] ; then
                $ECHO "${YEL}Warning - Xtrabackup crontab entry commented out${END}"
                (( STAT = $STAT + 1 ))
            else
                if [ "$(crontab -l 2>/dev/null |egrep '^[ 0-9].*backup-mysql.sh')" ] ; then
                    $ECHO "${YEL}Warning - No backups today - manual check required${END}"
                    (( STAT = $STAT + 1 ))
                else
                    $ECHO "${YEL}Warning - No scheduled backup configured - manual check required${END}"
                    (( STAT = $STAT + 1 ))
                fi
            fi
        fi
    fi
}
check_mysqldump_script_version()
{
    $ECHO -n "Checking MySQLdump $MYSQLDUMP_SCRIPT script version ... "
    MYSQLDUMP_SCRIPT_VER=$(grep "# Version " $DBBACKUPS_DIR/$MYSQLDUMP_SCRIPT 2>/dev/null |head -n 1 |awk -F' ' '{print $3}')
    LATEST_MYSQLDUMP_SCRIPT_VER=$MYSQLDUMP_SCRIPT_VERSION
    if [ ! "$MYSQLDUMP_SCRIPT_VER" ] ; then
        $ECHO "${YEL}Warning - Has an old $MYSQLDUMP_SCRIPT but v$LATEST_MYSQLDUMP_SCRIPT_VER is available${END}"
        (( STAT = $STAT + 1 ))
    elif [[ $(echo "$MYSQLDUMP_SCRIPT_VER $LATEST_MYSQLDUMP_SCRIPT_VER" | awk '{print ($1 < $2)}') == 1 ]] ; then
        $ECHO "${YEL}Warning - Has v$MYSQLDUMP_SCRIPT_VER but v$LATEST_MYSQLDUMP_SCRIPT_VER is available${END}"
        (( STAT = $STAT + 1 ))
    else
        $ECHO "${GRN}OK - Has latest version (v$LATEST_MYSQLDUMP_SCRIPT_VER)${END}"
    fi
}
check_mysqldump_using_dump_replica_switch()
{
    $ECHO -n "Checking mysqldump using correct switch ... "
    DUMP_REPLICA_PRESENT=$(grep -e "--dump-replica" $DBBACKUPS_DIR/$MYSQLDUMP_SCRIPT 2>/dev/null)
    if [ "$DUMP_REPLICA_PRESENT" ] ; then
        $ECHO "${GRN}OK - Using --dump-replica switch${END}"
    else
        $ECHO "${YEL}Warning - Using --dump-slave switch - should use --dump-replica${END}"
        (( STAT = $STAT + 1 ))
    fi
}
check_mysqldump_backups()
{
    $ECHO -n "Checking mysqldump backup status ... "
    cd $DBBACKUPS_DIR
    THERES_A_BACKUP=$(find . -mtime 1 -name "*.gz")
    if [ "$THERES_A_BACKUP" ] ; then
        $ECHO "${GRN}OK - Backup exists and is less than 24 hours old${END}"
    else
        if [ "$(crontab -l 2>/dev/null |egrep '^#[ 0-9].*mysqlbackup.sh')" ] ; then
            $ECHO "${YEL}Warning - mysqldump crontab entry commented out${END}"
            (( STAT = $STAT + 1 ))
        else
            if [ "$(crontab -l 2>/dev/null |egrep '^[ 0-9].*mysqlbackup.sh')" ] ; then
                $ECHO "${YEL}Warning - No backup within 24 hours - manual check required${END}"
                (( STAT = $STAT + 1 ))
            else
                $ECHO "${YEL}Warning - No scheduled backup configured - manual check required${END}"
                (( STAT = $STAT + 1 ))
            fi
        fi
    fi
    cd $OLDPWD      # return to previous directory to stop ugly file glob issues
}

#################################################### ZooKaf checks ####################################################

# Little function to get the Kafka Server ID
get_this_server_id()
{
    grep ^broker.id= $KAFKA_CONFIG |awk -F= '{print $2}'
}

# checks for Zookeeper/Kafka servers
check_nczookaf_version()
{
    check_customer_script_version $NCZOOKAF_SCRIPT
    NCZOOKAF_SCRIPT_STATUS=$CHECK_STATUS
}
check_broker_status()
{
    $ECHO -n "Checking broker connection status ... "
    OUTPUT=$(./$NCZOOKAF_SCRIPT test)
    if [ $? -ne 0 ] ; then
        $ECHO "${YEL}Warning - Broker test not successful${END}"
        (( STAT = $STAT + 1 ))
    else
        $ECHO "${GRN}OK - Broker check passed${END}"
    fi
}
check_red_box_config()
{
    $ECHO -n "Checking Red Boxes config ... "
    OUTPUT=$(./$NCZOOKAF_SCRIPT debug |sed -e '1,/^WatchedEvent state/d')
    if [ ${PIPESTATUS[0]} -ne 0 ] ; then
        $ECHO "${YEL}Warning - Could not check Red Boxes config${END}"
        (( STAT = $STAT + 1 ))
    else
        if [ "$(grep '"clusterNodes":' <<< $OUTPUT)" ] ; then
            $ECHO "${GRN}OK - Red Boxes has been configured${END}"
        else
            $ECHO "${YEL}Warning - Red Boxes has not been configured${END}"
            (( STAT = $STAT + 1 ))
        fi
    fi
}
check_replication_factor()
{
    $ECHO -n "Checking Replication factor ... "
    OUTPUT=$(./$NCZOOKAF_SCRIPT showrep)
    if [ $? -ne 0 ] ; then
        $ECHO "${YEL}Warning - Could not check Replication factor${END}"
        (( STAT = $STAT + 1 ))
    else
        if [ "$(grep 'ReplicationFactor: 3' <<< $OUTPUT)" -a "$(grep 'Replicas: 1,2,3' <<< $OUTPUT)" ] ; then
            $ECHO "${GRN}OK - Replication has been configured${END}"
        else
            if [ $SERVER_COUNT -gt 1 ] ; then
                $ECHO "${YEL}Warning - Replication has not been configured - manual review required${END}"
                (( STAT = $STAT + 1 ))
            else
                $ECHO "${GRN}OK - Replication not required with a single Zookeeper/Kafka server${END}"
            fi
        fi
    fi
}
check_ssl_cert_zookaf()
{
    $ECHO -n "Checking SSL certificate expiry ... "
    if [ "$ZOOKAF_SSL" ] ; then
        RES=$(openssl s_client -servername $SERVER -connect $SERVER:9192 2>/dev/null |openssl x509 -noout -dates)
        EXPIRE_DATE=$(echo "$RES" |grep 'notAfter=' |awk -F= '{print $2}' |awk '{print $1, $2, $4, $3}')
        EXPIRE_SECS=$(date --date="$EXPIRE_DATE" +"%s") # convert to an epoch value
        START_DATE=$(echo "$RES" |grep 'notBefore=' |awk -F= '{print $2}' |awk '{print $1, $2, $4, $3}')
        START_SECS=$(date --date="$START_DATE" +"%s") # convert to an epoch value
        TODAY_DATE=$(date +"%b %d %Y %T")               # todays's date in "Mmm DD YYYY hh:mm:ss" format
        TODAY_SECS=$(date --date="$TODAY_DATE" +"%s")   # convert to an epoch value
        (( EXPIRE_DAYS = ( $EXPIRE_SECS - $TODAY_SECS ) / 86400 ))        # seconds to days
        (( VALID_DAYS = ( $EXPIRE_SECS - $START_SECS ) / 86400 ))         # seconds to days
        if [ "$EXPIRE_SECS" -lt "$TODAY_SECS" ] ; then
            $ECHO "${RED}Fail - Expired $EXPIRE_DATE${END}"
            (( STAT = $STAT + 1 ))
        else
            (( TODAY_PLUS_30_DAYS = $TODAY_SECS + 2592000 ))    # add 30 days of seconds
            if [ "$EXPIRE_SECS" -lt "$TODAY_PLUS_30_DAYS" ] ; then
                $ECHO "${YEL}Warning - Expires $EXPIRE_DATE ($EXPIRE_DAYS days)${END}"
                (( STAT = $STAT + 1 ))
            else
                if [ "$VALID_DAYS" -gt $MAX_VALIDITY ] ; then
                    $ECHO "${YEL}Warning - Certificate validity period length > $MAX_VALIDITY days (Apple devices only)${END}"
                    (( STAT = $STAT + 1 ))
                else
                    $ECHO "${GRN}OK - Expires $EXPIRE_DATE ($EXPIRE_DAYS days)${END}"
                fi
            fi
        fi
    else
        $ECHO "${GRN}OK - Not using SSL${END}"
    fi
}

#################################################### Misc functions for health checks ####################################################

check_customer_script_version()
{
    # Takes 1 parameter - the script name to check
    SCRIPT_NAME=$1
    # Sets CHECK_STATUS to: NOTEXIST, HASOLDVER, HASLATEST, UNABLETOCHECK or CHECKDISABLED
    # Sets SCRIPT_VER to the version number of the script
    CHECK_STATUS=
    SCRIPT_VER=
    $ECHO -n "Checking ${SCRIPT_NAME} version ... "
    if [ ! -e ${SCRIPT_NAME} ] ; then
        $ECHO "${RED}Fail - Cannot find ${SCRIPT_NAME}${END}"
        (( STAT = $STAT + 1 ))
        CHECK_STATUS=NOTEXIST
    elif [ ! -r ~/.disable_script_version_check ] ; then
        SCRIPT_VER=$(grep -a ^VER= ${SCRIPT_NAME} |head -n 1 |awk -F'=' '{print $2}')

        OUTPUT_SSL=$(curl -m 2 -s $UBUNTU20_MIRROR_SSL/script-versions/${SCRIPT_NAME}.version) || \
        OUTPUT=$(curl -m 2 -s $UBUNTU20_MIRROR/script-versions/${SCRIPT_NAME}.version)
        if [ "$OUTPUT_SSL" ] ; then
            USE_MIRROR=$UBUNTU20_MIRROR_SSL
            OUTPUT=$OUTPUT_SSL
            #$ECHO -n "${GRN}[using SSL]${END} - "
        else
            if [ "$OUTPUT" ] ; then
                USE_MIRROR=$UBUNTU20_MIRROR
                #$ECHO -n "${RED}[non SSL]${END} - "
            fi
        fi
        if [ "$USE_MIRROR" ] ; then
            LATEST_SCRIPT=$(echo "$OUTPUT" |awk '{print $2}')
            if [[ $(echo "$SCRIPT_VER $LATEST_SCRIPT" | awk '{print ($1 < $2)}') == 1 ]] ; then
                $ECHO "${YEL}Warning - Has v$SCRIPT_VER but v$LATEST_SCRIPT is available${END}"
                (( STAT = $STAT + 1 ))
                CHECK_STATUS=HASOLDVER
            else
                $ECHO "${GRN}OK - Has latest version (v$LATEST_SCRIPT)${END}"
                CHECK_STATUS=HASLATEST
            fi
        else
            $ECHO "${YEL}Warning - Unable to check version${END}"
            (( STAT = $STAT + 1 ))
            CHECK_STATUS=UNABLETOCHECK
        fi
    else
        $ECHO "${YEL}Warning - Version checking disabled${END}"
        (( STAT = $STAT + 1 ))
        CHECK_STATUS=CHECKDISABLED
    fi
}


####################################################################################################
# View the last Health Check report created
###########################################
view_last_health_check()
{
    $ECHO "\nViewing last health check ...\n"
    REMOTE_HEALTHCHECKDIR=/tmp
    REMOTE_HEALTHCHECK_WC=$REMOTE_HEALTHCHECKDIR/healthcheck_*
    LAST_HEALTHCHECK=$(ls -1 $REMOTE_HEALTHCHECK_WC 2>/dev/null |tail -n 1)
    if [ "$LAST_HEALTHCHECK" ] ; then
        cat $LAST_HEALTHCHECK
    else
        $ECHO "\nNo health check files found"
    fi
    $ECHO -n "\nPress Enter to continue "
    read res
}

####################################################################################################
#                                                                                                  #
#                        Any 'read' command will in the while loop below will                      #
#                        need to use: '-u 1' to make it take input from stdin                      #
#                                                                                                  #
####################################################################################################

####################################################################################################
# Fix (Some) Health Check issues
################################
fix_health_check_problems()
{
    $ECHO "\nFixing problems found in last health check ...\n"

    collect_information             # just in case user hasn't just run a Health Check

    REMOTE_HEALTHCHECKDIR=/tmp
    REMOTE_HEALTHCHECK_WC=$REMOTE_HEALTHCHECKDIR/healthcheck_*
    LAST_HEALTHCHECK=$(ls -1 $REMOTE_HEALTHCHECK_WC 2>/dev/null |tail -n 1)
    if [ "$LAST_HEALTHCHECK" ] ; then
        real_fix_health_check_problems
    else
        $ECHO "\nNo health check files found"
    fi
    $ECHO -n "\nPress Enter to continue "
    read res
}
real_fix_health_check_problems()
{    
    FAILS_AND_WARNINGS=$(egrep '(Fail|Warning)' $LAST_HEALTHCHECK)
    $ECHO "Last health check: $LAST_HEALTHCHECK\n"
    echo "Fails and Warnings:"
    $ECHO "$FAILS_AND_WARNINGS\n"
    ISSUES_FIXED=0
    echo "Fixing the issues we can ..."

    while read LINE ; do                            # SEE NOTE ABOVE
        case "$LINE" in
        *Open\ file\ limits\ \(root\)*)
            echo "Setting open file limits (root) to 100000"
            echo -e "root soft nofile 100000\nroot hard nofile 100000" > $XTRABACKUP_FILE_LIMITS
            (( ISSUES_FIXED = ISSUES_FIXED + 1 ))
            ;;
        *Open\ file\ limits*)
            echo "Setting open file limits to 100000"
            echo -e "* soft nofile 100000\n* hard nofile 100000" > $NERVECENTRE_FILE_LIMITS
            (( ISSUES_FIXED = ISSUES_FIXED + 1 ))
            ;;
        *Large\ files\ found*)
            AFTER=$(echo "$LINE" |awk -F: '{print $2}' |sed 's/[^[:print:]]//' |awk -F[ '{print $1}')
            AFTER=$(trim $AFTER)
            echo "Large files: $AFTER"
            FILES=$(egrep -A$AFTER 'Large files found' $LAST_HEALTHCHECK |tail -n +2 |awk '{print $9}')
            echo "$FILES"
            remove_files "$FILES"
            ;;
        *Heap\ dumps\ exist*)
            AFTER=$(echo "$LINE" |awk -F: '{print $2}' |sed 's/[^[:print:]]//' |awk -F[ '{print $1}')
            AFTER=$(trim $AFTER)
            echo "Heap dumps: $AFTER"
            FILES=$(egrep -A$AFTER 'Heap dumps exist' $LAST_HEALTHCHECK |tail -n +2)
            echo "$FILES"
            cd $NCDIR
            remove_files "$FILES"
            cd $OLDPWD      # return to previous directory to stop ugly file glob issues
            ;;
        *Time\ not\ synced*NTP)
            echo "Restarting NTP service"
            service ntp restart
            (( ISSUES_FIXED = ISSUES_FIXED + 1 ))
            ;;
        *Time\ not\ synced*Chrony)
            echo "Restarting Chrony service"
            service chrony restart
            (( ISSUES_FIXED = ISSUES_FIXED + 1 ))
            ;;
        *Old\ installs\ present*)
            AFTER=$(echo "$LINE" |awk -F: '{print $2}' |sed 's/[^[:print:]]//' |awk -F[ '{print $1}')
            AFTER=$(trim $AFTER)
            echo "Old installs: $AFTER"
            DIRS=$(egrep -A1 'Old installs present' $LAST_HEALTHCHECK |tail -n +2)
            echo "$DIRS"
            remove_old_installs "$DIRS"
            ;;
        *Fonts\ not\ installed*)
            echo "Installing fonts"
            apt update -y && apt -y install fontconfig
            STAT=$?
            if [ $STAT -ne 0 ] ; then
                $ECHO "${RED}Unable to install fonts - check connection to mirror${END}"
            else
                sudo fc-cache -fv
                (( ISSUES_FIXED = ISSUES_FIXED + 1 ))
            fi
            ;;
        *Checking\ NC\ RAM\ allocation*Can\'t\ find*)
            create_nervecentre_conf_file
            (( ISSUES_FIXED = ISSUES_FIXED + 1 ))
            ;;
        *Superfluous\ or\ unexpected\ lines\ found*)
            rebuild_nervecentre_conf
            if [ $? -eq 0 ] ; then
                (( ISSUES_FIXED = ISSUES_FIXED + 1 ))
            fi
            ;;
        *\ -\ sar\ is*)
            install_and_configure_sar
            ;;
            esac
    done <<< "$FAILS_AND_WARNINGS"
    
    if [ $ISSUES_FIXED -eq 0 ] ; then
        $ECHO "\nNo fixable issues I'm afraid"
    else
        $ECHO "\nIssues fixed: $ISSUES_FIXED"
    fi
}
remove_old_installs()
{
    AT_LEAST_ONE_REMOVED=
    REMOVE_LIST="$1"
    if [ "$AFTER" -gt 1 ] ; then
        echo "Enter 'a' to remove all in one go or 'q' to quit fixing this issue"
    fi
    res=
    for i in $REMOVE_LIST ; do
        if [ "$res" != "a" ] ; then
            echo -n "Remove $NCDIR/$i (y/n"
            if [ "$AFTER" -gt 1 ] ; then
                echo -n "/a/q) "
            else
                echo -n ") "
            fi
            read -u 1 res
            case "$res" in
             Y*|y*) echo Removing $NCDIR/$i
                    rm -fr $NCDIR/$i
                    AT_LEAST_ONE_REMOVED=Y
                    ;;
             A*|a*) echo Removing $NCDIR/$i
                    rm -fr $NCDIR/$i
                    AT_LEAST_ONE_REMOVED=Y
                    res=a
                    ;;
             Q*|q*) break
                    ;;
            esac
        else
            echo Removing $NCDIR/$i
            rm -fr $NCDIR/$i
        fi
    done
    if [ "$AT_LEAST_ONE_REMOVED" ] ; then
        (( ISSUES_FIXED = ISSUES_FIXED + 1 ))
    fi
}
remove_files()
{
    AT_LEAST_ONE_REMOVED=
    REMOVE_LIST="$1"
    if [ "$AFTER" -gt 1 ] ; then
        echo "Enter 'a' to remove all in one go or 'q' to quit fixing this issue"
    fi
    res=
    for i in $REMOVE_LIST ; do
        if [ "$res" != "a" ] ; then
            echo -n "Remove $i (y/n"
            if [ "$AFTER" -gt 1 ] ; then
                echo -n "/a/q) "
            else
                echo -n ") "
            fi
            read -u 1 res
            case "$res" in
             Y*|y*) echo Removing $i
                    rm -f $i
                    AT_LEAST_ONE_REMOVED=Y
                    ;;
             A*|a*) echo Removing $i
                    rm -f $i
                    AT_LEAST_ONE_REMOVED=Y
                    res=a
                    ;;
             Q*|q*) break
                    ;;
            esac
        else
            echo Removing $i
            rm -f $i
        fi
    done
    if [ "$AT_LEAST_ONE_REMOVED" ] ; then
        (( ISSUES_FIXED = ISSUES_FIXED + 1 ))
    fi
}
rebuild_nervecentre_conf()
{
    AFTER=$(echo "$LINE" |awk -F: '{print $2}' |sed 's/[^[:print:]]//' |awk -F[ '{print $1}')
    AFTER=$(trim $AFTER)
    echo "Superfluous or unexpected lines in ${NCCONF##*/}: $AFTER"
    if [ ! "$NCVERSION" ] ; then
        $ECHO "${RED}Cannot determine NC version so the ${NCCONF##*/} file cannot be fixed${END}"
        return 190
    fi
    if [ "${NCVERSION%%.*}" -lt 7 ] ; then
        $ECHO "${YEL}NOTE: The ${NCCONF##*/} file cannot be fixed in versions prior to 7.x - manual intervention required${END}"
        return 191
    fi
    LINES=$(egrep -A$AFTER 'Superfluous or unexpected lines found' $LAST_HEALTHCHECK |tail -n +2)
    echo "$LINES"
    cp $NCCONF ${NCCONF}.ncsupport-backup
    create_nervecentre_conf_header Recreated ${NCCONF}.new
    MAXMEMORY_LINE=$(grep ^MAXMEMORY= $NCCONF)
    echo "$MAXMEMORY_LINE" >> ${NCCONF}.new
    while read LINE ; do
        if [ "${LINE}" -a "${LINE:0:1}" != "#" -a "${LINE:0:10}" != "MAXMEMORY=" ] ; then
            if [ "$(grep ^$LINE$ $NCCONFDEF)" ] ; then
                $ECHO "Removing line: $LINE"
            else
                $ECHO "Writing line : $LINE ${CYN}(*** Check if required ***)${END}"
                echo "$LINE" >> ${NCCONF}.new
            fi
        fi
    done < $NCCONF
    mv ${NCCONF}.new $NCCONF
    chown nervecentre: $NCCONF
}
install_and_configure_sar()
{
    SAR_INSTALLED=$(which sar)
    if [ ! "$SAR_INSTALLED" ] ; then
        $ECHO "Installing sar ..."
        apt update -y && apt -y install sysstat
        STAT=$?
        if [ $STAT -ne 0 ] ; then
            $ECHO "${RED}Unable to install sar - check connection to mirror${END}"
            return $STAT
        fi
    fi

    SAR_ENABLED=$(grep 'ENABLED.*true' $DEFAULT_SYSSTAT)
    if [ ! "$SAR_ENABLED" ] ; then
        $ECHO "Enabling sar ..."
        cp -p $DEFAULT_SYSSTAT ${DEFAULT_SYSSTAT}.bak 2>/dev/null
        awk -F= '{
                  if ($1 != "HISTORY" && $1 != "ENABLED") {
                        print $0
                  }
        } END {
                print "ENABLED=\"true\""
                print "HISTORY=28"
        }' $DEFAULT_SYSSTAT > /tmp/sysstat
        cp /tmp/sysstat $DEFAULT_SYSSTAT
    fi

    SAR_CRON_ENTRY=$(grep debian-sa1 $SYSSTAT_CRON 2>/dev/null |grep '*/5')
    if [ ! "$SAR_CRON_ENTRY" ] ; then
        $ECHO "Scheduling sar to run every 5 mins ..."
        cp -p $SYSSTAT_CRON ${SYSSTAT_CRON}.bak 2>/dev/null
        echo "# The first element of the path is a directory where the debian-sa1
# script is located
PATH=/usr/lib/sysstat:/usr/sbin:/usr/sbin:/usr/bin:/sbin:/bin

# Activity reports every 5 minutes everyday
*/5 * * * * root command -v debian-sa1 > /dev/null && debian-sa1 1 1

# Additional run at 23:59 to rotate the statistics file
59 23 * * * root command -v debian-sa1 > /dev/null && debian-sa1 60 2" > $SYSSTAT_CRON
    fi

    service sysstat restart
    (( ISSUES_FIXED = ISSUES_FIXED + 1 ))
    $ECHO "Sar installed and configured"
}

####################################################################################################
# Edit NC RAM allocation
########################

edit_nc_ram_allocation()
{
    if [ -r $PROPSFILE ] ; then         # this is an NC machine
        collect_information
        real_edit_nc_ram_allocation
    else
        $ECHO "\n${RED}This is not an NC server so you cannot do this${END}\n"
        sleep 1
    fi
}
real_edit_nc_ram_allocation()
{
    $ECHO "\nEdit NC RAM Allocation\n"
    if [ ! -r $NCCONF ] ; then
        create_nervecentre_conf_file
    fi
    VALID_AMOUNT_OF_MEMORY=${NC_MEMORY_ARRAY[$MEMORY]}
    if [ ! "$VALID_AMOUNT_OF_MEMORY" ] ; then
        ADDITIONAL_TEXT="(System has $MEMORY GB - should be 4, 8, 16, 32 or 64)"
    else
        ADDITIONAL_TEXT=
    fi
    if [ "$COMBO" ] ; then
        echo "Sys type  : $SERVER_TYPE"
    fi
    printf "System RAM: %2s GB  ${YEL}%s${END}\n" $MEMORY "$ADDITIONAL_TEXT"
    #MEMORY_MB=$(echo $MEMORY |awk '{val = $1 * 1024; printf "%2.0f\n", val}')
    printf "Cur NC RAM: %2s GiB\n" $NC_MEMORY_GIB
    echo
    if [ "$VALID_AMOUNT_OF_MEMORY" ] ; then
        echo "Recommended values for MAXMEMORY for standard System RAM amounts:"
        RECOMMENDED_NC_MEMORY=
        for i in 64 32 16 8 4 ; do
            if [ $i -le $MEMORY -a ! "$RECOMMENDED_NC_MEMORY" ] ; then
                COL=$BOLD
                RECOMMENDED_NC_MEMORY=${NC_MEMORY_ARRAY[$i]}
            else
                COL=$END
            fi
            printf "  ${COL}For %2s GB System RAM, recommended MAXMEMORY is %2s GiB${END}\n" $i ${NC_MEMORY_ARRAY[$i]}
        done
    fi
    NEW_NC_MEMORY=
    while [ ! "$NEW_NC_MEMORY" ] ; do
        if [ "$VALID_AMOUNT_OF_MEMORY" ] ; then
            getres "Use ${BOLD}recommended${END} value (y/n) or q to quit: "
            case $res in
             y) NEW_NC_MEMORY=$RECOMMENDED_NC_MEMORY
                ;;
             n) get_custom_value
                NEW_NC_MEMORY=$CUSTOM_NC_MEMORY
                ;;
             q) NEW_NC_MEMORY=
                break
                ;;
             *) $ECHO "${RED}Error - Enter y/n or q to quit${END}"
                NEW_NC_MEMORY=
                ;;
            esac
        else
            echo "System RAM is a non-standard value so you must enter a custom value for MAXMEMORY"
            get_custom_value
            if [ "$CUSTOM_NC_MEMORY" ] ; then
                NEW_NC_MEMORY=$CUSTOM_NC_MEMORY
            else
                break
            fi
        fi
        if [ "$NEW_NC_MEMORY" ] ; then
            $ECHO "\nNew NC RAM: $NEW_NC_MEMORY GiB"
            getres "Is this correct? (y/n): "
            case $res in
            y*) sed -i -e "s/MAXMEMORY=.*/MAXMEMORY=${NEW_NC_MEMORY}g/" $NCCONF
                $ECHO "\nUpdated $NCCONF"
                ;;
             *) NEW_NC_MEMORY=
                ;;
            esac
        fi
    done
}
get_custom_value()
{
    CUSTOM_NC_MEMORY=
    while [ ! "$CUSTOM_NC_MEMORY" ] ; do
        getres "Enter custom value in GiB or q to quit: "
        case $res in
        "") $ECHO "${RED}Error - Enter custom value${END}"
            CUSTOM_NC_MEMORY=
            ;;
         q) CUSTOM_NC_MEMORY=
            break
            ;;
         *) res=${res//[!1-9]+/}                            # remove non numerics
            if [ "$res" -eq "$res" ] 2>/dev/null ; then     # integer check
                if [ $res -gt 1000 ] ; then                 # do not allow MiB values to be entered now
                    $ECHO "${RED}Error - Custom value must be in GiB${END}"
                    CUSTOM_NC_MEMORY=
                else
                    if [ $res -lt $MEMORY ] ; then       # check value is less than System RAM
                        CUSTOM_NC_MEMORY=$res
                    else
                        $ECHO "${RED}Error - Custom value must be less than System RAM${END}"
                        CUSTOM_NC_MEMORY=
                    fi
                fi
            else
                $ECHO "${RED}Error - Custom value must be an integer${END}"
            fi
            ;;
        esac
    done
}

create_nervecentre_conf_header()
{
    ACTION=$1
    FILENAME=$2
    echo -e "#
# Configuration variables used by the NC start/stop script.
# Values in this file override values set in $NCCONFDEF
# $ACTION by ncsupport.sh v$VER ($(date))
#" > $FILENAME
}
create_nervecentre_conf_file()
{
    echo "There is no ${NCCONF##*/} file - creating from default ..."
    create_nervecentre_conf_header Created $NCCONF
    MAXMEMORY_LINE=$(grep ^MAXMEMORY= $NCCONFDEF)
    echo "$MAXMEMORY_LINE" >> $NCCONF
    chown nervecentre: $NCCONF
}

####################################################################################################
# Backup server config to DR box
################################
backup_server_config_to_dr()
{
    if [ -r $PROPSFILE ] ; then         # this is an NC machine
        real_backup_server_config_to_dr
    else
        $ECHO "\n${RED}This is not an NC server so you cannot do this${END}"
    fi
    $ECHO -n "\nPress Enter to continue "
    read res
}
real_backup_server_config_to_dr()
{
    $ECHO "\nBackup server config to DR\n"
    if [ ! "$VALID_DR_IP_ADDRESS" ] ; then
        $ECHO "${ERRCOL}Error - cannot extract DR server IP address from props file${END}"
        DEST_SERVER=    # ask where the logs should go again
        return
    else
        DEST_SERVER=$DR_IP_ADDRESS
    fi

    TAR_FILE=/tmp/Config-${THIS_HOST}.tgz
    CONFIG_LOCATIONS="/usr/local/nc/custdata/audio
/usr/local/nc/custdata/Certs
/usr/local/nc/custdata/CustBodyMaps
/usr/local/nc/custdata/customconf
/usr/local/nc/custdata/forms
/usr/local/nc/custdata/init
/usr/local/nc/custdata/maps
/usr/local/nc/custdata/meshdata/[a-ce-z]*
/usr/local/nc/custdata/reportdefn"

    if [ $DEST_SERVER != "none" ] ; then
        $ECHO "Creating tar file: ${BOLD}$TAR_FILE${END}
containing config:
${BOLD}$CONFIG_LOCATIONS${END}
and sending to   : ${BOLD}$DEST_SERVER$:$SERVERCONFIGS_DIR${END}"
    fi

    CONTINUE=
    while [ ! "$CONTINUE" ] ; do
        getres "Continue? (y/n): " lowercase
        case $res in
            q)  CONTINUE=q
                ;;
           "")  $ECHO "${ERRCOL}Error - need a y/n answer${END}"
                CONTINUE=
                ;;
            *)  CONTINUE=$res
                ;;
        esac
    done
    if [ "$CONTINUE" = "y" ] ; then
        create_config_tar_file
        if [ $DEST_SERVER != "none" ] ; then
            save_config_to_server
        fi
    fi
}

# create the config tar file
create_config_tar_file()
{
    $ECHO "\nCreating tar file: $TAR_FILE ..."
    cd $NCHOME
    tar zcf $TAR_FILE $(ls -d $CONFIG_LOCATIONS 2>/dev/null)
    chown $NCUSER: $TAR_FILE
    chmod 700 $TAR_FILE
    LATEST_BUILD=
    if [ "$(grep ^ServerRole=Primary$ $PROPSFILE |awk -F= '{print $2}')" ] ; then   # only want to send tarball if we are App1
        LATEST_BUILD=$NCHOME/NCbuilds/$(ls -rt $NCHOME/NCbuilds/ 2>/dev/null |tail -n 1)
    fi
    cd $OLDPWD      # return to previous directory to stop ugly file glob issues
}

# send the config onto the DR server
save_config_to_server()
{
    $ECHO "\nSending config to $DEST_SERVER ..."
    COMMAND="rsync -rvz --checksum -e ssh $TAR_FILE $LATEST_BUILD  $NCUSER@$DEST_SERVER:$SERVERCONFIGS_DIR"
    echo "$COMMAND"
    if [ $(hostname) != "mint20" ] ; then
        sudo -u $NCUSER $COMMAND
        STAT=$?
    else
        echo "WOULD RUN THIS: $COMMAND"
        STAT=0
    fi
    if [ $STAT -eq 0 ] ; then
        $ECHO "\n${GRN}Config successfully sent to DR${END}"
    else
        $ECHO "\n${RED}There was a problem sending the config to DR${END}"
    fi
}

####################################################################################################
# Search HL7 logs (when it's written)
#####################################
search_hl7_logs()
{
    echo
    echo "Not written yet - watch this space!"
    echo "Will format HL7 logs and allow user to search for text"
# tail -f nchl7transmit.log |tr '\r' '\n'
    echo
    sleep 1
}

####################################################################################################
# Search log files (when it's written)
######################################
search_log_files()
{
    echo
    echo "Not written yet - watch this space!"
    echo "Will allow user to search for text in a group or all log files"
    echo
    sleep 1
}

####################################################################################################
#
##### Actual script starts here #####
#
####################################################################################################

# Determine what type of VM we are running on
NC=
DB=
ZK=
if [ -r $PROPSFILE ] ; then         # this is an NC machine
    NC=Y
fi
RES=$(systemctl status mysql.service 2>/dev/null)
if [ $? -eq 0 ] ; then          # this is a DB machine
    DB=Y
fi
if [ -d $ZOOKEEPER_HOME -a -d $KAFKA_HOME ] ; then  # this is a Zookeeper/Kafka box
    ZK=Y
fi

# Tidying up - look for /home/nervecentreadm/.bash_aliases
# if it doesn't exist create it with some useful aliases
# if it does exist then add any missing aliases
create_or_update_bash_aliases

# More tidying up - remove the old prepare-for-os-patch.sh script. New one has underscores in the name
#                   and the crappy scripts that we used to use to setup sources.list and meta-release
remove_old_redundant_scripts

# More tidying up - ensure all scripts are executable
chmod_755_scripts

# Remove some users we know are not required
remove_redundant_user_accounts

# Silently moves the open file limits lines from /etc/security/limits.conf
# to /etc/security/limits.d/nervecentre.conf if the lines exist in /etc/security/limits.conf
move_open_file_limits_to_new_file

THIS_HOST=$(get_this_host)

##### Main loop #####
MAIN_MENU=Y
while [ "$MAIN_MENU" ] ; do
    $ECHO "\nNC Support Tool - v$VER\n"
    $ECHO "Running on: '${BOLD}$THIS_HOST${END}'\n"
    echo "    1. Save logs for troubleshooting"
    echo "    2. Run 'Health Check' (enter 2q for quick check)"
    echo "    3. Fix problems found in 'Health Check'"
    echo "    4. View last 'Health Check'"
    echo "    5. Edit NC RAM allocation"
    echo "    6. Backup server config to DR"
    echo "    7. Search HL7 logs"
    echo "    8. Search log files"
    getres "Select an option or q to quit: " lowercase
    case $res in
        q)  MAIN_MENU=
            ;;
        1)  save_logs_for_troubleshooting
            ;;
        2)  health_check
            ;;
        2q) health_check_quick
            ;;
        3)  fix_health_check_problems
            ;;
        4)  view_last_health_check
            ;;
        5)  edit_nc_ram_allocation
            ;;
        6)  backup_server_config_to_dr
            ;;
        7)  search_hl7_logs
            ;;
        8)  search_log_files
            ;;
        *)  echo "Invalid entry"
            ;;
    esac
done

exit $?
