#!/bin/bash

#inclusions des procédures communes et de la configuration.
source glabmin.conf
source common.sh

#petite aide du script. Les options -h et -v sont systèmatiques ...
DESCRIPTION="supprimer les statistiques d'un service http"
USAGE="(-d|--domain) nom_du_domaine [options]"
OPTIONS="
 (-g|--engine) engine_name // moteur de rendu statistique (defaut : $STAT_DEFAULT_ENGINE)
 "


PARAMS=`getopt -o d:,g:,r:,h,v -l domain:,engine:,root:,help,version -- "$@"`
[ $? != 0 ] && exit 1
eval set -- "$PARAMS"


while true ; do
	case "$1" in
	-d|--domain) opt_domain="1"	; shift 1
		[ -n "$1" ] && opt_domain_val=$1 && shift 1 ;;
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
[ -z "$opt_domain" ] && error "Domain name is missing"


#argument vs system ckeckings :
[ -z "`query "select name from domains where name='$opt_domain_val';"`" ] && error "Domain $opt_domain_val is unknown"
[ -n "`query "select name from domains where name='$opt_domain_val' and mounted=0"`" ] && error "Domain $opt_domain_val is unmounted" 
[ -z "$opt_engine" ] && opt_engine_val=$STAT_DEFAULT_ENGINE
[ -z "`query "select domain from http_domains where domain='$opt_domain_val';"`" ] && error "Service HTTP for domain $opt_domain_val is disabled"
[ -z "`query "select name from stat_engines where name='$opt_engine_val';"`" ] && error "Stat engine $opt_engine_val is unknown"
[ -z "`query "select domain from http_domains_stats where domain='$opt_domain_val' and  engine='$opt_engine_val';"`" ] && error "Service Stats with engine $opt_engine_val for domain $opt_domain_val is not enabled"


#verifications :
opt_domain_val=`query "select domain from http_domains_stats where domain='$opt_domain_val' and engine='$opt_engine_val';"`
opt_engine_val=`query "select engine from http_domains_stats where domain='$opt_domain_val' and engine='$opt_engine_val';"`
opt_root_val=`query "select documentroot from http_domains_stats where domain='$opt_domain_val' and engine='$opt_engine_val';"`

#deleting http stats service
query "delete from http_domains_stats where engine='$opt_engine_val' and domain='$opt_domain_val';" || error "Client integrity at risk; aborting"

#upgrading system level
$DAEMON_HTTP_SERVER reload>/dev/null
case "$opt_engine_val" in
webalizer )
	rm /etc/webalizer/$opt_domain_val.http.conf
	;;
* )	;;
esac
chattr -i $opt_root_val/.lock &&
rm -fr $opt_root_val && exit 0

#otherwise, something went wrong.
error "something unexpected appened"
#peut etre effacer içi l'enregistrement en bdd ??

