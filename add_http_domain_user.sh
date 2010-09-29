#!/bin/bash

#inclusions des procédures communes et de la configuration.
source glabmin.conf
source common.sh

#petite aide du script. Les options -h et -v sont systèmatiques ...
DESCRIPTION="ajouter un utilisateur ayant un acces au service http restreint d'un domaine"
USAGE="(-d|--domain) nom_du_domaine (-u|--user) nom_utilisateur [options]"
OPTIONS="(-p|--password) mot_de_passe // mot de passe de l'utilisateur (defaut : mot de passe du domaine)"


PARAMS=`getopt -o d:,p:,u:,h,v -l domain:,password:,user:,help,version -- "$@"`
[ $? != 0 ] && exit 1
eval set -- "$PARAMS"

while true ; do
	case "$1" in
	-d|--domain) opt_domain="1"	; shift 1
		[ -n "$1" ] && opt_domain_val=$1 && shift 1 ;;
        -u|--user) opt_user="1"	; shift 1
		[ -n "$1" ] && opt_user_val=$1 && shift 1 ;;
	-p|--password) opt_password="1"	; shift 1
		[ -n "$1" ] && opt_password_val=$1 && shift 1 ;;
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
[ -z "`query "select domain from http_domains where domain='$opt_domain_val';"`" ] && echo "ERROR : Service HTTP for domain $opt_domail_val is disabled" && exit 1
[ -z "$opt_password" ] && opt_password_val=`query "select password from domains where name=(select domain from http_domains where domain='$opt_domain_val');"`
[ -z `echo $opt_user_val|egrep '^[a-zA-Z]+([-_]?[a-zA-Z0-9]+)$'` ] && echo "ERROR : Invalid user name $opt_user_val" && exit 1
[ "`echo ${#opt_user_val}`" -gt "16"  ] && echo "ERROR : User name $opt_user_val too long" && exit 1
[ -n "`query "select user from http_domains_users where user='$opt_user_val' and domain='$opt_domain_val' "`" ] && echo "ERROR : User $opt_user_val for domain $opt_domain_val already defined" && exit 1

#eventuellement à garder en option
#[ "`query "select count(*) from database_users where domain='$opt_domain_val';"`" -ge "`query "select nbuser from database_domains where domain='$opt_domain_val';"`" ] && echo "ERROR : cannot add another user for domain $opt_domain_val" && exit 1

#registering new http service
query "insert into http_domains_users (domain,user,password) values ('$opt_domain_val','$opt_user_val','$opt_password_val');" || exit 1

#upgrading system level
#nothing to be done ...
exit 0

#otherwise, something went wrong.
echo "ERROR : something unexpected appened" && exit 1
#peut etre effacer içi l'enregistrement en bdd ??

