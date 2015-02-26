#!/usr/bin/env bash

# Nagios Exit Codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

usage()
{
cat <<EOF

Check packet loss and errors from a few Linux tools and facilities.

        Options:
        -T <type>  Check type of loss, "ethtool/procnetdev/netstat"
        -i <int>   Interval in seconds
        -c <int>   Critical threshold as an int (0-100)
        -w <int>   Warning threshold as an int (0-100)

Usage: $0 -T procnetdev -c 95 -w 90
EOF
}

checktool () {
TOOL=$1
if [ ! -f $TOOL ]; then
        echo "Error: $TOOL not found, verify that it's in the system PATH"
        exit $UNKNOWN   
fi
}

argcheck() {
# if less than n argument
if [ $ARGC -lt $1 ]; then
        echo "Missing arguments! Use \`\`-h'' for help."
        exit 1
fi
}

# Define now to prevent expected number errors
CRIT=0
WARN=0
TIME=0
REPORT=0
INTERVAL=0
OS=$(uname)
ARGC=$#

if [ $OS != Linux ]; then 
        echo "Machine is not Linux!"
        exit $UNKNOWN
fi

argcheck 1

while getopts "hc:i:T:w:" OPTION
do
     case $OPTION in
         h)
             usage
             ;;
         c)
             CRIT="$OPTARG"
             ;;
         i)  
             TIME="$OPTARG"                                                                                                                                                                                                                                                                                              
             ;;  
         T)
             if [[ "$OPTARG" == ethtool ]]; then
                TYPE="ethtool"
                checktool $(which ethtool)
             elif [[ "$OPTARG" == procnetdev ]]; then
                TYPE="procnetdev"
                checktool /proc/net/dev
             elif [[ "$OPTARG" == netstat ]]; then
                TYPE="netstat"
                checktool $(which netstat)
             else
                echo "Unknown type!"
                exit 1
             fi
             ;;
         w) 
             WARN="$OPTARG"
             ;;
         \?)
             exit 1
             ;;
     esac
done

if [[ $TYPE == procnetdev ]]; then

        LOSS=$(awk '/[[:digit:]]/ && $5 > 0 { count=1; print $5 } END { if (count==1) { /./ } else print "0";  }' /proc/net/dev)

        if [ $LOSS -gt 0 ] && [ $LOSS -lt $CRIT ] ; then
        
                 echo "Kernel lost $LOSS packets."
                 exit $WARNING

        elif [ $LOSS -gt $CRIT ]; then

                 echo "Kernel lost $LOSS packets."
                 exit $CRITICAL
        else
                 echo "0 loss"
                 exit $OK
        fi
fi

if [[ $TYPE == ethtool ]]; then

        for item in /sys/class/net/eth[0-9];
        do
                  NIC=$(echo $item |sed 's/\/.*\///')
                  while read line
                  do
                         VAL=$(echo $line | awk -F : '{ print $2 }')
                         if [ $VAL -gt $CRIT ]; then
                                 REPORT=1
                                error+=("$line")
                         fi

                  done < <(ethtool -S $NIC | grep '(discard\|error\|drop\|loss)' | sed "s/^/$NIC/")
        done
        
        case $REPORT in
        1)
                 echo "NIC driver loss reached threshold"
                 for element in "${error[@]}"
                 do 
                        echo $element
                 done | sort -t : -k 2 -n -r
                 exit $CRITICAL
                 ;; 
        0)
                 echo "NIC driver loss did not reach threshold"
                 exit $OK
                 ;;  

        *)
                 echo "Unknown loss status."
                 exit $UNKNOWN
                 ;;
        esac

fi 

if [[ $TYPE == netstat ]]; then

        IPINDISCARD=$(netstat -s | awk '/incoming packets discarded/ { print $1 }')
        IPOUTDROPS=$(netstat -s | awk '/outgoing packets dropped/ { print $1 }')
        UDPERRORS=$(netstat -s | awk '/packet receive errors/ { print $1 }')
        UDPRCVBUFERRS=$(netstat -s | awk '/RcvbufErrors/ { print $2 }')
        UDPSNDBUFERRS=$(netstat -s | awk '/SndbufErrors/ { print $2 }')
        TCPDATALOSS=$(netstat -s | awk '/TCP data loss events/ { print $1 }')

        # Initalize variables if variable is not set due to RHEL version differences.
        if [ -z $IPDISCARD ]; then
                 IPDISCARD=0
        fi
        if [ -z $IPOUTDROPS ]; then
                 IPOUTDROPS=0
        fi
        if [ -z $UDPERRORS ]; then
                 UDPERRORS=0
        fi
        if [ -z $TCPDATALOSS ]; then
                 TCPDATALOSS=0
        fi
        if [ -z $UDPRCVBUFERRS ]; then
                 UDPRCVBUFERRS=0
        fi
        if [ -z $UDPSNDBUFERRS ]; then
                 UDPSNDBUFERRS=0
        fi

        if [ $IPINDISCARD -gt $CRIT ] || [ $IPOUTDROPS -gt $CRIT ] || [ $UDPERRORS -gt $CRIT ] || [ $TCPDATALOSS -gt $CRIT ] || [ $UDPRCVBUFERRS -gt $CRIT ] || [ $UDPSNDBUFERRS -gt $CRIT ]; 
        then
        echo -e "IP-Incoming-Discards: $IPINDISCARD\n \
                IP-Outgoing-Drops: $IPOUTDROPS\n \
                UDP-Errors: $UDPERRORS\n \
                UDP-Rcv-Buf-Errors: $UDPRCVBUFERRS\n \
                UDP-Snd-Buf-Errors: $UDPSNDBUFERRS\n \
                TCP-Data-Loss: $TCPDATALOSS" | column -t | sort -t : -k 2 -r -n
                exit $CRITICAL
        else
                echo -e "IP-Incoming-Discards: $IPINDISCARD\n \
                IP-Outgoing-Drops: $IPOUTDROPS\n \
                UDP-Errors: $UDPERRORS\n \
                UDP-Rcv-Buf-Errors: $UDPRCVBUFERRS\n \
                UDP-Snd-Buf-Errors: $UDPSNDBUFERRS\n \
                TCP-Data-Loss: $TCPDATALOSS" | column -t | sort -t : -k 2 -r -n
                exit $OK
        fi
fi

