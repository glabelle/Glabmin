#!/bin/bash

#methodes utilisées un peu partout dans les scripts ..
source glabmin.conf

query() {
	mysql -N -h$DATABASE_HOST -u$DATABASE_USER -p$DATABASE_PASS -e"use $DATABASE_NAME ; $@"
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
