#!/bin/bash

#inclusions des procédures communes et de la configuration.
source glabmin.conf
source common.sh

#petite aide du script. Les options -h et -v sont systèmatiques ...
DESCRIPTION="ajouter un client"
USAGE="(-n|--name) nom_du_client (-e|--email) email_de_contact [options]"
OPTIONS="(-a|--address) \"adresse_du_client\" //Adresse postale
"


PARAMS=`getopt -o n:,e:,a:,h,v -l name:,email:,address:,help,version -- "$@"`
[ $? != 0 ] && exit 1
eval set -- "$PARAMS"



while true ; do
	case "$1" in
	-n|--name) opt_name="1"	; shift 1
		[ -n "$1" ] && opt_name_val=$1 && shift 1 ;;
	-e|--email) opt_email="1" ; shift 1
		[ -n "$1" ] && opt_email_val=$1 && shift 1 ;;
	-a|--address) opt_address="1"; shift 1
	        [ -n "$1" ] && opt_address_val=$1 && shift 1 ;;
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
[ -z "$opt_name" ] && echo "ERROR : Client name is missing" && exit 1
[ -z "$opt_email" ] && echo "ERROR : Client email is missing" && exit 1

#argument vs system ckeckings :
[ -z `echo $opt_name_val|egrep '^[a-zA-Z0-9]+([_-]?[a-zA-Z0-9]+)*$'` ] && echo "ERROR : Invalid client name : $opt_name_val" && exit 1
[ -n "`query "select name from clients where name='$opt_name_val';"`" ] && echo "ERROR : Client name already registered" && exit 1
[ -z `echo $opt_email_val|egrep '\w+([_-]\w)*@\w+([._-]\w)*\.\w{2,4}'` ] && echo "ERROR : Invalid email : $opt_email_val" && exit 1

#registering new client
query "insert into clients (name,address,email) values('$opt_name_val','$opt_address_val','$opt_email_val')" && exit 0

#otherwise, something went wrong.
echo "ERROR : something unexpected appened" && exit 1
#peut etre effacer içi l'enregistrement en bdd ??
