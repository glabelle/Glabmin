#!/bin/bash

#inclusions des procédures communes et de la configuration.
source glabmin.conf
source common.sh

#petite aide du script. Les options -h et -v sont systèmatiques ...
DESCRIPTION="traitement par lot sur les sous-domaines d'un domaine"
USAGE="(-n|--name) client_name (-d|--domain) (-c|--command) \"<commande>\" [options]"
OPTIONS=""
PARAMETERS="[DOMAIN]	nom du domaine courant
 [SUBDOMAIN]	nom du sous-domaine courant
 [CLIENT]	nom du client"


PARAMS=`getopt -o n:,d:,c:,h,v -l name:,domain:,command:,help,version -- "$@" `
[ $? != 0 ] && exit 1
eval set -- "$PARAMS"

while true ; do
	case "$1" in
	-n|--name) opt_name="1"	; shift 1
		[ -n "$1" ] && opt_name_val=$1 && shift 1 ;;
	-d|--domain) opt_domain="1"	; shift 1
		[ -n "$1" ] && opt_domain_val=$1 && shift 1 ;;
	-c|--command) opt_command="1"	; shift 1
		[ -n "$1" ] && opt_command_val=$1 && shift 1 ;;
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
#if no domain or no password, then display help and exit
[ -z "$opt_name" ] && echo "Client name is missing" && exit 1
[ -z "$opt_domain" ] && echo "Domain name is missing" && exit 1
[ -z "$opt_command" ] && echo "Command name is missing" && exit 1


#argument vs system ckeckings :
[ -z "`query "select name from clients where name='$opt_name_val';"`" ] && echo "ERROR : Client $opt_name_val is unknown" && exit 1
[ -z "`query "select name from domains where name='$opt_domain_val' and client='$opt_name_val';"`" ] && echo "ERROR : Domain $opt_domain_val is unknown" && exit 1

#montages .. pas grand chose pour le moment ..

for SUBDOMAIN in `query "select name from subdomains where domain='$opt_domain_val';"`
do
        command=$opt_command_val
        command=`echo $command | sed 's#>$##g'`
        command=`echo $command | sed 's#^<##g'`
        sub_command=`echo $command | grep -o '"<.*>"'`
        sub_command=`echo $sub_command | sed 's#>"$##g'`
        sub_command=`echo $sub_command | sed 's#^"<##g'`
	sub_command=`echo $sub_command | sed 's#&#\\\\&#g'`
        echo $sub_command | sed -e 's:":\\\\":g'>tmp
        sub_command=`cat tmp`
        rm tmp
        sub_command='"<'$sub_command'>"'
        command=`echo $command | sed 's#"<.*>"#SUBCOMMAND#g'`
        command=${command//\[DOMAIN\]/$opt_domain_val}
        command=${command//\[SUBDOMAIN\]/$SUBDOMAIN}
        command=${command//\[CLIENT\]/$opt_name_val}
        command=`echo $command | sed "s#SUBCOMMAND#$sub_command#g"`
        bash -c "$command" 2>&1
done 

exit 0

#otherwise, something went wrong.
echo "ERROR : something unexpected appened" && exit 1

