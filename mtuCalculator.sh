#!/bin/bash

function displayOutput() {
    local pid=$1
    local textRotate='calculating mtu'
    local dispInt=0.1
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${textRotate#?}
        printf " [%c]  " "$textRotate"
        local textRotate=$temp${textRotate%"$temp"}
        sleep $dispInt
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

function mtuFind() {
	mode=0
	pass=0
	failPoint=1
	while [[ $failPoint > 0 ]]; do
		mtu=$(ping -D -c 1 -t 1 -s $mtuSize $host &>/dev/null)
		if [ "$?" -eq "2" ]; then
			if [[ $mode = 0 ]] ; then
				mtuSize=`expr $mtuSize - 10`
			else
				mtuSize=`expr $mtuSize - 1`
			fi
		else
			if [[ $pass = 0 ]] ; then
				mtuSize=`expr $mtuSize + 9`
				mode=1
				pass=1
			else
				echo $mtuSize > /tmp/finalSize
				failPoint=0
			fi
		fi
	done
}

function report() {
	sysMtu=$(ifconfig $nicInUse | grep mtu | awk '{print $NF}')
	finalSize=$(cat /tmp/finalSize)
	bigSize=`expr $finalSize + 28`
	echo "The largest contiguous packet that can pass down the link is $finalSize bytes, or $bigSize bytes including 28 bytes of ICMP/IP headers."
	echo ""
	if [ $sysMtu = $bigSize ] ; then
		echo "This matches your network card's MTU, $sysMtu."
	else
		echo "The calculated MTU and the system MTU ($sysMtu) don't match! This probably means that something, somewhere could be broken, or is at least interesting."
		read -r -p "Would you like to set your MTU for $nicInUse? [y/N] (You will be asked for an admin password.) " response
		if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]] ; then
			networksetup -setMTU $nicInUse $bigSize
			if [ $(networksetup -getMTU $nicInUse | awk '{print $3}') = $bigSize ] ; then 
				echo "$nicInUse MTU updated to $bigSize."
			else
				echo "There was a problem updating your MTU!  Please run the following command:"
				echo "sudo networksetup -setMTU $bigSize"
			fi
		fi
		read -r -p "Open Wikipedia MTU entry? [y/N] " response
		if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]] ; then
			open http://en.wikipedia.org/wiki/Maximum_transmission_unit
		fi
	fi
	echo ""
	rm /tmp/finalSize
	export finalSize
	export bigSize
}

if [ -z "$1" ] ; then 
	read -p "Enter host to test against:" host
else
	host=$1
fi

pingTest=$(ping -c 1 $host &>/dev/null)
if [ "$?" -eq "0" ]; then
	nicInUse=$(route get $host | grep interface | awk '{print $2}')
	mtuSize=1500
	echo ""
	(mtuFind) & displayOutput $!
	report
else
	echo "Unable to ping host: please re-run, and try again."
fi
