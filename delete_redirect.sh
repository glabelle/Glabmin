#!/bin/bash

#inclusions des procédures communes et de la configuration.
source glabmin.conf
source common.sh

#petite aide du script. Les options -h et -v sont systèmatiques ...
DESCRIPTION="supprimer une redirection http(s) vers un domaine ou un sous-domaine http(s)"
USAGE="(-r|--redirection) link_name [options]"
OPTIONS="(e|--encrypted) value // si 1 : lien https ; si 0 : lien http (par défaut : $REDIRECT_DEFAULT_ENCRYPTED)
"

PARAMS=`getopt -o r:,e:,h,v -l redirection:,encrypted:,help,version -- "$@" `
[ $? != 0 ] && exit 1
eval set -- "$PARAMS"

while true ; do
	case "$1" in
	-r|--redirection) opt_redirect="1" ;shift 1
		[ -n "$1" ] && opt_redirect_val=$1 && shift 1 ;;
	-e|--encrypted) opt_encrypted="1"	; shift 1
		[ -n "$1" ] && opt_encrypted_val=$1 && shift 1 ;;
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
[ -z "$opt_redirect" ] && error "Redirection link name is missing"

#if no encrypted, using default value
[ -z "$opt_encrypted" ] && opt_encrypted_val=$REDIRECT_DEFAULT_ENCRYPTED 
#argument vs system ckeckings :
result=""
for i in 'http_domains_redirect' 'https_domains_redirect' 'http_subdomains_redirect' 'https_subdomains_redirect'
do
  result="$result`query "select * from $i where link='$opt_redirect_val' and is_https=$opt_encrypted_val"`"
done
[ -z "$result" ] && error "link '$opt_redirect_val' with https=$opt_encrypted_val does not exists"

#delete existing redirection
for i in 'http_domains_redirect' 'https_domains_redirect' 'http_subdomains_alias' 'https_subdomains_alias'
do
  query "delete from $i where link='$opt_redirect_val' and is_https=$opt_encrypted_val" || error "Client integrity at risk; aborting" 
done

$DAEMON_HTTP_SERVER reload>/dev/null && exit 0

#otherwise, something went wrong.
error "something unexpected appened"
#peut etre effacer içi l'enregistrement en bdd ??
