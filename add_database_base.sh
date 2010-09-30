#!/bin/bash

#inclusions des procedures communes et de la configuration.
source glabmin.conf
source common.sh

#petite aide du script. Les options -h et -v sont systematiques ...
DESCRIPTION="ajouter une base de donnees pour un domaine"
USAGE="(-d|--domain) nom_du_domaine (-b|--base) nom_de_base [options]"
OPTIONS=""

PARAMS=`getopt -o d:,b:,h,v -l domain:,base:,help,version -- "$@"`
[ $? != 0 ] && exit 1
eval set -- "$PARAMS"

while true ; do
	case "$1" in
	-d|--domain) opt_domain="1"	; shift 1
		[ -n "$1" ] && opt_domain_val=$1 && shift 1 ;;
        -b|--base) opt_base="1"	; shift 1
		[ -n "$1" ] && opt_base_val=$1 && shift 1 ;;
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
[ -z "$opt_base" ] && error "Base name is missing"

#argument vs system ckeckings :
[ -z "`query "select name from domains where name='$opt_domain_val';"`" ] && error "Domain $opt_domail_val is unknown"
[ -z "`query "select domain from database_domains where domain='$opt_domain_val';"`" ] && error "Service database for domain $opt_domain_val is disabled"
[ -z `echo $opt_base_val|egrep '^[a-zA-Z]+([_]?[a-zA-Z0-9]+)$'` ] && error "Invalid base name $opt_base_val"
[ "`echo ${#opt_base_val}`" -gt "16"  ] && error "Base name $opt_base_val too long"
[ -n "`query "select name from database_bases where name='$opt_base_val'"`" ] && error "Base $opt_base_val already defined"
[ -n "`mysql -N -h$DATABASE_HOST -u$DATABASE_ADMIN_USER -p$DATABASE_ADMIN_PASS -e"use information_schema ; SELECT SCHEMA_NAME FROM SCHEMATA where SCHEMA_NAME='$opt_base_val';"`" ] && error "Base $opt_base_val is system-dedicated"
[ "`query "select count(*) from database_bases where domain='$opt_domain_val';"`" -ge "`query "select nbbase from database_domains where domain='$opt_domain_val';"`" ] && error "cannot add another base for domain $opt_domain_val"

#registering new database service
query "insert into database_bases (domain,name) values ('$opt_domain_val','$opt_base_val');"

#verif
opt_base_val=`query "select name from database_bases where domain='$opt_domain_val' and name='$opt_base_val';"`
opt_dbroot_val=`query "select dbroot from database_domains where domain='$opt_domain_val'"`

#upgrading system level
mysql -N  -h$DATABASE_HOST -u$DATABASE_ADMIN_USER -p$DATABASE_ADMIN_PASS -e"use mysql ; create database $opt_base_val;" && 
mkdir $opt_dbroot_val/$opt_base_val &&
chown mysql:mysql $opt_dbroot_val/$opt_base_val &&
mv $DB_SYSTEM_POOL/$opt_base_val/* $opt_dbroot_val/$opt_base_val &&
mount --bind $opt_dbroot_val/$opt_base_val/ $DB_SYSTEM_POOL/$opt_base_val/ && exit 0


#otherwise, something went wrong.
error "something unexpected appened"
#peut etre effacer içi l'enregistrement en bdd ??

