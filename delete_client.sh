#!/bin/bash

#inclusions des procédures communes et de la configuration.
source glabmin.conf
source common.sh

#petite aide du script. Les options -h et -v sont systèmatiques ...
DESCRIPTION="supprimer un client"
USAGE="(-n|--name) nom_du_client [options]"
OPTIONS=""

PARAMS=`getopt -o n:,h,v -l name:,help,version -- "$@"`
[ $? != 0 ] && exit 1
eval set -- "$PARAMS"



while true ; do
	case "$1" in
	-n|--name) opt_name="1"	; shift 1
		[ -n "$1" ] && opt_name_val=$1 && shift 1 ;;
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

#argument vs system ckeckings :
[ -z "`query "select name from clients where name='$opt_name_val';"`" ] && echo "ERROR : Client $opt_name_val is unknown" && exit 1

#validation :
opt_name_val=`query "select name from clients where name='$opt_name_val';"`

# Mathieu : On ne passe pas a la suite tant que la base n'a pas été correctement vidée.
# Autrement dit, il faut que tous les enregistrements avec des clés étrangère domaine aient été virées.
query "delete from clients where name='$opt_name_val';" && exit 0

#creating appropriate system side
#rien a faire ...

#otherwise, something went wrong.
echo "ERROR : something unexpected appened" && exit 1
