#!/bin/bash

#inclusions des procédures communes et de la configuration.
source glabmin.conf
source common.sh

#petite aide du script. Les options -h et -v sont systèmatiques ...
DESCRIPTION="ajouter un sous-domaine"
USAGE="(-d|--domain) domain_name (-s|subdomain) subdomain_name [options]"
OPTIONS="(-p|--password) mot_de_passe //par defaut subdomain.pass=domain.pass"

PARAMS=`getopt -o d:,s:,p:,h,v -l domain:,subdomain:,password:,help,version -- "$@" `
[ $? != 0 ] && exit 1
eval set -- "$PARAMS"

while true ; do
	case "$1" in
	-d|--domain) opt_domain="1" ; shift 1
		[ -n "$1" ] && opt_domain_val=$1 && shift 1 ;;
	-s|--subdomain) opt_subdomain="1" ;shift 1
		[ -n "$1" ] && opt_subdomain_val=$1 && shift 1 ;;
	-p|--password) opt_password="1"	; shift 1
		[ -n "$1" ] && opt_password_val=$1 && shift 1 ;;
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
#if no domain, client or password, then exit
[ -z "$opt_subdomain" ] && echo "ERROR : Subdomain name is missing" && exit 1
[ -z "$opt_domain" ] && echo "ERROR : Domain name is missing" && exit 1


#argument vs system ckeckings :
[ -z "`query "select name from domains where name='$opt_domain_val';"`" ] && echo "ERROR : Domain $opt_domain_val is unknown" && exit 1
[ -z `echo $opt_subdomain_val|egrep '^[a-zA-Z0-9]+([_-]?[a-zA-Z0-9]+)*$'` ] && echo "ERROR : Invalid subdomain name $opt_domain_val" && exit 1
[ -n "`query "select name from restricted_names where name='$opt_subdomain_val';"`" ] && echo "ERROR : Subdomain name $opt_subdomain_val is restricted" && exit 1
[ -n "`query "select name from subdomains where name='$opt_subdomain_val' and domain='$opt_domain_val';"`" ] && echo "ERROR : Subdomain $opt_subdomain_val already registered" && exit 1
[ -e "$DOMAIN_POOL_ROOT/$opt_domain_val/$opt_subdomain_val" ] && echo "ERROR : A file or directory $opt_subdomain_val exists in domain $opt_domain_val" && exit 1
[ -z "$opt_password" ] && opt_password_val=`query "select password from domains where name='$opt_domain_val';"`


query "insert into subdomains (name,domain,password) values ('$opt_subdomain_val','$opt_domain_val','$opt_password_val');"
#validation :
opt_domain_val=`query "select name from domains where name='$opt_domain_val';"`
opt_password_val=`query "select password from subdomains where name='$opt_subdomain_val' and domain='$opt_domain_val';"`
opt_subdomain_val=`query "select name from subdomains where name='$opt_subdomain_val' and domain='$opt_domain_val';"`


useradd -g $opt_domain_val -d $DOMAIN_POOL_ROOT/$opt_domain_val/$opt_subdomain_val -m -s /bin/false "$opt_subdomain_val.$opt_domain_val" &&
echo "$opt_subdomain_val.$opt_domain_val:$opt_password_val"|chpasswd &&
chown -R $opt_subdomain_val.$opt_domain_val:$opt_domain_val $DOMAIN_POOL_ROOT/$opt_domain_val/$opt_subdomain_val &&
chmod 755 $DOMAIN_POOL_ROOT/$opt_domain_val/$opt_subdomain_val &&
touch $DOMAIN_POOL_ROOT/$opt_domain_val/$opt_subdomain_val/.lock &&
chmod 000 $DOMAIN_POOL_ROOT/$opt_domain_val/$opt_subdomain_val/.lock &&
chown root:root $DOMAIN_POOL_ROOT/$opt_domain_val/$opt_subdomain_val/.lock &&
chattr +i $DOMAIN_POOL_ROOT/$opt_domain_val/$opt_subdomain_val/.lock && exit 0


#otherwise, something went wrong.
echo "ERROR : something unexpected appened" && exit 1
#peut etre effacer içi l'enregistrement en bdd ??
