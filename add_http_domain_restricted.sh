#!/bin/bash

#inclusions des procédures communes et de la configuration.
source glabmin.conf
source common.sh

#petite aide du script. Les options -h et -v sont systèmatiques ...
DESCRIPTION="ajouter un dossier ayant un acces restreint au service http d'un domaine"
USAGE="(-d|--domain) nom_du_domaine [options]"
OPTIONS="(-r|--directory) nom_du_dossier // depuis la racine_http du domaine ; p.ex 'toto' 'toto/subtoto' (par defaut racine_http du domaine) 
 "

PARAMS=`getopt -o d:,r:,h,v -l domain:,directory:,help,version -- "$@"`
[ $? != 0 ] && exit 1
eval set -- "$PARAMS"


while true ; do
	case "$1" in
	-d|--domain) opt_domain="1"	; shift 1
		[ -n "$1" ] && opt_domain_val=$1 && shift 1 ;;
    -r|--directory) opt_directory="1"	; shift 1
		[ -n "$1" ] && opt_directory_val=$1 && shift 1 ;;
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
[ -z "$opt_domain" ] && echo "ERROR : Domain name is missing" && exit 1

#argument vs system ckeckings :
[ -z "`query "select name from domains where name='$opt_domain_val';"`" ] && echo "ERROR : Domain $opt_domail_val is unknown" && exit 1
[ -z "`query "select domain from http_domains where domain='$opt_domain_val';"`" ] && echo "ERROR : Service HTTP for domain $opt_domail_val is disabled" && exit 1
[ -z "$opt_directory" ] && opt_directory_val=`query "select documentroot from http_domains where domain='$opt_domain_val';"`
[ -n "$opt_directory" ] && opt_directory_val="`query "select documentroot from http_domains where domain='$opt_domain_val';"`/$opt_directory_val"
[ -z `echo $opt_directory_val|egrep '^[/][a-zA-Z0-9]([-._/]?[a-zA-Z0-9]+)*$'` ] && echo "ERROR : Invalid directory name $opt_directory_val" && exit 1
[ "`echo ${#opt_directory_val}`" -gt "40"  ] && echo "ERROR : directory name $opt_directory_val too long" && exit 1
[ ! -d "$opt_directory_val" ] && echo "ERROR : $opt_directory_val is not a valid directory" && exit 1
[ -n "`query "select directory from http_domains_restricted where domain='$opt_domain_val' and directory='$opt_directory_val'"`" ] && echo "ERROR : directory $opt_directory_val already restricted" && exit 1

#eventuellement à garder en option
#[ "`query "select count(*) from database_directorys where domain='$opt_domain_val';"`" -ge "`query "select nbdirectory from database_domains where domain='$opt_domain_val';"`" ] && echo "ERROR : cannot add another directory for domain $opt_domain_val" && exit 1

#registering new http service
query "insert into http_domains_restricted (domain,directory) values ('$opt_domain_val','$opt_directory_val');" || exit 1

#upgrading system level
#nothing to be done ..
exit 0

#otherwise, something went wrong.
echo "ERROR : something unexpected appened" && exit 1
#peut etre effacer içi l'enregistrement en bdd ??

