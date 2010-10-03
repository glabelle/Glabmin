#!/bin/bash

#inclusions des procédures communes et de la configuration.
source $(dirname $0)/glabmin.conf
source $SCRIPTSDIR/common.sh

#petite aide du script. Les options -h et -v sont systèmatiques ...
DESCRIPTION="desactiver un domaine et demonter les bindings"
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
[ -n "`query "select name from domains where name='$opt_domain_val' and suspended=1;"`" ] && warning "Domain $opt_domain_val is suspended"

#démontages .. pas grand chose pour le moment ..

#1) On démonte les bdd :
if [ -n "`query "select domain from database_domains where domain='$opt_domain_val';"`" ] 
then
	opt_dbroot_val=`query "select dbroot from database_domains where domain='$opt_domain_val';"` &&
    base_list=`query "select name from database_bases where domain='$opt_domain_val';"` &&
    user_list=`query "select name from database_users where domain='$opt_domain_val';"`
	#2) On désactive les connexion des utilisateurs de bdd associés au domaine (si le domaine n'est pas bani)
	if [ -n "`query "select name from domains where name='$opt_domain_val' and suspended=0;"`" ]
	then
		for opt_user_val in $user_list
		do
			adminquery "RENAME USER '$opt_user_val'@'localhost' TO  '$opt_user_val'@'nohost';";
		done
	fi
	#3) On démonte les bindings des bases du domaine
	$DAEMON_DATABASE_SERVER stop >/dev/null
    for opt_base_val in $base_list
    do
    	[ -n "`mount|grep "$DB_SYSTEM_POOL$opt_base_val"`" ] && umount $DB_SYSTEM_POOL$opt_base_val
    done
    $DAEMON_DATABASE_SERVER start >/dev/null
fi

#2) y'a t'il un pool de mail ? Si oui, on démonte sa racine (en ayant au préalable désactivé les boites mails ..)
if [ -n "`query "select domain from mail_domains where domain='$opt_domain_val';"`" ]
then
	#mailroot :
	opt_mailroot_val="`query "select mailroot from mail_domains where domain='$opt_domain_val';"`"
	#memorisation des comptes de courriel déjà désactivés :
	opt_disabled_accounts_val="`mailquery "select username from mailbox where active=0;"`"
	[ -n "$opt_disabled_accounts_val" ] && ( query "update mail_domains set suspendatmount='$opt_disabled_accounts_val' where domain='$opt_domain_val';" || error "cannot save suspended mailboxes into database" )
	#desactiver les comptes de courrier du domaine :
	[ -n "$opt_disabled_accounts_val" ] && ( mailquery "update mailbox set active=0 where domain='$opt_domain_val';" || error "cannot suspend mailboxes" )
	if [ -n "`mount|grep "$opt_mailroot_val"`" ]
	then
		if [ -n "`umount $opt_mailroot_val`" ]
		then
			opt_daemon_pop_name="`echo $DAEMON_POP3_SERVER | sed 's/^.*\/\(.*\)$/\1/g'`" 
			[ -n "`ps aux|grep ^$opt_daemon_pop_name`" ] &&  $DAEMON_POP3_SERVER stop && opt_reload_pop3="1"
			opt_daemon_imap_name="`echo $DAEMON_IMAP_SERVER | sed 's/^.*\/\(.*\)$/\1/g'`"
			[ -n "`ps aux|grep ^$opt_daemon_imap_name`" ] && $DAEMON_IMAP_SERVER stop && opt_reload_imap="1"
			[ -n "`umount $opt_mailroot_val/`" ] && error "mail pool $opt_mailroot_val cannot be unmounted"
			[ -n "$opt_reload_imap" ] $DAEMON_IMAP_SERVER start
			[ -n "$opt_reload_pop3" ] $DAEMON_POP3_SERVER start
		fi
	fi
fi

#3) on désactive apache, les utilisateurs unix du domaine et sous domaines puis on démonte et désactive le domaine ..
#couper apache si nécéssaire
APACHE_STATUS="`$DAEMON_HTTP_SERVER status`"
( [ -n "`query "select domain from http_domains where domain='$opt_domain_val';"`" ] || [ -n "`query "select domain from https_domains where domain='$opt_domain_val';"`" ] || [ -n "`query "select domain from http_subdomains where domain='$opt_domain_val';"`" ] || [ -n "`query "select domain from https_subdomains where domain='$opt_domain_val';"`" ] ) && [ -n "$APACHE_STATUS" ] && $DAEMON_HTTP_SERVER stop >/dev/null
[ -n "`mount|grep clients-$opt_domain_val`" ] && umount /dev$DOMAIN_POOL_ROOT/$opt_domain_val
#désactiver les utilisateurs sous-domaine qui ne sont pas suspendus:
for opt_subdomain_val in `query "select name from subdomains where domain='$opt_domain_val' and suspended=0;"`
do
	usermod -L "$opt_subdomain_val.$opt_domain_val"
done 
#desactiver l'utilisateur du domaine s'il ne l'etait pas encore :
[ -n "`query "select name from domains where name='$opt_domain_val' and suspended=0;"`" ] && usermod -L "$opt_domain_val"
#modifier l'état en base
query "update domains set mounted=0 where name='$opt_domain_val';"
#allumer apache si nécessaire
[ -n "$APACHE_STATUS" ] && [ -z "`$DAEMON_HTTP_SERVER status`" ] && $DAEMON_HTTP_SERVER start >/dev/null
[ -n "`echo $DB_STATUS|grep 'MySQL is stopped'`" ] && [ -z "`$DAEMON_DATABASE_SERVER status|grep 'MySQL is stopped'`" ] && $DAEMON_DATABASE_SERVER stop >/dev/null

