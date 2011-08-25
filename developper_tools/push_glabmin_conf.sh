#!/bin/bash

#push the local copy of glabmin.conf to the glabelle server
#CARREFULL : glamin.conf on the server will be replaced by your local copy
#you must have been given admin privileges to successfully run this script

[ -e "./glabmin.conf" ] && scp ./glabmin.conf glabelle@glabelle.net:glabmin/glabmin.conf