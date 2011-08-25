#!/bin/bash

#inclusions des procédures communes et de la configuration.
source glabmin.conf
source common.sh

#petite aide du script. Les options -h et -v sont systèmatiques ...
DESCRIPTION="ajouter un service http"
USAGE="(-d|--domain) nom_du_domaine [options]"
OPTIONS="(-u|--user) apache_utilisateur // utilisateur apache (defaut : nom_du_domaine)
 (-c|--charset) caractere_set // encodage des pages (defaut : $HTTP_DEFAULT_CHARSET. Valeurs possibles définies dans BDD glabelle.charsets)
 (-g|--group) apache_groupe // groupe apache (defaut : nom_du_domaine)
 (-e|--email) admin_email // email de l'administrateur (defaut : email du client de nom_du_domaine)
 (-r|--root) racine_web // racine de l'arborescence http dans $DOMAIN_POOL_ROOT/nom_de_domaine (defaut : $HTTP_DEFAULT_ROOT)
 (-l|--logs) logs_dir // repertoire des logs http dans $DOMAIN_POOL_ROOT/nom_de_domaine (defaut : $HTTP_DEFAULT_LOGDIR)
 "


PARAMS=`getopt -o l:,d:,u:,c:,g:,e:,r:,h,v -l logs:,domain:,user:,charset:,group:,email:,root:,help,version -- "$@"`
[ $? != 0 ] && exit 1
eval set -- "$PARAMS"


while true ; do
	case "$1" in
	-d|--domain) opt_domain="1"	; shift 1
		[ -n "$1" ] && opt_domain_val=$1 && shift 1 ;;
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
[ -z "$opt_domain" ] && error "Domain name is missing"


#argument vs system ckeckings :
[ -z "`query "select name from domains where name='$opt_domain_val';"`" ] && error "Domain $opt_domain_val is unknown"
[ -n "`query "select name from domains where name='$opt_domain_val' and mounted=0"`" ] && error "Domain $opt_domain_val is unmounted"
[ -n "`query "select name from domains where name='$opt_domain_val' and suspended=1"`" ] && error "Domain $opt_domain_val is suspended" 
[ -z "$opt_charset" ] && opt_charset_val=$HTTP_DEFAULT_CHARSET
[ -z "`query "select name from charsets where name='$opt_charset_val';"`" ] && error "Charset $opt_charset_val is unknown"
[ -z "$opt_user" ] && opt_user_val=$opt_domain_val
[ -z "$opt_group" ] && opt_group_val=$opt_domain_val
[ -z "$opt_root" ] && opt_root_val=$HTTP_DEFAULT_ROOT
[ -z "$opt_logs" ] && opt_logs_val=$HTTP_DEFAULT_LOGDIR
[ -z `echo $opt_root_val|egrep $HTTP_ROOT_REGEXP` ] && error "Invalid http root name $opt_root_val"
[ -z `echo $opt_logs_val|egrep $HTTP_LOGDIR_REGEXP` ] && error "Invalid logs directory name $opt_logs_val"
[ -z "$opt_email" ] && opt_email_val=`query "select email from clients where name=(select client from domains where name='$opt_domain_val');"`
[ -z `echo $opt_email_val|egrep $HTTP_CONTACT_EMAIL_REGEXP` ] && error "admin email $opt_email_val is invalid"
[ -n "`query "select domain from http_domains where domain='$opt_domain_val';"`" ] && error "Service http for domain $opt_domain_val already present"
[ -e "$DOMAIN_POOL_ROOT/$opt_domain_val/$opt_root_val" ] && error "A file or directory \"$opt_root_val\" exists in domain $opt_domain_val"
[ -e "$DOMAIN_POOL_ROOT/$opt_domain_val/$opt_logs_val" ] && error "A file or directory \"$opt_logs_val\" exists in domain $opt_domain_val"

#registering new http service
query "insert into http_domains (domain,serveruser,servergroup,serveradmin,documentroot,charset,logfiledir) values ('$opt_domain_val','$opt_user_val','$opt_group_val','$opt_email_val','$DOMAIN_POOL_ROOT/$opt_domain_val/$opt_root_val','$opt_charset_val','$DOMAIN_POOL_ROOT/$opt_domain_val/$opt_logs_val');" || error "Client integrity at risk; aborting"

#verif
opt_domain_val=`query "select domain from http_domains where domain='$opt_domain_val'"`
opt_root_val=`query "select documentroot from http_domains where domain='$opt_domain_val'"`
opt_logs_val=`query "select logfiledir from http_domains where domain='$opt_domain_val'"`
opt_email_val=`query "select serveradmin from http_domains where domain='$opt_domain_val'"`

#upgrading system level
#create rootdir
mkdir $opt_root_val &&
sed 's/\[HOST\]/<a href="http:\/\/glabelle.net">Glabelle.net<\/a>/g' $SCRIPTSDIR/template_files/http_index.tmpl > tmp1 &&
sed "s/\[SERVERADMIN\]/$opt_email_val/g" tmp1 > tmp2 &&
sed "s/\[NAME\]/$opt_domain_val/g" tmp2 > $opt_root_val/index.html &&
rm tmp1 tmp2 &&
chown -R $opt_domain_val:$opt_domain_val $opt_root_val &&
chmod 755 -R $opt_root_val &&
placelock $opt_root_val

#create logsdir
mkdir $opt_logs_val &&
chown -R $opt_domain_val:$opt_domain_val $opt_logs_val &&
chmod 755 -R $opt_logs_val &&
chown -R $opt_domain_val:$opt_domain_val $opt_logs_val &&
placelock $opt_logs_val

$DAEMON_HTTP_SERVER reload>/dev/null && exit 0

#otherwise, something went wrong.
error "something unexpected appened"
#peut etre effacer içi l'enregistrement en bdd ??

