#!/bin/bash

#inclusions des procédures communes et de la configuration.
source $(dirname $0)/glabmin.conf
source $(dirname $0)/common.sh

#petite aide du script. Les options -h et -v sont systèmatiques ...
DESCRIPTION="ajouter un service de backup d'un domaine"
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
[ -n "`query "select name from domains where name='$opt_domain_val' and mounted=0"`" ] && error "Domain $opt_domain_val is unmounted" 
[ -n "`query "select domain from backup_domains where domain='$opt_domain_val';"`" ] && error "Service backup for domain $opt_domain_val already present"

#registering new http service
query "insert into backup_domains (domain) values ('$opt_domain_val');" error "Client integrity at risk; aborting"

#verif (pas de vérif a priori ..)

sed -i "s:BM_TARBALL_DIRECTORIES=\":BM_TARBALL_DIRECTORIES=\"$DOMAIN_POOL_ROOT/$opt_domain_val :g" $BACKUP_CONFIG_FILE && exit 0

#otherwise, something went wrong.
error "something unexpected appened"

