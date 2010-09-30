#!/bin/bash

#inclusions des procédures communes et de la configuration.
source glabmin.conf
source common.sh

#petite aide du script. Les options -h et -v sont systèmatiques ...
DESCRIPTION="supprimer un service https"
USAGE="(-d|--domain) nom_du_domaine (-s|--subdomain) nom_du_sous_domaine [options]"
OPTIONS=""

PARAMS=`getopt -o d:,s:,h,v -l domain:,subdomain:,help,version -- "$@"`
[ $? != 0 ] && exit 1
eval set -- "$PARAMS"


while true ; do
	case "$1" in
	-d|--domain) opt_domain="1"	; shift 1
		[ -n "$1" ] && opt_domain_val=$1 && shift 1 ;;
	-s|--subdomain) opt_subdomain="1"	; shift 1
		[ -n "$1" ] && opt_subdomain_val=$1 && shift 1 ;;
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
[ -z "$opt_domain" ] && error "Domain name is missing"
[ -z "$opt_subdomain" ] && error "Subdomain name is missing"

#argument vs system ckeckings :
[ -z "`query "select name from domains where name='$opt_domain_val';"`" ] && error "Domain $opt_domail_val is unknown"
[ -z "`query "select name from subdomains where name='$opt_subdomain_val' and domain='$opt_domain_val';"`" ] && error "Subdomain $opt_subdomain_val is unknown for domain $opt_domain_val"
[ -z "`query "select domain from https_subdomains where domain='$opt_domain_val' and subdomain='$opt_subdomain_val';"`" ] && error "Service https for subdomain $opt_subdomain_val of $opt_domain_val already disabled"

#verif
opt_domain_val=`query "select domain from https_subdomains where domain='$opt_domain_val' and subdomain='$opt_subdomain_val'"`
opt_subdomain_val=`query "select subdomain from https_subdomains where domain='$opt_domain_val' and subdomain='$opt_subdomain_val'"`
opt_root_val=`query "select documentroot from https_subdomains where domain='$opt_domain_val' and subdomain='$opt_subdomain_val'"` #ATTENTION : cas de destruction de la racine serveur si "/" en param !!!!!!!!!!!!

#Deleting https service record
query "delete from https_subdomains where domain='$opt_domain_val' and subdomain='$opt_subdomain_val'"  error "Client integrity at risk; aborting"

$DAEMON_HTTP_SERVER reload>/dev/null &&
chattr -i $opt_root_val/.lock && #-> normalement on évite la pire en sortant là ....
rm -fr $opt_root_val && exit 0 #Fichue ligne !!!! Il faut vérifier ce parametre avant d'éxécuter. Je sais pas trop comment .... Si on a / en bdd au moment de 

#otherwise, something went wrong.
error "something unexpected appened"
#peut etre effacer içi l'enregistrement en bdd ??















