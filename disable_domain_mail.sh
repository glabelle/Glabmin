#!/bin/bash

#inclusions des procédures communes et de la configuration.
source glabmin.conf
source common.sh

#petite aide du script. Les options -h et -v sont systèmatiques ...
DESCRIPTION="supprimer un pool mail à un domaine"
USAGE="(-d|--domain) nom_du_domaine [options]"
OPTIONS=""


PARAMS=`getopt -o d:,e:,r:,h,v -l domain:,email:,root:,help,version -- "$@"`
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
[ -z "$opt_domain" ] && echo "ERROR : Domain name is missing" && exit 1


#argument vs system ckeckings :
[ -z "`query "select name from domains where name='$opt_domain_val';"`" ] && echo "ERROR : Domain $opt_domain_val is unknown" && exit 1
[ -z "`query "select domain from mail_domains where domain='$opt_domain_val';"`" ] && echo "ERROR : Service mail for domain $opt_domain_val already disabled" && exit 1

#registering new http service
#verif
opt_domain_val=`query "select domain from mail_domains where domain='$opt_domain_val';"`
opt_root_val=`query "select mailroot from mail_domains where domain='$opt_domain_val';"`
opt_email_val=`query "select pooladmin from mail_domains where domain='$opt_domain_val';"`

#deleting entry in glabelle db
query "delete from mail_domains where domain='$opt_domain_val';"  || exit 1

#upgrading system level
[ -n "`lsof $opt_root_val`" ] && echo "ERROR : mail pool $opt_root_val cannot be unmounted" && echo "processes : `lsof -t $opt_root_val`" && exit 1
umount $opt_root_val/ &&
chattr -i $opt_root_val/.lock &&
rm -fr $opt_root_val &&
rm -fr $MAIL_SYSTEM_POOL/$opt_domain_val && exit 0

#otherwise, something went wrong.
echo "ERROR : something unexpected appened" && exit 1
#peut etre effacer içi l'enregistrement en bdd ??

