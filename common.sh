#!/bin/bash

#methodes utilisées un peu partout dans les scripts ..

source glabmin.conf


#place un vérrou dans un dossier passé en paramêtre (p. ex. /home/glabelle )
#Méthode sure, si le placement echoue, on nettoie et renvoie faux 
placelock () {
	( 
		[ -d "$@" ] &&
		touch $@/.lock &&
		chmod 000 $@/.lock &&
		chown root:root $@/.lock &&
		chattr +i $@/.lock #-> sortie si tout se passe bien
	) || ( 
		[ -e "$@/.lock" ] && 		#-> Sorties possibles quand cela se passe mal
		rm -fr  $@/.lock && false	#-> 
	)
}

#methode inverse, supprime un verrou .. 
removelock () {
	(
		[ -d "$@" ] &&
		chattr -i $@/.lock && 
		rm -fr $@/.lock
	) || (
		[ -e "$@/.lock" ] &&
		chattr +i $@/.lock && false
	)
}


query() {
	mysql --silent -N -h$DATABASE_HOST -u$DATABASE_USER -p$DATABASE_PASS -e"use $DATABASE_NAME ; $@"
}

adminquery() {
	mysql -N -h$DATABASE_HOST -u$DATABASE_ADMIN_USER -p$DATABASE_ADMIN_PASS -e"use mysql ; $@"
}

mailquery() {
	mysql -N -h$MAIL_DATABASE_HOST -u$MAIL_DATABASE_USER -p$MAIL_DATABASE_PASS -e"use $MAIL_DATABASE_NAME ; $@"
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
 
echo -e "$(basename $0), $DESCRIPTION

Usage:
------
 $(basename $0) $USAGE
 
Options:
-------------
 $OPTIONS (-h|--help) //Cet ecran d'aide
 (-v|--version) //Version du script

Parameters:
-------------
 $PARAMETERS"
}
