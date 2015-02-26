#!/usr/bin/env bash

# Nagios Exit Codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

usage()
{
cat <<EOF

Check the capacity of a volume using df.

     Options:
        -v         Specify volume as mountpoint
        -c         Critical threshold as an int (0-100)
        -w         Warning threshold as an int (0-100)

Usage: $0 -v /mnt -c 95 -w 90
EOF
}

if [ $# -lt 6 ]; 
then
	usage
	exit 1
fi

# Define now to prevent expected number errors
VOL=/dev/da0
CRIT=0
WARN=0
OS=$(uname)

while getopts "hc:v:w:" OPTION
do
     case $OPTION in
         h)
	     usage
             ;;
         c)
	     CRIT="$OPTARG"
             ;;
         v)
             VOL="$OPTARG"
             ;;
	 w) 
	     WARN="$OPTARG"
	     ;;
         \?)
             exit 1
             ;;
     esac
done

if [[ $OS == AIX ]]; then
	STATUS=$(df $VOL | awk '!/Filesystem/ { print $4 }' | sed 's/%//')
else
	STATUS=$(df $VOL | awk '!/Filesystem/ { print $5 }' | sed 's/%//')
fi

if [ $STATUS -gt $CRIT ]; then
        echo "$VOL is at ${STATUS}% capacity!"
        exit $CRITICAL
elif [ $STATUS -gt $WARN ]; then
        echo "$VOL is at ${STATUS}% capacity!"
        exit $WARNING
else
        echo "$VOL is at ${STATUS}% capacity"
        exit $OK
fi 
