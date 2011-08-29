#!/bin/bash

#inclusions des procédures communes et de la configuration.
source glabmin.conf
source common.sh

#petite aide du script. Les options -h et -v sont systèmatiques ...
DESCRIPTION="créer une redirection http(s) vers un domaine ou un sous-domaine https"
USAGE="(-r|--redirection) link_name (-d|--domain) target_domain [options]"
OPTIONS="(-s|--subdomain) target_subdomain // lien vers un sous domaine https
 (-e|--encrypted) value // si 1 : lien https ; si 0 : lien http (par défaut : $REDIRECT_DEFAULT_ENCRYPTED)
"

PARAMS=`getopt -o r:,d:,s:,e:,h,v -l redirection:,domain:,subdomain:,encrypted:,help,version -- "$@" `
[ $? != 0 ] && exit 1
eval set -- "$PARAMS"

while true ; do
	case "$1" in
	-d|--domain) opt_domain="1" ; shift 1
		[ -n "$1" ] && opt_domain_val=$1 && shift 1 ;;
	-r|--redirection) opt_redirect="1" ;shift 1
		[ -n "$1" ] && opt_redirect_val=$1 && shift 1 ;;
	-e|--encrypted) opt_encrypted="1"	; shift 1
		[ -n "$1" ] && opt_encrypted_val=$1 && shift 1 ;;
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
#if no redirection or target domain, exit
[ -z "$opt_domain" ] && error "Target https domain is missing"
[ -z "$opt_redirect" ] && error "Redirection link name is missing"

#argument vs system ckeckings :
[ -z "$opt_subdomain" ] && [ -z "`query "select domain from https_domains where domain='$opt_domain_val';"`" ] && error "Service https for domain $opt_domain_val disabled"
[ -n "$opt_subdomain" ] && [ -z "`query "select domain from https_subdomains where domain='$opt_domain_val' and subdomain='$opt_subdomain_val';"`" ] && error "Service https for subdomain $opt_subdomain_val of $opt_domain_val disabled"
#if no encrypted, using default value
[ -z "$opt_encrypted" ] && opt_encrypted_val=$REDIRECT_DEFAULT_ENCRYPTED 

#registering new redirection
[ -z "$opt_subdomain" ] && query "insert into https_domains_redirect(link,is_https,target) values ('$opt_redirect_val','$opt_encrypted_val','$opt_domain_val');" || error "Client integrity at risk; aborting"
[ -n "$opt_subdomain" ] && query "insert into https_subdomains_redirect(link,is_https,target,domain) values ('$opt_redirect_val','$opt_encrypted_val','$opt_subdomain_val','$opt_domain_val');" || error "Client integrity at risk; aborting"

$DAEMON_HTTP_SERVER reload>/dev/null && exit 0

#otherwise, something went wrong.
error "something unexpected appened"
#peut etre effacer içi l'enregistrement en bdd ??
