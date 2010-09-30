#!/bin/bash

#inclusions des procédures communes et de la configuration.
source glabmin.conf
source common.sh

#petite aide du script. Les options -h et -v sont systèmatiques ...
DESCRIPTION="ajouter un domaine"
USAGE="(-n|--name) client_name (-d|--domain) domain_name (-p|--pasword) mot_de_passe [options]"
OPTIONS="(-s|--size) size_in_Mo //taille a allouer en megaoctets (defaut=$DOMAIN_DEFAULT_SIZE)"


PARAMS=`getopt -o n:,d:,s:,p:,h,v -l name:,domain:,size:,password:,help,version -- "$@" `
[ $? != 0 ] && exit 1
eval set -- "$PARAMS"

while true ; do
	case "$1" in
	-d|--domain) opt_domain="1" ; shift 1
		[ -n "$1" ] && opt_domain_val=$1 && shift 1 ;;
	-n|--name) opt_name="1" ;shift 1
		[ -n "$1" ] && opt_name_val=$1 && shift 1 ;;
	-p|--password) opt_password="1"	; shift 1
		[ -n "$1" ] && opt_password_val=$1 && shift 1 ;;
	-s|--size) opt_size="1"	; shift 1
		[ -n "$1" ] && opt_size_val=$1 && shift 1 ;;
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
[ -z "$opt_name" ] && error "Client name is missing"
[ -z "$opt_domain" ] && error "Domain name is missing"
[ -z "$opt_password" ] && error "Password is missing"

#argument vs system ckeckings :
[ -z "`query "select name from clients where name='$opt_name_val';"`" ] && error "Client $opt_name_val is unknown"
[ -z `echo $opt_domain_val|egrep '^[a-zA-Z0-9]+([_-]?[a-zA-Z0-9]+)*([.]{1})[a-zA-Z0-9]+([.]?[a-zA-Z0-9]+)*$'` ] && error "Invalid domain name : $opt_domain_val"
[ -n "`query "select name from domains where name='$opt_domain_val';"`" ] && error "Domain $opt_domain_val already registered"
#if no size, using default size
[ -z "$opt_size" ] && opt_size_val=$DOMAIN_DEFAULT_SIZE
#checking if given size is ok
[ -z `echo $opt_size_val|egrep '^[1-9]+[[:digit:]]*$'` ] && error "Invalid domain size $opt_size_val"
[ -z `echo "$opt_size_val<=$DOMAIN_MAXIMUM_SIZE"|bc|egrep 1` ] && error "Domain size $opt_size_val too big (must be < $DOMAIN_MAXIMUM_SIZE)"

#registering new domain
#MATHIEU : attention, le pool est en dur !
query "insert into domains (name,password,client,size,pool) values ('$opt_domain_val','$opt_password_val','$opt_name_val',$opt_size_val,'glabelle1');" error "Client integrity at risk; aborting"

#validation :
opt_password_val=`query "select password from domains where name='$opt_domain_val';"`
opt_size_val=`query "select size from domains where name='$opt_domain_val';"`
opt_domain_val=`query "select name from domains where name='$opt_domain_val';"`

#creating appropriate system side
groupadd $opt_domain_val &&
useradd -g $opt_domain_val -d $DOMAIN_POOL_ROOT/$opt_domain_val -m -s /bin/false $opt_domain_val &&
echo "$opt_domain_val:$opt_password_val"|chpasswd &&
lvcreate -L$opt_size_val -n$opt_domain_val clients &&
mkfs.ext3 /dev$DOMAIN_POOL_ROOT/$opt_domain_val &&
mount /dev$DOMAIN_POOL_ROOT/$opt_domain_val $DOMAIN_POOL_ROOT/$opt_domain_val &&
chown -R $opt_domain_val:$opt_domain_val $DOMAIN_POOL_ROOT/$opt_domain_val &&
chmod 750 $DOMAIN_POOL_ROOT/$opt_domain_val && 
cat /etc/hosts|while read line; do echo ${line/`hostname`/`hostname` $opt_domain_val} >> ./hosts.temp; done && cp ./hosts.temp /etc/hosts && rm ./hosts.temp &&
exit 0

#otherwise, something went wrong.
error "something unexpected appened"
#peut etre effacer içi l'enregistrement en bdd ??
