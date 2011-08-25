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
[ -z "$opt_domain" ] && error "Domain name is missing"


#argument vs system ckeckings :
[ -z "`query "select name from domains where name='$opt_domain_val';"`" ] && error "Domain $opt_domain_val is unknown"
[ -n "`query "select name from domains where name='$opt_domain_val' and mounted=0"`" ] && error "Domain $opt_domain_val is unmounted"
[ -n "`query "select name from domains where name='$opt_domain_val' and suspended=1"`" ] && error "Domain $opt_domain_val is suspended"
[ -z "`query "select domain from mail_domains where domain='$opt_domain_val';"`" ] && error "Service mail for domain $opt_domain_val already disabled"

#verif
opt_domain_val=`query "select domain from mail_domains where domain='$opt_domain_val';"`
opt_root_val=`query "select mailroot from mail_domains where domain='$opt_domain_val';"`
opt_email_val=`query "select pooladmin from mail_domains where domain='$opt_domain_val';"`
opt_mailadmin_val=`query "select mailadmin from mail_domains where domain='$opt_domain_val';"`

#deleting entry in glabelle db
query "delete from mail_domains where domain='$opt_domain_val';" || error "Client integrity at risk; aborting"

#deleting entries in Postfix DB :
#deleting aliases:
mailquery "delete from alias where domain='$opt_domain_val';" || error "Cannot delete aliases of domain $opt_domain_val from postfix database"
#deleting mailboxes:
mailquery "delete from mailbox where domain='$opt_domain_val';" || error "Cannot delete mailboxes of domain $opt_domain_val from postfix database"
#deleting domainadmin:
mailquery "delete from domain_admins where domain='$opt_domain_val';" || error "Cannot delete domain admins of domain $opt_domain_val from postfix database"
#deleting admin:
mailquery "delete from admin where username='$opt_mailadmin_val@$opt_domain_val';" || error "Cannot delete admins $opt_mailadmin_val@$opt_domain_val from postfix database"
#deleting domain:
mailquery "delete from domain where domain='$opt_domain_val';" || error "Cannot delete domain $opt_domain_val from postfix database"

#upgrading system level
if [ -n "`umount $opt_root_val/`" ] 
then
	$DAEMON_IMAP_SERVER stop && $DAEMON_POP3_SERVER stop && opt_reload="1"
	[ -n "`umount $opt_root_val/`" ] && error "mail pool $opt_root_val cannot be unmounted"
fi
removelock $opt_root_val &&
rm -fr $opt_root_val &&
rm -fr $MAIL_SYSTEM_POOL/$opt_domain_val 
[ -n "$opt_reload" ] && $DAEMON_IMAP_SERVER start && $DAEMON_POP3_SERVER start
exit 0

#otherwise, something went wrong.
error "something unexpected appened"
#peut etre effacer içi l'enregistrement en bdd ??

