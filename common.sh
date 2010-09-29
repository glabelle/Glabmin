#!/bin/bash

#methodes utilisées un peu partout dans les scripts ..
source glabmin.conf

query() {
	mysql --silent -N -h$DATABASE_HOST -u$DATABASE_USER -p$DATABASE_PASS -e"use $DATABASE_NAME ; $@"
}

error() {
	echo  -e '\E[41m'"\033[1mERROR\033[0m"": $@" ; exit 1
}

warning() {
	echo  -e '\E[43m'"\033[1mWARNING\033[0m"": $@" ; true
}

usage(){
[ -z "$PARAMETERS" ] && PARAMETERS="\n"
[ -n "$OPTIONS" ] && OPTIONS=$OPTIONS"\n"
 
echo "$(basename $0), $DESCRIPTION

Usage:
------
 $(basename $0) $USAGE
 
Options:
-------------
 $OPTIONS(-h|--help) //Cet ecran d'aide
 (-v|--version) //Version du script

Parameters:
-------------
 $PARAMETERS"
}
