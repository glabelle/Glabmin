#!/bin/bash

#inclusions des procédures communes et de la configuration.
source glabmin.conf
source common.sh

#petite aide du script. Les options -h et -v sont systèmatiques ...
DESCRIPTION="supprimer un utilisateur de base de données mysql"
USAGE="(-d|--domain) nom_du_domaine (-u|--user) nom_utilisateur [options]"
OPTIONS=""

PARAMS=`getopt -o d:,u:,h,v -l domain:,user:,help,version -- "$@"`
[ $? != 0 ] && exit 1
eval set -- "$PARAMS"


while true ; do
	case "$1" in
	-d|--domain) opt_domain="1"	; shift 1
		[ -n "$1" ] && opt_domain_val=$1 && shift 1 ;;
        -u|--user) opt_user="1"	; shift 1
		[ -n "$1" ] && opt_user_val=$1 && shift 1 ;;
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
[ -z "$opt_domain" ] && echo "ERROR : Domain name is missing" && exit 1
[ -z "$opt_user" ] && echo "ERROR : User name is missing" && exit 1

#argument vs system ckeckings :
[ -z "`query "select name from domains where name='$opt_domain_val';"`" ] && echo "ERROR : Domain $opt_domail_val is unknown" && exit 1
[ -z "`query "select domain from database_domains where domain='$opt_domain_val';"`" ] && echo "ERROR : Service database for domain $opt_domain_val is disabled" && exit 1
[ -z "`query "select name from database_users where domain='$opt_domain_val' and name='$opt_user_val'"`" ] && echo "ERROR : User $opt_user_val not defined for domain $opt_domain_val" && exit 1

#verif
opt_user_val=`query "select name from database_users where domain='$opt_domain_val' and name='$opt_user_val';"`

#deleting user entry
query "delete from database_users where name='$opt_user_val';"

#upgrading system level
mysql -N -u$DATABASE_ADMIN_USER -p$DATABASE_ADMIN_PASS -e "use mysql ; drop user '$opt_user_val'@'localhost' ;" && exit 0

#otherwise, something went wrong.
echo "ERROR : something unexpected appened" && exit 1
#peut etre effacer içi l'enregistrement en bdd ??

