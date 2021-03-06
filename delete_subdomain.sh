#!/bin/bash

#inclusions des procédures communes et de la configuration.
source glabmin.conf
source common.sh

#petite aide du script. Les options -h et -v sont systèmatiques ...
DESCRIPTION="supprimer un sous-domaine"
USAGE="(-d|--domain) domain_name (-s|--subdomain) subdomain_name "
OPTIONS=""


PARAMS=`getopt -o d:,s:,h,v -l domain:,subdomain:,help,version -- "$@" `
[ $? != 0 ] && exit 1
eval set -- "$PARAMS"

while true ; do
	case "$1" in
	-d|--domain) opt_domain="1" ; shift 1
		[ -n "$1" ] && opt_domain_val=$1 && shift 1 ;;
	-s|--subdomain) opt_subdomain="1" ;shift 1
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
#if no domain, then exit
[ -z "$opt_domain" ] && error "Domain name is missing"
[ -z "$opt_subdomain" ] && error "subdomain name is missing"

#argument vs system ckeckings :
[ -z "`query "select name from subdomains where name='$opt_subdomain_val' and domain='$opt_domain_val';"`" ] && error "Subdomain $opt_subdomain_val is unknown for domain $opt_domain_val"

#validation :
opt_subdomain_val=`query "select name from subdomains where name='$opt_subdomain_val' and domain='$opt_domain_val';"`
opt_domain_val=`query "select domain from subdomains where name='$opt_subdomain_val' and domain='$opt_domain_val';"`

# Mathieu : On ne passe pas a la suite tant que la base n'a pas été correctement vidée.
# Autrement dit, il faut que tous les enregistrements avec des clés étrangère subdomaine aient été virées.
query "delete from subdomains where name='$opt_subdomain_val' and domain='$opt_domain_val';" || error "Client integrity at risk; aborting" #provoque une erreur si ce n'est pas possible

#creating appropriate system side
removelock $DOMAIN_POOL_ROOT/$opt_domain_val/$opt_subdomain_val &&
userdel -r "$opt_subdomain_val.$opt_domain_val" && exit 0

#otherwise, something went wrong.
error "something unexpected appened"
