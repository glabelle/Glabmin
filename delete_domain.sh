#!/bin/bash

#inclusions des procédures communes et de la configuration.
source glabmin.conf
source common.sh

#petite aide du script. Les options -h et -v sont systèmatiques ...
DESCRIPTION="supprimer un domaine"
USAGE="(-d|--domain) domain_name [options]"
OPTIONS=""


PARAMS=`getopt -o d:,h,v -l domain:,help,version -- "$@" `
[ $? != 0 ] && exit 1
eval set -- "$PARAMS"

while true ; do
	case "$1" in
	-d|--domain) opt_domain="1" ; shift 1
		[ -n "$1" ] && opt_domain_val=$1 && shift 1 ;;
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
#if no domain, then exit
[ -z "$opt_domain" ] && error "Domain name is missing"

#argument vs system ckeckings :
[ -z "`query "select name from domains where name='$opt_domain_val';"`" ] && error "Domain $opt_domain_val is unknown"
[ -n "`query "select name from domains where name='$opt_domain_val' and mounted=0"`"] && error "Domain $opt_domain_val is unmounted" 
[ -n "`lsof $DOMAIN_POOL_ROOT/$opt_domain_val`" ] && error "Domain $opt_domain_val cannot be unmounted" && echo "processes : `lsof -t $DOMAIN_POOL_ROOT/$opt_domain_val`" #umount check

#validation :
opt_domain_val=`query "select name from domains where name='$opt_domain_val';"`

# Mathieu : On ne passe pas a la suite tant que la base n'a pas été correctement vidée.
# Autrement dit, il faut que tous les enregistrements avec des clés étrangère domaine aient été virées.
query "delete from domains where name='$opt_domain_val';" error "Client integrity at risk; aborting" #provoque une erreur si ce n'est pas possible

#creating appropriate system side
cat /etc/hosts|while read line; do echo ${line/$opt_domain_val /} >> ./hosts.temp; done && cp ./hosts.temp /etc/hosts && rm ./hosts.temp &&
umount /dev$DOMAIN_POOL_ROOT/$opt_domain_val &&
lvremove -f /dev$DOMAIN_POOL_ROOT/$opt_domain_val &&
userdel -r $opt_domain_val && exit 0

#otherwise, something went wrong.
error "something unexpected appened"
