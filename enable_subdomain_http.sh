#!/bin/bash

#inclusions des procédures communes et de la configuration.
source glabmin.conf
source common.sh

#petite aide du script. Les options -h et -v sont systèmatiques ...
DESCRIPTION="ajouter un service http"
USAGE="(-d|--domain) nom_du_domaine (-s|--subdomain) nom_du_sous_domaine [options]"
OPTIONS="(-u|--user) apache_utilisateur // utilisateur apache (defaut : nom_du_sous_domaine)
 (-c|--charset) caractere_set // encodage des pages (defaut : $HTTP_DEFAULT_CHARSET. Les autres valeurs possibles sont définies dans la table glabelle.charsets)
 (-g|--group) apache_groupe // groupe apache (defaut : nom_du_domaine)
 (-e|--email) admin_email // email de l'administrateur (defaut : email du client de nom_du_domaine)
 (-r|--root) racine_web // racine de l'arborescence http dans $DOMAIN_POOL_ROOT/nom_de_domaine/nom_de_sous_domaine (defaut : $HTTP_DEFAULT_ROOT)
 (-l|--logs) logs_dir // repertoire des logs http dans $DOMAIN_POOL_ROOT/nom_de_domaine/nom_de_sous_domaine (defaut : $HTTP_DEFAULT_LOGDIR)
"


PARAMS=`getopt -o l:,d:,s:,u:,c:,g:,e:,r:,h,v -l logs:,domain:,subdomain:,user:,charset:,group:,email:,root:,help,version -- "$@"`
[ $? != 0 ] && exit 1
eval set -- "$PARAMS"


while true ; do
	case "$1" in
	-d|--domain) opt_domain="1"	; shift 1
		[ -n "$1" ] && opt_domain_val=$1 && shift 1 ;;
        -s|--subdomain) opt_subdomain="1"	; shift 1
		[ -n "$1" ] && opt_subdomain_val=$1 && shift 1 ;;
        -u|--user) opt_user="1"	; shift 1
		[ -n "$1" ] && opt_user_val=$1 && shift 1 ;;
	-g|--group) opt_group="1"	; shift 1
		[ -n "$1" ] && opt_group_val=$1 && shift 1 ;;
	-c|--charset) opt_charset="1"	; shift 1
		[ -n "$1" ] && opt_charset_val=$1 && shift 1 ;;
	-e|--email) opt_email="1"	; shift 1
		[ -n "$1" ] && opt_email_val=$1 && shift 1 ;;
	-r|--root) opt_root="1"	; shift 1
		[ -n "$1" ] && opt_root_val=$1 && shift 1 ;;
	-l|--logs) opt_logs="1"	; shift 1
		[ -n "$1" ] && opt_logs_val=$1 && shift 1 ;;
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
[ -z "$opt_charset" ] && opt_charset_val=$HTTP_DEFAULT_CHARSET
[ -z "`query "select name from charsets where name='$opt_charset_val';"`" ] && echo "ERROR : Charset $opt_charset_val is unknown" && exit 1
[ -z "$opt_user" ] && opt_user_val="$opt_subdomain_val.$opt_domain_val"
[ -z "$opt_group" ] && opt_group_val=$opt_domain_val
[ -z "$opt_root" ] && opt_root_val=$HTTP_DEFAULT_ROOT
[ -z "$opt_logs" ] && opt_logs_val=$HTTP_DEFAULT_LOGDIR
[ -z `echo $opt_root_val|egrep '^[a-zA-Z0-9]+([._-]?[a-zA-Z0-9]+)*$'` ] && echo "ERROR : Invalid http root name $opt_root_val" && exit 1
[ -z `echo $opt_logs_val|egrep '^[a-zA-Z0-9]+([_-]?[a-zA-Z0-9]+)*$'` ] && echo "ERROR : Invalid logs directory name $opt_logs_val" && exit 1
[ -z "$opt_email" ] && opt_email_val=`query "select email from clients where name=(select client from domains where name='$opt_domain_val');"`
[ -z `echo $opt_email_val|egrep '\w+([._-]\w)*@\w+([._-]\w)*\.\w{2,4}'` ] && echo "ERROR : admin email $opt_email_val is invalid" && exit 1
[ -n "`query "select domain from http_subdomains where domain='$opt_domain_val' and subdomain='$opt_subdomain_val';"`" ] && echo "ERROR : Service http for subdomain $opt_subdomain_val of $opt_domain_val already present" && exit 1
[ -e "$DOMAIN_POOL_ROOT/$opt_domain_val/$opt_subdomain_val/$opt_root_val" ] && echo "ERROR : A file or directory \"$opt_root_val\" exists in subdomain $opt_subdomain_val of $opt_domain_val" && exit 1
[ -e "$DOMAIN_POOL_ROOT/$opt_domain_val/$opt_subdomain_val/$opt_logs_val" ] && echo "ERROR : A file or directory \"$opt_logs_val\" exists in subdomain $opt_subdomain_val of $opt_domain_val" && exit 1

#registering new http service
query "insert into http_subdomains (subdomain,domain,serveruser,servergroup,serveradmin,documentroot,charset,logfiledir) values ('$opt_subdomain_val','$opt_domain_val','$opt_user_val','$opt_group_val','$opt_email_val','$DOMAIN_POOL_ROOT/$opt_domain_val/$opt_subdomain_val/$opt_root_val','$opt_charset_val','$DOMAIN_POOL_ROOT/$opt_domain_val/$opt_subdomain_val/$opt_logs_val');"

#verif
opt_domain_val=`query "select domain from http_subdomains where domain='$opt_domain_val' and subdomain='$opt_subdomain_val'"`
opt_subdomain_val=`query "select subdomain from http_subdomains where domain='$opt_domain_val' and subdomain='$opt_subdomain_val'"`
opt_root_val=`query "select documentroot from http_subdomains where domain='$opt_domain_val'and subdomain='$opt_subdomain_val'"`
opt_email_val=`query "select serveradmin from http_subdomains where domain='$opt_domain_val'and subdomain='$opt_subdomain_val'"`
opt_logs_val=`query "select logfiledir from http_subdomains where domain='$opt_domain_val'and subdomain='$opt_subdomain_val'"`

#upgrading system level
#create rootdir
mkdir $opt_root_val &&
sed "s/\[HOST\]/$opt_domain_val/g" $SCRIPTSDIR/template_files/http_index.tmpl > tmp1 &&
sed "s/\[SERVERADMIN\]/$opt_email_val/g" tmp1 > tmp2 &&
sed "s/\[NAME\]/$opt_subdomain_val.$opt_domain_val/g" tmp2 > $opt_root_val/index.html &&
rm tmp1 tmp2 &&
chown -R $opt_subdomain_val.$opt_domain_val:$opt_domain_val $opt_root_val &&
chmod 755 -R $opt_root_val &&
touch $opt_root_val/.lock &&
chmod 000 $opt_root_val/.lock &&
chown root:root $opt_root_val/.lock &&
chattr +i $opt_root_val/.lock &&

#create logsdir
mkdir $opt_logs_val &&
chown -R $opt_subdomain_val.$opt_domain_val:$opt_domain_val $opt_logs_val &&
chmod 755 -R $opt_logs_val &&
touch $opt_logs_val/.lock &&
chmod 000 $opt_logs_val/.lock &&
chown -R $opt_subdomain_val.$opt_domain_val:$opt_domain_val $opt_logs_val &&
chown root:root $opt_logs_val/.lock &&
chattr +i $opt_logs_val/.lock &&

$DAMEON_HTTP_SERVER reload>/dev/null && exit 0

#otherwise, something went wrong.
echo "ERROR : something unexpected appened" && exit 1
#peut etre effacer içi l'enregistrement en bdd ??















