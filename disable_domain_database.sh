#!/bin/bash

#inclusions des procédures communes et de la configuration.
source glabmin.conf
source common.sh

#petite aide du script. Les options -h et -v sont systèmatiques ...
DESCRIPTION="supprimer un service de bases de données mysql"
USAGE="(-d|--domain) nom_du_domaine [options]"
OPTIONS=""

PARAMS=`getopt -o d:,h,v -l domain:,help,version -- "$@"`
[ $? != 0 ] && exit 1
eval set -- "$PARAMS"


while true ; do
	case "$1" in
	-d|--domain) opt_domain="1"	; shift 1
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
#if no client or no email, then exit
[ -z "$opt_domain" ] && error "Domain name is missing"


#argument vs system ckeckings :
[ -z "`query "select name from domains where name='$opt_domain_val';"`" ] && error "Domain $opt_domain_val is unknown"
[ -n "`query "select name from domains where name='$opt_domain_val' and mounted=0"`" ] && error "Domain $opt_domain_val is unmounted"
[ -n "`query "select name from domains where name='$opt_domain_val' and suspended=1"`" ] && error "Domain $opt_domain_val is suspended" 
[ -z "`query "select domain from database_domains where domain='$opt_domain_val';"`" ] && error "Service database for domain $opt_domain_val already disabled"


#verif
opt_domain_val=`query "select domain from database_domains where domain='$opt_domain_val'"`
opt_dbroot_val=`query "select dbroot from database_domains where domain='$opt_domain_val'"`


#fetching info from database :
query "delete from database_domains where domain='$opt_domain_val'" || error "Client integrity at risk; aborting" #-> sortie sur erreur s'il reste des bases ..

#upgrading system level
removelock $opt_dbroot_val && 
rm -fr $opt_dbroot_val && exit 0 

#otherwise, something went wrong.
error "something unexpected appened"
#peut etre effacer içi l'enregistrement en bdd ??

