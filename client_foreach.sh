#!/bin/bash

#inclusions des procédures communes et de la configuration.
source glabmin.conf
source common.sh

#petite aide du script. Les options -h et -v sont systèmatiques ...
DESCRIPTION="traitement par lot sur les clients"
USAGE="(-c|--command) \"<commande>\" [options]"
OPTIONS=""
PARAMETERS="[CLIENT]	nom du client courant
 [ADDRESS]	adresse du client courant
 [EMAIL]	adresse email du client courant"


PARAMS=`getopt -o c:,h,v -l command:,help,version -- "$@" `
[ $? != 0 ] && exit 1
eval set -- "$PARAMS"

while true ; do
	case "$1" in
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
[ -z "$opt_command" ] && echo "Command name is missing" && exit 1

#looping clients, replacing parameter & executing command ..
for CLIENT in `query "select name from clients;"`
do
        EMAIL=`query "select email from clients where name='$CLIENT';"`
        ADDRESS=`query "select address from clients where name='$CLIENT';"`
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
        command=${command//\[CLIENT\]/$CLIENT}
        command=${command//\[ADDRESS\]/$ADDRESS}
        command=${command//\[EMAIL\]/$EMAIL}
        command=`echo $command | sed "s#SUBCOMMAND#$sub_command#g"`
        bash -c "$command" 2>&1
done

exit 0

