#!/bin/bash

#inclusions des procédures communes et de la configuration.
source glabmin.conf
source common.sh

#petite aide du script. Les options -h et -v sont systèmatiques ...
DESCRIPTION="supprimer les statistiques d'un service https pour un sous-domaine"
USAGE="(-d|--domain) nom_du_domaine (-s|--subdomain) nom_du_sous_domaine [options]"
OPTIONS="
 (-g|--engine) engine_name // moteur de rendu statistique (defaut : $STAT_DEFAULT_ENGINE)
 "


PARAMS=`getopt -o d:,s:,g:,r:,h,v -l domain:,subdomain:,engine:,root:,help,version -- "$@"`
[ $? != 0 ] && exit 1
eval set -- "$PARAMS"


while true ; do
	case "$1" in
	-d|--domain) opt_domain="1"	; shift 1
		[ -n "$1" ] && opt_domain_val=$1 && shift 1 ;;
	-s|--subdomain) opt_subdomain="1"	; shift 1
		[ -n "$1" ] && opt_subdomain_val=$1 && shift 1 ;;
	-g|--engine) opt_engine="1"	; shift 1
		[ -n "$1" ] && opt_engine_val=$1 && shift 1 ;;
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
[ -z "$opt_subdomain" ] && echo "ERROR : Subdomain name is missing" && exit 1

#argument vs system ckeckings :
[ -z "`query "select name from domains where name='$opt_domain_val';"`" ] && echo "ERROR : Domain $opt_domail_val is unknown" && exit 1
[ -z "`query "select name from subdomains where name='$opt_subdomain_val' and domain='$opt_domain_val';"`" ] && echo "ERROR : Subdomain $opt_subdomain_val is unknown for domain $opt_domain_val" && exit 1
[ -z "`query "select domain from https_subdomains where domain='$opt_domain_val' and subdomain='$opt_subdomain_val';"`" ] && echo "ERROR : Service https for subdomain $opt_subdomain_val of $opt_domain_val is disabled" && exit 1
[ -z "$opt_engine" ] && opt_engine_val=$STAT_DEFAULT_ENGINE
[ -z "`query "select name from stat_engines where name='$opt_engine_val';"`" ] && echo "ERROR : Stat engine $opt_engine_val is unknown" && exit 1
[ -z "`query "select domain from https_subdomains_stats where domain='$opt_domain_val' and subdomain='$opt_subdomain_val' and  engine='$opt_engine_val';"`" ] && echo "ERROR : Service Stats with engine $opt_engine_val for  subdomain $opt_subdomain_val of domain $opt_domain_val is not enabled" && exit 1


#verifications :
opt_domain_val=`query "select domain from https_subdomains_stats where domain='$opt_domain_val' and subdomain='$opt_subdomain_val' and engine='$opt_engine_val';"`
opt_subdomain_val=`query "select subdomain from https_subdomains_stats where domain='$opt_domain_val' and subdomain='$opt_subdomain_val' and engine='$opt_engine_val';"`
opt_engine_val=`query "select engine from https_subdomains_stats where domain='$opt_domain_val' and subdomain='$opt_subdomain_val' and engine='$opt_engine_val';"`
opt_root_val=`query "select documentroot from https_subdomains_stats where domain='$opt_domain_val' and subdomain='$opt_subdomain_val' and engine='$opt_engine_val';"`

#deleting https stats service
query "delete from https_subdomains_stats where engine='$opt_engine_val' and domain='$opt_domain_val' and subdomain='$opt_subdomain_val';" || exit 1

#upgrading system level
$DAMEON_HTTP_SERVER reload>/dev/null
case "$opt_engine_val" in
webalizer )
	rm /etc/webalizer/$opt_subdomain_val.$opt_domain_val.https.conf
	;;
* )	;;
esac
chattr -i $opt_root_val/.lock &&
rm -fr $opt_root_val && exit 0

#otherwise, something went wrong.
echo "ERROR : something unexpected appened" && exit 1
#peut etre effacer içi l'enregistrement en bdd ??

