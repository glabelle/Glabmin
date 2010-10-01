#!/bin/bash

#inclusions des procédures communes et de la configuration.
source $(dirname $0)/glabmin.conf
source $SCRIPTSDIR/common.sh

#petite aide du script. Les options -h et -v sont systèmatiques ...
DESCRIPTION="dé-suspendre un sous-domaine"
USAGE="(-d|--domain) nom_domaine (-s|--subdomain) [options]"
OPTIONS=""


PARAMS=`getopt -o d:,s:,h,v -l domain:,subdomain:,help,version -- "$@" `
[ $? != 0 ]
eval set -- "$PARAMS"

while true ; do
	case "$1" in
	-d|--domain) opt_domain="1"	; shift 1
		[ -n "$1" ] && opt_domain_val=$1 && shift 1 ;;	
	-s|--subdomain) opt_subdomain="1"	; shift 1
		[ -n "$1" ] && opt_subdomain_val=$1 && shift 1 ;;
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
#if no domain or no subdomain, then display help and exit
[ -z "$opt_domain" ] && error "Domain name is missing"
[ -z "$opt_subdomain" ] && error "Subomain name is missing"
[ -z "`query "select name from domains where name='$opt_domain_val';"`" ] && error "Domain $opt_domain_val is unknown"
[ -n "`query "select name from domains where name='$opt_domain_val' and mounted=0"`" ] && warning "Domain $opt_domain_val is unmounted"
[ -z "`query "select name from subdomains where name='$opt_subdomain_val' and domain='$opt_domain_val';"`" ] && error "Subomain $opt_domain_val is unknown for domain $opt_domain_val"
[ -n "`query "select name from subdomains where suspended=0 and name='$opt_subdomain_val' and domain='$opt_domain_val';"`" ] && error "Subomain $opt_subdomain_val of domain $opt_domain_val is not suspended"

#on désactive le sous-domaine :
#1) eteindre apache si nécessaire
APACHE_STATUS="`$DAEMON_HTTP_SERVER status`"
( [ -n "`query "select domain from http_subdomains where domain='$opt_domain_val' and subdomain='$opt_subdomain_val';"`" ] || [ -n "`query "select domain from https_subdomains where domain='$opt_domain_val' and subdomain='$opt_subdomain_val';"`" ] ) && [ -n "$APACHE_STATUS" ] && $DAEMON_HTTP_SERVER stop >/dev/null
#3) marquer le compte comme retabli
query "update subdomains set suspended=0 where name='$opt_subdomain_val' and domain='$opt_domain_val';" || error "Cannot write suspended statut in database for subdomain $opt_subdomain_val of domain $opt_domain_val"
#2) rétablir l'utilsateur unix associé au sous-domaine
usermod -U "$opt_subdomain_val.$opt_domain_val" || error "Cannot suspend unix user $opt_subdomain_val.$opt_domain_val"
#3) allumer apache si nécessaire
[ -n "$APACHE_STATUS" ] && [ -z "`$DAEMON_HTTP_SERVER status`" ] && $DAEMON_HTTP_SERVER start >/dev/null


