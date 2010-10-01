#!/bin/bash

#inclusions des procédures communes et de la configuration.
source glabmin.conf
source common.sh

#petite aide du script. Les options -h et -v sont systèmatiques ...
DESCRIPTION="supprimer un base de données mysql d'un domaine"
USAGE="(-d|--domain) nom_du_domaine (-b|--base) nom_de_base [options]"
OPTIONS=""

PARAMS=`getopt -o d:,b:,h,v -l domain:,base:,help,version -- "$@"`
[ $? != 0 ] && exit 1
eval set -- "$PARAMS"


while true ; do
	case "$1" in
	-d|--domain) opt_domain="1"	; shift 1
		[ -n "$1" ] && opt_domain_val=$1 && shift 1 ;;
        -b|--base) opt_base="1"	; shift 1
		[ -n "$1" ] && opt_base_val=$1 && shift 1 ;;
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
[ -z "$opt_base" ] && error "Base name is missing"

#argument vs system ckeckings :
[ -z "`query "select name from domains where name='$opt_domain_val';"`" ] && error "Domain $opt_domain_val is unknown"
[ -n "`query "select name from domains where name='$opt_domain_val' and mounted=0"`" ] && error "Domain $opt_domain_val is unmounted" 
[ -z "`query "select domain from database_domains where domain='$opt_domain_val';"`" ] && error "Service database for domain $opt_domain_val is disabled"
[ -z "`query "select name from database_bases where domain='$opt_domain_val' and name='$opt_base_val'"`" ] && error "Base $opt_user_val not defined for domain $opt_domain_val"

#verif
opt_user_val=`query "select name from database_bases where domain='$opt_domain_val' and name='$opt_base_val';"`
opt_dbroot_val=`query "select dbroot from database_domains where domain='$opt_domain_val'"`



#deleting user entry
query "delete from database_bases where name='$opt_base_val';" || error "Client integrity at risk; aborting"

#upgrading system level
$DAEMON_DATABASE_SERVER stop &&
umount $opt_dbroot_val/$opt_base_val &&
rm -fr $opt_dbroot_val/$opt_base_val &&
$DAEMON_DATABASE_SERVER start &&
mysql -N -u$DATABASE_ADMIN_USER -p$DATABASE_ADMIN_PASS -e "use mysql ; drop database $opt_base_val ;" && exit 0

#otherwise, something went wrong.
error "something unexpected appened"
#peut etre effacer içi l'enregistrement en bdd ??

