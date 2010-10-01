#!/bin/bash

#inclusions des procédures communes et de la configuration.
source glabmin.conf
source common.sh

#petite aide du script. Les options -h et -v sont systèmatiques ...
DESCRIPTION="ajouter un pool mail à un domaine"
USAGE="(-d|--domain) nom_du_domaine [options]"
OPTIONS="(-p|--password) mot_de_passe_admin // (par defaut : mot de passe de l'administrateur du domaine)
 (-e|--email) pool_admin_email // email de l'administrateur du service (defaut : email du client de nom_du_domaine)
 (-r|--root) racine_pool // racine de l'arborescence mail dans $DOMAIN_POOL_ROOT/nom_de_domaine (defaut : $MAIL_DEFAULT_ROOT)"


PARAMS=`getopt -o d:,p:,e:,r:,h,v -l domain:,password:,email:,root:,help,version -- "$@"`
[ $? != 0 ] && exit 1
eval set -- "$PARAMS"


while true ; do
	case "$1" in
	-d|--domain) opt_domain="1"	; shift 1
		[ -n "$1" ] && opt_domain_val=$1 && shift 1 ;;
	-e|--email) opt_email="1"	; shift 1
		[ -n "$1" ] && opt_email_val=$1 && shift 1 ;;
	-p|--password) opt_password="1"	; shift 1
		[ -n "$1" ] && opt_password_val=$1 && shift 1 ;;
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
[ -z "$opt_root" ] && opt_root_val=$MAIL_DEFAULT_ROOT
[ -z `echo $opt_root_val|egrep '^[a-zA-Z0-9]+([._-]?[a-zA-Z0-9]+)*$'` ] && error "Invalid mail root name $opt_root_val"
[ -z "$opt_email" ] && opt_email_val=`query "select email from clients where name=(select client from domains where name='$opt_domain_val');"`
[ -z `echo $opt_email_val|egrep '\w+([._-]\w)*@\w+([._-]\w)*\.\w{2,4}'` ] && error "pool admin email $opt_email_val is invalid"
[ -z "$opt_password" ] && opt_password_val=`query "select password from domains where name='$opt_domain_val';"`
[ -n "`query "select domain from mail_domains where domain='$opt_domain_val';"`" ] && error "Service mail for domain $opt_domain_val already present"
[ -e "$DOMAIN_POOL_ROOT/$opt_domain_val/$opt_root_val" ] && error "A file or directory \"$opt_root_val\" exists in domain $opt_domain_val"

#registering new http service
query "insert into mail_domains (domain,pooladmin,mailroot,password) values ('$opt_domain_val','$opt_email_val','$DOMAIN_POOL_ROOT/$opt_domain_val/$opt_root_val','$opt_password_val');" error "Client integrity at risk; aborting"

#verif
opt_domain_val=`query "select domain from mail_domains where domain='$opt_domain_val'"`
opt_root_val=`query "select mailroot from mail_domains where domain='$opt_domain_val'"`
opt_email_val=`query "select pooladmin from mail_domains where domain='$opt_domain_val'"`

#upgrading system level
mkdir $opt_root_val &&
mkdir -p $MAIL_SYSTEM_POOL/$opt_domain_val &&
chown -R $MAIL_DEFAULT_USER:$MAIL_DEFAULT_GROUP $opt_root_val &&
chown -R $MAIL_DEFAULT_USER:$MAIL_DEFAULT_GROUP $MAIL_SYSTEM_POOL/$opt_domain_val &&
chmod 755 -R $opt_root_val &&
touch $opt_root_val/.lock &&
chmod 000 $opt_root_val/.lock &&
chown root:root $opt_root_val/.lock &&
chattr +i $opt_root_val/.lock &&
mount --bind $opt_root_val/ $MAIL_SYSTEM_POOL/$opt_domain_val && exit 0

#otherwise, something went wrong.
error "something unexpected appened"
#peut etre effacer içi l'enregistrement en bdd ??
