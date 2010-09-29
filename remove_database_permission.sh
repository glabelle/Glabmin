#!/bin/bash

#inclusions des procédures communes et de la configuration.
source glabmin.conf
source common.sh

#petite aide du script. Les options -h et -v sont systèmatiques ...
DESCRIPTION="supprimer les droits à un utilisateur sur une base de données pour un domaine"
USAGE="(-b|--base) nom_de_base (-u|--user) nom_utilisateur [options]"
OPTIONS=""


PARAMS=`getopt -o u:,b:,h,v -l user:,base:,help,version -- "$@"`
[ $? != 0 ] && exit 1
eval set -- "$PARAMS"


while true ; do
	case "$1" in
	-u|--user) opt_user="1"	; shift 1
		[ -n "$1" ] && opt_user_val=$1 && shift 1 ;;
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
[ -z "$opt_user" ] && echo "ERROR : User name is missing" && exit 1
[ -z "$opt_base" ] && echo "ERROR : Base name is missing" && exit 1

#argument vs system ckeckings :
[ -z "`query "select name from database_bases where name='$opt_base_val'"`" ] && echo "ERROR : Base $opt_base_val not defined" && exit 1
[ -z "`query "select name from database_users where name='$opt_user_val'"`" ] && echo "ERROR : User $opt_user_val not defined" && exit 1
[ "`query "select domain from database_users where name='$opt_user_val'"`" != "`query "select domain from database_bases where name='$opt_base_val'"`" ] && echo "ERROR : User $opt_base_val and base does not belong to the same domain" && exit 1
[ -z "`query "select base from database_permissions where base='$opt_base_val' and user='$opt_user_val';"`" ] && echo "ERROR : User $opt_user_val is already disabled for database $opt_base_val" && exit 0

#verif
opt_base_val=`query "select base from database_permissions where base='$opt_base_val' and user='$opt_user_val';"`
opt_dbroot_val=`query "select user from database_permissions where base='$opt_base_val' and user='$opt_user_val';"`

#deleting entry ..
query "delete from database_permissions where base='$opt_base_val' and user='$opt_user_val';" || exit 1

#upgrading system level
mysql -N -u$DATABASE_ADMIN_USER -p$DATABASE_ADMIN_PASS -e "use mysql ; revoke all privileges on $opt_base_val.* from '$opt_user_val'@'localhost' ;" && exit 0

#otherwise, something went wrong.
echo "ERROR : something unexpected appened" && exit 1
#peut etre effacer içi l'enregistrement en bdd ??

