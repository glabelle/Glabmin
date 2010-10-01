#!/bin/bash

#inclusions des procédures communes et de la configuration.
source glabmin.conf
source common.sh

#petite aide du script. Les options -h et -v sont systèmatiques ...
DESCRIPTION="ajouter les statistiques d'un service http"
USAGE="(-d|--domain) nom_du_domaine [options]"
OPTIONS="
 (-r|--root) racine_stats // racine de l'arborescence statistiques dans $DOMAIN_POOL_ROOT/nom_de_domaine (defaut : $STAT_DEFAULT_HTTP_ROOT)
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
	-r|--root) opt_root="1"	; shift 1
		[ -n "$1" ] && opt_root_val=$1 && shift 1 ;;
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
[ -z "$opt_root" ] && opt_root_val=$STAT_DEFAULT_HTTP_ROOT
[ -z `echo $opt_root_val|egrep '^[a-zA-Z0-9]+([_-]?[a-zA-Z0-9]+)*$'` ] && error "Invalid stats directory name $opt_root_val"
[ -z "`query "select domain from http_domains where domain='$opt_domain_val';"`" ] && error "Service HTTP for domain $opt_domain_val is disabled"
[ -z "`query "select name from stat_engines where name='$opt_engine_val';"`" ] && error "Stat engine $opt_engine_val is unknown"
[ -n "`query "select domain from http_domains_stats where domain='$opt_domain_val' and  engine='$opt_engine_val';"`" ] && error "Service Stats with engine $opt_engine_val for domain $opt_domain_val is already enabled"
[ -e "$DOMAIN_POOL_ROOT/$opt_domain_val/$opt_root_val" ] && error "A file or directory \"$opt_root_val\" exists in domain $opt_domain_val"


#registering new http stats service
query "insert into http_domains_stats (domain,engine,documentroot) values ('$opt_domain_val','$opt_engine_val','$DOMAIN_POOL_ROOT/$opt_domain_val/$opt_root_val');" || error "Client integrity at risk; aborting"

#verif
opt_domain_val=`query "select domain from http_domains_stats where domain='$opt_domain_val' and engine='$opt_engine_val';"`
opt_engine_val=`query "select engine from http_domains_stats where domain='$opt_domain_val' and engine='$opt_engine_val';"`
opt_root_val=`query "select documentroot from http_domains_stats where domain='$opt_domain_val' and engine='$opt_engine_val';"`
opt_logs_val=`query "select logfiledir from http_domains where domain='$opt_domain_val';"`

#upgrading system level
#create statistics rootdir

mkdir $opt_root_val &&
chown -R $opt_domain_val:$opt_domain_val $opt_root_val &&
chmod 755 -R $opt_root_val &&
touch $opt_root_val/.lock &&
chmod 000 $opt_root_val/.lock &&
chown root:root $opt_root_val/.lock &&
chattr +i $opt_root_val/.lock &&

#engine congiguration :
case "$opt_engine_val" in
webalizer )
	sed "s|\[LOGS\]|$opt_logs_val|g" $SCRIPTSDIR/template_files/webalizer_conf.tmpl > tmp1 &&
	sed "s|\[ROOT\]|$opt_root_val|g" tmp1 > tmp2 &&
	sed "s|\[DOMAIN\]|$opt_domain_val|g" tmp2 > /etc/webalizer/$opt_domain_val.http.conf &&
	rm tmp1 tmp2 &&
	webalizer -c /etc/webalizer/$opt_domain_val.http.conf
	;;
* )	;;
esac

$DAEMON_HTTP_SERVER reload>/dev/null && exit 0

#otherwise, something went wrong.
error "something unexpected appened"
#peut etre effacer içi l'enregistrement en bdd ??

