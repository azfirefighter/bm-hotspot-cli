#!/usr/bin/env bash
# Manage Talkgroups on MMDVM-Hotspot via Brandmeister-API

# The BM API had changed after this was orignally created.
# This is just an attempt to modernize it.
#
# Changes:
# 1) Fixed the select statements for jq so that it works
# 2) Changed the curl statements so that they match the new API
# 3) Fixed dropping all of the TG in a timeslot (took some doing)
# 4) Minor UI changes and usability enhancements

clear

# Config and variables have been broken off into ONE file
source bm-hotspot-cli.conf

ver="3.1"

function banner {
	echo $(tput setaf 3)
	echo "      ___ __  __      ___ _    ___  ";
	echo "     | _ )  \/  |___ / __| |  |_ _| ";
	echo "     | _ \ |\/| |___| (__| |__ | |  ";
	echo "     |___/_|  |_|    \___|____|___| ";
	echo " 	 		      $(tput sgr0)v$ver";
}

function dep_check {
	curlinstalled=$(which curl)
    if [[ "$?" == 1 ]]; then
        printf "\n\n    This Script requires curl.\n    Please install 'curl' to continue.\n\n\n"
		exit 0
    fi

	jqinstalled=$(which jq)
    if [[ "$?" == 1 ]]; then
        printf "\n\n    This Script requires jq.\n    Please install 'jq' to continue.\n\n\n"
		exit 0
    fi
}

function check_apikey {
	if [[ -z "$APIKEY" ]]; then
		printf "\n\n    $(tput bold)API-Key Not Found.$(tput sgr0)\n"
		printf "    Enter Brandmeister API-KEY in $(tput bold)bm-hotspot-cli.conf$(tput sgr0)!\n\n\n"
		exit 0
	fi

}

function check_hotspotid {
     if [[ -z "$HOTSPOT" ]]; then
          printf "\n\n    $(tput bold)Hotspot ID Not Found.$(tput sgr0)\n"
          printf "    Enter Hotspot ID in $(tput bold)bm-hotspot-cli.conf$(tput sgr0)!\n\n\n"
		exit 0
	fi
}

function showsettings {
    printf "\n     Hotspot ID: $HOTSPOT\n"
}

function menu {
    banner
    showsettings
    printf "\n$(tput bold)     BRANDMEISTER HOTSPOT CONTROL$(tput sgr0)\n"
    printf "$(tput bold)     ---------------------------------------$(tput sgr0)\n"
    printf "     [$(tput bold)1$(tput sgr0)] Show current Dynamic and Static TGs\n"
    printf "     [$(tput bold)2$(tput sgr0)] Drop current QSO\n"
    printf "     [$(tput bold)3$(tput sgr0)] Drop ALL Dynamic TGs\n"
    printf "     [$(tput bold)4$(tput sgr0)] Add Static TG\n"
    printf "     [$(tput bold)5$(tput sgr0)] Drop Static TG\n"
    printf "     [$(tput bold)6$(tput sgr0)] Drop ALL Static TGs NOT WORKING YET\n"
    printf "     [$(tput bold)A$(tput sgr0)] About\n"
    printf "     [$(tput bold)Q$(tput sgr0)] Quit\n"  
    printf "     $(tput bold)---------------------------------------$(tput sgr0)\n\n"
    read -r -sn1 menu_selection
    case "$menu_selection" in
            [1]) show_tgs;;
            [2]) drop_qso;;
            [3]) drop_dynamic_tgs;;
            [4]) add_static_tg;;
            [5]) drop_static_tg;;
            [6]) drop_all_static_tgs;;
            [0]) bunny;;
            [aA]) about;;
            [qQ]) printf "\n"; rm *.json; exit;;
    esac
}


function show_tgs {
     # Confirmed that the code
	printf "$(tput sgr0)$(tput setaf 3)Inquire current TGs...$(tput sgr0)\n"
	curl -s $APIURL/$HOTSPOT/talkgroup -H "accept: application/json" > ./bm-cli.json

	printf "$(tput bold)\n    Static TS1: $(tput sgr0)$(tput setaf 6)"
	jq '.[] | select(.slot=="1").talkgroup' 'bm-cli.json' | tr '\n' ' '
	printf "$(tput sgr0)"
	printf "$(tput bold)\n    Static TS2: $(tput sgr0)$(tput setaf 6)"
     jq '.[] | select(.slot=="2").talkgroup' 'bm-cli.json' | tr '\n' ' '
	printf "$(tput sgr0)\n"
	
	grep -q dynamicSubscriptions ./bm-cli.json
	if [ $? = 1 ];then
		printf "$(tput bold)\n    Dynamic: $(tput sgr0)$(tput setaf 6)NONE LISTED$(tput sgr0)"
	else
		printf "$(tput bold)\n    Dynamic on TS1: $(tput sgr0)$(tput setaf 6)"
		jq '.dynamicSubscriptions[] | select(.slot=="1").talkgroup' './bm-cli.json' | tr '\n' ' ' # The data is pulled correctly now
		printf "$(tput sgr0)\n"
		printf "$(tput bold)\n    Dynamic on TS2: $(tput sgr0)$(tput setaf 6)"
		jq '.dynamicSubscriptions[] | select(.slot=="2").talkgroup' './bm-cli.json' | tr '\n' ' ' # The data is pulled correctly now
		printf "$(tput sgr0)\n"
	fi

	grep -q timedSubscriptions ./bm-cli.json
	if [ $? = 1 ];then
		printf "$(tput bold)\n    Timed Static: $(tput sgr0)$(tput setaf 6)NONE LISTED$(tput sgr0)"
	else
		printf "$(tput bold)\n    Timed Static on TS1: $(tput sgr0)$(tput setaf 6)"
		jq '.timedSubscriptions[] | select(.slot=="1").talkgroup' './bm-cli.json' | tr '\n' ' ' # Need to verify this works still
		printf "$(tput sgr0)\n"
		printf "$(tput bold)\n    Timed Static on TS2: $(tput sgr0)$(tput setaf 6)"
		jq '.timedSubscriptions[] | select(.slot=="2").talkgroup' './bm-cli.json' | tr '\n' ' ' # Need to verify this works still
		printf "$(tput sgr0)\n"
	fi
	printf "\n"
	menu
}

function drop_qso {
     ts=""
	printf "\n"
	while [[ ! $ts =~ ^[1-2] ]]; do
		printf "    Enter the Timeslot (Numbers Only): "
		read ts
	done
	printf "$(tput setaf 3)Dropping current QSOs on Timeslot $ts...$(tput sgr0)\n\n    "
     curl -X 'GET' -s "$APIURL/$HOTSPOT/action/dropCallRoute/$ts" \
     -H 'accept: application/json' \
     -H "Authorization: Bearer $APIKEY"
     printf "\n"
	menu
}

function drop_dynamic_tgs {
     ts=""
     printf "    Enter the timeslot to drop ALL dynamic talkgroups from: "
     read ts
	printf "$(tput setaf 3)Dropping Dynamic Talkgroups from Timeslot $ts...$(tput sgr0)\n\n    "
     curl -X 'GET' -s "$APIURL/$HOTSPOT/action/dropDynamicGroups/$ts" \
     -H 'accept: application/json' \
     -H "Authorization: Bearer $APIKEY" | jq '.message'
	menu
}

function add_static_tg {
	tg=""
	ts=""
	printf "\n"
	while [[ ! $ts =~ ^[1-2] ]]; do
		printf "    Enter the Timeslot (Numbers Only): "
		read ts
	done
	while [[ ! $tg =~ ^[0-9] ]]; do
		printf "    Enter Talkgroup ID (Numbers Only): "
	    read tg
	done
	printf "\n$(tput setaf 3)    Adding Talkgroup $tg to Timeslot $ts.$(tput sgr0)\n\n    "
               curl -X 'POST' -s \
               "$APIURL/$HOTSPOT/talkgroup" \
               -H 'accept: application/json' \
               -H "Authorization: Bearer $APIKEY"  \
               -H 'Content-Type: application/json' \
               -d "{\"slot\": $ts,\"group\": $tg}" | jq '.talkgroup' | grep -q "$tg"
               if [ $? = 0 ];then
                    printf "    Talkgroup $tg was added successfully to Timeslot $ts!\n"
               else
                    printf "    Error! TG $tg was $(tput bold)NOT$(tput sgr0) added to Timeslot $ts!\n"        
	          fi
	menu
}

function drop_static_tg {
	tg=""
	ts=""
	printf "\n"
        while [[ ! $ts =~ ^[1-2] ]];do
		printf "    Enter Timeslot (Numbers Only:) "
		read ts
	done
	while [[ ! $tg =~ ^[0-9] ]]; do
		printf "    Enter Talkgroup ID (Numbers Only): "
	    read tg
	done
	printf "\n$(tput setaf 3)    Dropping Talkgroup $tg from Timeslot $ts...$(tput sgr0)\n\n    "
	curl -X 'DELETE' -s -o output "$APIURL/$HOTSPOT/talkgroup/$ts/$tg" \
	     -H 'accept: */*' \
          -H "Authorization: Bearer $APIKEY" | jq '.message'
     grep -q "1" output
     if [ $? = 0 ];then
          printf "    Talkgroup $tg has been $(tput bold)removed$(tput sgr0) from Timeslot $ts.\n"
          rm output
          menu
     else
          printf "$(tput bold)    There was some kind of error and Talkgroup $tg was NOT removed from Timeslot $ts!$(tput sgr0)\n"
     fi
     rm output
	menu
}

function drop_all_static_tgs {
    # curl current static TGs into an array
    ts=""
    ans=""
    curl -s $APIURL/$HOTSPOT/talkgroup -H "accept: application/json" > ./drop-bm-cli.json
    while [[ ! $ts =~ ^[1-2] ]]; do
		printf "    Enter the Timeslot (Numbers Only): "
		read -r -sn1 ts
    done
    case "$ts" in
          1)
               printf "\n    Selecting talkgroup $ts\n"
               jq '.[] | select(.slot=="1").talkgroup' './drop-bm-cli.json' | tr '\n' ',' > to-nuke
               sed -i 's/\"//g' to-nuke
               sed -i 's/.$//' to-nuke
		     printf "    Are you $(tput bold)SURE$(tput sgr0) (Y/N)?\n"
		     read -r -sn1 ans
		     case "$ans" in
		          Y|y);;
		          N|n)
		               menu
		          ;;
		     esac
               printf "    Are you $(tput bold)REALLY SURE$(tput sgr0) (Y/N)?\n"
               read -r -sn1 ans
		     case "$ans" in
		          Y|y);;
		          N|n)
		               menu
		          ;;
		     esac
               ;;
          2)
               printf "\n    Selecting talkgroup $ts\n"
               jq '.[] | select(.slot=="2").talkgroup' './drop-bm-cli.json' | tr '\n' ',' > to-nuke
               sed -i 's/\"//g' to-nuke
               cat to-nuke | tr ',' '\n' > really-nuke
		     printf "    Are you $(tput bold)SURE$(tput sgr0) (Y/N)?\n"
		     read -r -sn1 ans
		     case "$ans" in
		          Y|y);;
		          N|n)
		               menu
		          ;;
		     esac
               printf "    Are you $(tput bold)REALLY SURE$(tput sgr0) (Y/N)?\n"
               read -r -sn1 ans
		     case "$ans" in
		          Y|y);;
		          N|n)
		               menu
		          ;;
		     esac
               ;;
    esac
    static_tgs=$(cat to-nuke) 
    if [ -z $static_tgs ]; then
        printf "\n    No Static TGs on Hotspot $(tput bold)$HOTSPOT$(tput sgr0) $(tput bold)(TS $ts)$(tput sgr0) found, aborting...\n\n"
		menu
   else
        IFS=''
        while read i; do
            curl -X 'DELETE' "$APIURL/$HOTSPOT/talkgroup/$ts/$i" \
	       -H 'accept: */*' \
            -H "Authorization: Bearer $APIKEY"
            printf "    $(tput setaf 6)$i $(tput sgr0)Dropped\n\n"
        done < really-nuke
    fi
     rm to-nuke
     rm really-nuke
     rm drop-bm-cli.json
	menu
}


function bunny {
	printf "\n\n    $(tput setaf 6)APIURL: $APIURL\n    APIKEY: $APIKEY\n\n    HOTSPOT_ID: $HOTSPOT\n\n"
	dep_check
	printf "\n\n    $(tput setaf 5)/)___(\ \n    (='.'=)\n    (\")_(\")$(tput sgr0)$(tput bold) (v$ver) by $Author.$(tput sgr0)\n\n"
	printf "\n\n    $(tput bold)Modified by $MOD.$(tput sgr0)\n\n"
	menu
}

function about {
     clear
     banner
     printf "\n\nThis program was created to assist in managing the basics of your Brandmeister hotspot.\n"
     printf "It was originally created in $Date by $Author for an earlier version of the API.\n"
     printf "It was further modified by $MOD in $MODDate to use the current API (at that time).\n\n"
     printf "$(tput bold)Press any key to return to menu.$(tput sgr0)"
     read
     clear
     menu
}

dep_check
check_apikey
check_hotspotid


menu
