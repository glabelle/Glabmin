#!/bin/bash

#inclusions des procédures communes et de la configuration.
source $(dirname $0)/glabmin.conf
source $SCRIPTSDIR/common.sh

#petite aide du script. Les options -h et -v sont systèmatiques ...
DESCRIPTION="suspendre un domaine et ses services"
USAGE="(-d|--domain) nom_domaine [options]"
OPTIONS=""


PARAMS=`getopt -o d:,h,v -l domain:,help,version -- "$@" `
[ $? != 0 ]
eval set -- "$PARAMS"

while true ; do
	case "$1" in
	-d|--domain) opt_domain="1"	; shift 1
		[ -n "$1" ] && opt_domain_val=$1 && shift 1 ;;
	-h|--help) opt_help="1"	; shift 1 ;;
	-v|--version) opt_version="1"	; shift 1 ;;
	--) shift ; break ;;
	esac
done

#command line checkings :
#if help wanted, display usage and exit
[ -n "$opt_help" ] && usage && exit 0
#if version, display version and exit 
[ -n "$opt_version" ] && echo "Version $(basename $0) $VERSION" && exit 0
#if no domain or no password, then display help and exit
[ -z "$opt_domain" ] && error "Domain name is missing"

#argument vs system ckeckings :
DB_STATUS="`$DAEMON_DATABASE_SERVER status`"
[ -n "`echo $DB_STATUS|grep 'MySQL is stopped'`" ] && $DAEMON_DATABASE_SERVER start
[ -n "`$DAEMON_DATABASE_SERVER status|grep 'MySQL is stopped'`" ] && error "can't start MySQL"
[ -z "`query "select name from domains where name='$opt_domain_val';"`" ] && error "Domain $opt_domain_val is unknown"
[ -n "`query "select name from domains where name='$opt_domain_val' and mounted=0;"`" ] && warning "Domain $opt_domain_val is unmounted"
[ -n "`query "select name from domains where name='$opt_domain_val' and suspended=1;"`" ] && error "Domain $opt_domain_val is already suspended"


#2) On désactive les connexion des utilisateurs de bdd associés au domaine
if [ -n "`query "select name from domains where name='$opt_domain_val' and mounted=1;"`" ]
then
	user_list=`query "select name from database_users where domain='$opt_domain_val';"`
	if [ -n "$user_list" ]
	then
		for opt_user_val in $user_list
		do
			adminquery "RENAME USER '$opt_user_val'@'localhost' TO  '$opt_user_val'@'nohost';";
		done
		$DAEMON_DATABASE_SERVER restart >/dev/null
	fi
fi

#2) y'a t'il un pool de mail ? Si oui, on démonte sa racine
#peut etre débrancher les serveurs de courrier, non ?
#if [ -n "`query "select domain from mail_domains where domain='$opt_domain_val';"`" ] 
#then	
#fi

#3) si nécessaire, on desactive l'utilisateur UNIX du domaine
[ -n "`query "select name from domains where name='$opt_domain_val' and mounted=1;"`" ] && usermod -L "$opt_domain_val"
#mise a niveau BDD
query "update domains set suspended=1 where name='$opt_domain_val';"
#recharger apache si nécessaire
APACHE_STATUS="`$DAEMON_HTTP_SERVER status`"
( [ -n "`query "select domain from http_domains where domain='$opt_domain_val';"`" ] || [ -n "`query "select domain from https_domains where domain='$opt_domain_val';"`" ] ) && [ -n "$APACHE_STATUS" ] && $DAEMON_HTTP_SERVER reload >/dev/null


