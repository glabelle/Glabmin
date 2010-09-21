#!/bin/bash

#inclusions des procédures communes et de la configuration.
source $(dirname $0)/glabmin.conf
source $(dirname $0)/common.sh

#petite aide du script. Les options -h et -v sont systèmatiques ...
DESCRIPTION="supprimer le backup d'un domaine"
USAGE="(-d|--domain) nom_du_domaine [options]"
OPTIONS=""


PARAMS=`getopt -o d:,h,v -l domain:,help,version -- "$@"`
[ $? != 0 ]
eval set -- "$PARAMS"


while true ; do
	case "$1" in
	-d|--domain) opt_domain="1"	; shift 1
		[ -n "$1" ] && opt_domain_val=$1 && shift 1 ;;
	-h|--help) opt_help="1"	; shift 1 ;;
	-v|--version) opt_version="1"; shift 1 ;;
	--) shift ; break ;;
	esac
done

#command line checkings :
#if help wanted, display usage and exit
[ -n "$opt_help" ] && usage && exit 0
#if version, display version and exit 
[ -n "$opt_version" ] && echo "Version $(basename $0) $VERSION" && exit 0
#if no client or no email, then exit
[ -z "$opt_domain" ] && error "Domain name is missing"


#argument vs system ckeckings :
[ -z "`query "select name from domains where name='$opt_domain_val';"`" ] && error "Domain $opt_domain_val is unknown"
[ -z "`query "select domain from backup_domains where domain='$opt_domain_val';"`" ] && error "Service backup for domain $opt_domain_val already disabled"

#deleting entry in glabelle db
query "delete from backup_domains where domain='$opt_domain_val';"

#upgrading system level
filename="glabelle.net`echo $DOMAIN_POOL_ROOT | sed -e 's/\//-/g'`-$opt_domain_val.*.tar.gz"

ftp -in $BACKUP_FTP_SERVER <<EOF
quote USER $BACKUP_FTP_LOGIN
quote PASS $BACKUP_FTP_PASS

binary
mdelete $filename
quit
EOF

#ligne au danger potentiel !!!
rm `ls "/var/archives/$filename"` 

sed -i "s:$DOMAIN_POOL_ROOT/$opt_domain_val ::g" $BACKUP_CONFIG_FILE && exit 0

#otherwise, something went wrong.
error "something unexpected appened, please call scriptmaster !"
