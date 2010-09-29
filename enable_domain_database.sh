#!/bin/bash

#inclusions des procédures communes et de la configuration.
source glabmin.conf
source common.sh

#petite aide du script. Les options -h et -v sont systèmatiques ...
DESCRIPTION="ajouter un service de bases de données mysql"
USAGE="(-d|--domain) nom_du_domaine [options]"
OPTIONS="(-u|--nbuser) nb_utilisateurs // nombre maximum d'utilisateurs mysql pour nom_du_domaine (defaut : $DB_DEFAULT_MAX_USER)
 (-b|--nbbase) nb_dbs // nombre maximum de bases de données pour nom_du_domaine (defaut : $DB_DEFAULT_MAX_DB)
 (-e|--email) admin_email // email de l'administrateur (defaut : email du client de nom_du_domaine)
 (-r|--dbroot) racine_bdd // racine de l'arborescence des bases de données dans $DOMAIN_POOL_ROOT/nom_de_domaine (defaut : $DB_DEFAULT_ROOT)"


PARAMS=`getopt -o d:,u:,b:,e:,r:,h,v -l domain:,nbuser:,nbbase:,email:,dbroot:,help,version -- "$@"`
[ $? != 0 ] && exit 1
eval set -- "$PARAMS"


while true ; do
	case "$1" in
	-d|--domain) opt_domain="1"	; shift 1
		[ -n "$1" ] && opt_domain_val=$1 && shift 1 ;;
        -u|--nbuser) opt_nbuser="1"	; shift 1
		[ -n "$1" ] && opt_nbuser_val=$1 && shift 1 ;;
	-b|--nbbase) opt_nbbase="1"	; shift 1
		[ -n "$1" ] && opt_nbbase_val=$1 && shift 1 ;;
	-e|--email) opt_email="1"	; shift 1
		[ -n "$1" ] && opt_email_val=$1 && shift 1 ;;
	-r|--dbroot) opt_dbroot="1"	; shift 1
		[ -n "$1" ] && opt_dbroot_val=$1 && shift 1 ;;
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
[ -z "$opt_nbuser" ] && opt_nbuser_val=$DB_DEFAULT_MAX_USER
[ -z "$opt_nbbase" ] && opt_nbbase_val=$DB_DEFAULT_MAX_DB
[ -z "$opt_dbroot" ] && opt_dbroot_val=$DB_DEFAULT_ROOT
[ -z "$opt_email" ] && opt_email_val=`query "select email from clients where name=(select client from domains where name='$opt_domain_val');"`

[ -z `echo $opt_nbuser_val|egrep '^[1-9]+[[:digit:]]*$'` ] && echo "ERROR : Invalid maximum user number $opt_nbuser_val" && exit 1
[ -z `echo $opt_nbbase_val|egrep '^[1-9]+[[:digit:]]*$'` ] && echo "ERROR : Invalid maximum base number $opt_nbbase_val" && exit 1
[ -z `echo $opt_dbroot_val|egrep '^[a-zA-Z0-9]+([._-]?[a-zA-Z0-9]+)*$'` ] && echo "ERROR : Invalid $DB_DEFAULT_ROOT root name $opt_dbroot_val" && exit 1
[ -z `echo $opt_email_val|egrep '\w+([._-]\w)*@\w+([._-]\w)*\.\w{2,4}'` ] && echo "ERROR : admin email $opt_email_val is invalid" && exit 1

[ -n "`query "select domain from database_domains where domain='$opt_domain_val';"`" ] && echo "ERROR : Service database for domain $opt_domain_val already present" && exit 1
[ -e "$DOMAIN_POOL_ROOT/$opt_domain_val/$opt_dbroot_val" ] && echo "ERROR : A file or directory \"$opt_dbroot_val\" exists in domain $opt_domain_val" && exit 1

#registering new http service
query "insert into database_domains (domain,nbuser,nbbase,mailadmin,dbroot) values ('$opt_domain_val','$opt_nbuser_val','$opt_nbbase_val','$opt_email_val','$DOMAIN_POOL_ROOT/$opt_domain_val/$opt_dbroot_val');" || exit 1

#verif
opt_domain_val=`query "select domain from database_domains where domain='$opt_domain_val'"`
opt_dbroot_val=`query "select dbroot from database_domains where domain='$opt_domain_val'"`

#upgrading system level
mkdir $opt_dbroot_val &&
chown -R mysql:mysql $opt_dbroot_val &&
chmod 755 -R $opt_dbroot_val &&
touch $opt_dbroot_val/.lock &&
chmod 000 $opt_dbroot_val/.lock &&
chown root:root $opt_dbroot_val/.lock &&
chattr +i $opt_dbroot_val/.lock && exit 0

#otherwise, something went wrong.
echo "ERROR : something unexpected appened" && exit 1
#peut etre effacer içi l'enregistrement en bdd ??

