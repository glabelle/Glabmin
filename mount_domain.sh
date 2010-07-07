#!/bin/bash

#inclusions des procédures communes et de la configuration.
source glabmin.conf
source common.sh

#petite aide du script. Les options -h et -v sont systèmatiques ...
DESCRIPTION="monter les bindings pour un domaine"
USAGE="(-d|--domain) nom_domaine [options]"
OPTIONS=""

PARAMS=`getopt -o d:,h,v -l domain:,help,version -- "$@" `
[ $? != 0 ] && exit 1
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
[ -z "$opt_domain" ] && echo "Domain name is missing" && exit 1


#argument vs system ckeckings :
[ -n "`$DAEMON_DATABASE_SERVER status|grep 'MySQL is stopped'`" ] && echo "WARNING : trying start MySQL" && $DAEMON_DATABASE_SERVER start
[ -n "`$DAEMON_DATABASE_SERVER status|grep 'MySQL is stopped'`" ] && echo "ERROR : can't start MySQL" && exit 1
[ -z "`query "select name from domains where name='$opt_domain_val';"`" ] && echo "ERROR : Domain $opt_domail_val is unknown" && exit 1

#montages .. pas grand chose pour le moment ..
#1) monter le domaine
[ -z "`mount|grep clients-$opt_domain_val`" ] && mount /dev$DOMAIN_POOL_ROOT/$opt_domain_val $DOMAIN_POOL_ROOT/$opt_domain_val
#2) y'a t'il un pool de mail ? Si oui, on monte sa racine
[ -n "`query "select domain from mail_domains where domain='$opt_domain_val';"`" ] && [ -z "`mount|grep "$MAIL_SYSTEM_POOL/$opt_base_val"`" ] && mount --bind `query "select mailroot from mail_domains where domain='$opt_domain_val';"` $MAIL_SYSTEM_POOL/$opt_domain_val
#3) y'a t'il un ensemble de bases de données ? si oui, monter chacune d'elle
if [ -n "`query "select domain from database_domains where domain='$opt_domain_val';"`" ] 
then
        opt_dbroot_val=`query "select dbroot from database_domains where domain='$opt_domain_val';"` &&
        base_list=`query "select name from database_bases where domain='$opt_domain_val';"` &&
        $DAEMON_DATABASE_SERVER stop
        for opt_base_val in $base_list
        do     
                [ -z "`mount|grep "$DB_SYSTEM_POOL/$opt_base_val"`" ] && mount --bind $opt_dbroot_val/$opt_base_val/ $DB_SYSTEM_POOL/$opt_base_val/
        done        
        #restart mysql ..
        $DAEMON_DATABASE_SERVER start
fi

exit 0

#otherwise, something went wrong.
echo "ERROR : something unexpected appened" && exit 1

