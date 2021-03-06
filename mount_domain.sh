#!/bin/bash

#inclusions des procédures communes et de la configuration.
source $(dirname $0)/glabmin.conf
source $SCRIPTSDIR/common.sh

#petite aide du script. Les options -h et -v sont systèmatiques ...
DESCRIPTION="activer un domaine et monter ses bindings mail et bdd"
USAGE="(-d|--domain) nom_domaine [options]"
OPTIONS=""

PARAMS=`getopt -o d:,h,v -l domain:,help,version -- "$@" `
[ $? != 0 ]
eval set -- "$PARAMS"

while true ; do
	case "$1" in
	-d|--domain) opt_domain="1"; shift 1
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
#if no domain or no password, then display help and exit
[ -z "$opt_domain" ] && error "Domain name is missing"


#argument vs system ckeckings :
DB_STATUS="`$DAEMON_DATABASE_SERVER status`"
[ -n "`echo $DB_STATUS|grep 'MySQL is stopped'`" ] && $DAEMON_DATABASE_SERVER start
[ -n "`$DAEMON_DATABASE_SERVER status|grep 'MySQL is stopped'`" ] && error "can't start MySQL"
[ -z "`query "select name from domains where name='$opt_domain_val';"`" ] && error "Domain $opt_domain_val is unknown"
[ -n "`query "select name from domains where name='$opt_domain_val' and mounted=1;"`" ] && warning "Domain $opt_domain_val is already mounted"
[ -n "`query "select name from domains where name='$opt_domain_val' and suspended=1;"`" ] && warning "Domain $opt_domain_val is suspended"

#1) monter/activer le domaine
#activer l'utilisateur du domaine s'il n'est pas suspendu
[ -n "`query "select name from domains where name='$opt_domain_val' and suspended=0;"`" ] && usermod -U $opt_domain_val
#activer les utilisateur des sous-domaines qui ne sont pas suspendus
for opt_subdomain_val in `query "select name from subdomains where domain='$opt_domain_val' and suspended=0;"`
do
	usermod -U "$opt_subdomain_val.$opt_domain_val"
done
#désactiver apache si nécessaire
APACHE_STATUS="`$DAEMON_HTTP_SERVER status`"
( [ -n "`query "select domain from http_domains where domain='$opt_domain_val';"`" ] || [ -n "`query "select domain from https_domains where domain='$opt_domain_val';"`" ] || [ -n "`query "select domain from http_subdomains where domain='$opt_domain_val';"`" ] || [ -n "`query "select domain from https_subdomains where domain='$opt_domain_val';"`" ] ) && [ -n "$APACHE_STATUS" ] && $DAEMON_HTTP_SERVER stop >/dev/null
[ -z "`mount|grep clients-$opt_domain_val`" ] && mount /dev$DOMAIN_POOL_ROOT/$opt_domain_val $DOMAIN_POOL_ROOT/$opt_domain_val
query "update domains set mounted=1 where name='$opt_domain_val';"
[ -n "$APACHE_STATUS" ] && [ -z "`$DAEMON_HTTP_SERVER status`" ] && $DAEMON_HTTP_SERVER start >/dev/null


#2) y'a t'il un pool de mail ? Si oui, on monte sa racine
if [ -n "`query "select domain from mail_domains where domain='$opt_domain_val';"`" ] 
then	
	[ -z "`mount|grep "$MAIL_SYSTEM_POOL$opt_domain_val"`" ] && mount --bind `query "select mailroot from mail_domains where domain='$opt_domain_val';"` $MAIL_SYSTEM_POOL$opt_domain_val
	#on active les boites mails :
	mailquery "update mailbox set active=1 where domain='$opt_domain_val';"
	#on desactives les boites qui n'etaient pas actives à l'origine
	opt_mailbox_list=`query "select suspendatmount from mail_domains where domain='$opt_domain_val';"`
	echo $opt_deactivate_val
	for opt_deactive_val in `query "select suspendatmount from mail_domains where domain='$opt_domain_val';"`
	do
		echo $opt_deactive_val
		mailquery "update mailbox set active=0 where domain='$opt_domain_val' and username='$opt_deactive_val';"
	done
	#remettre a NULL :
	query "update mail_domains set suspendatmount=NULL where domain='$opt_domain_val';"
fi


#3) y'a t'il un ensemble de bases de données ? si oui, monter chacune d'elle
if [ -n "`query "select domain from database_domains where domain='$opt_domain_val';"`" ]
then
    opt_dbroot_val=`query "select dbroot from database_domains where domain='$opt_domain_val';"` &&
    base_list=`query "select name from database_bases where domain='$opt_domain_val';"` &&
    user_list=`query "select name from database_users where domain='$opt_domain_val';"`
	#2) On active les connexion des utilisateurs de bdd associés au domaine (si le domaine n'est pas bani)
	if [ -n "`query "select name from domains where name='$opt_domain_val' and suspended=0;"`" ]
	then
		for opt_user_val in $user_list
		do
			adminquery "RENAME USER '$opt_user_val'@'nohost' TO  '$opt_user_val'@'localhost';";
		done
	fi
    $DAEMON_DATABASE_SERVER stop >/dev/null
    for opt_base_val in $base_list
    do  
        [ -z "`mount|grep "$DB_SYSTEM_POOL$opt_base_val"`" ] && mount --bind $opt_dbroot_val/$opt_base_val/ $DB_SYSTEM_POOL$opt_base_val
    done
    $DAEMON_DATABASE_SERVER start >/dev/null
    
fi

[ -n "`echo $DB_STATUS|grep 'MySQL is stopped'`" ] && [ -z "`$DAEMON_DATABASE_SERVER status|grep 'MySQL is stopped'`" ] && $DAEMON_DATABASE_SERVER stop >/dev/null



