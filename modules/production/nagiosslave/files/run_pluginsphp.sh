#!/bin/sh

# Run plugins from $plugindir specified in $1 file, send results to $nagiosurl
# Needs nagios-plugins, send_nrdp.php, 
# Todo:
# Syntax check on config file and report to nagios in host status
# Use subroutines
# Add verbose option

# start of code do not edit.

check_parameters ()
{
# Check for proper number of command line args.

EXPECTED_ARGS=2
E_BADARGS=65

if [ $1 -ne $EXPECTED_ARGS ]
then
	echo "Usage: `basename $0` /etc/run_plugins.conf /etc/nagiosslave.conf"
 	exit $E_BADARGS
fi

## end of function
}

check_configfile ()
{
# Check configfile syntax
E_BADCONF=66
E_NOCONF=67

if [ -e $1 ]
then
	echo "" 
else
	echo "Configuration file $1 not readable"
	exit $E_NOCONF
fi
## end of function
}

process_services ()
{
	host="$(echo $@ | cut -d, -f1)"
        service="$(echo $@ | cut -d, -f2)"
        plugin="$plugindir/$(echo "$@" | cut -d, -f 3-)"
	args="$(echo $plugin | cut -d\  -f 2-)"
	plugin="$(echo $plugin | cut -d\  -f1)"
	output=`eval $plugin $args 2>&1`
        returncode=$?
        $echocommand "$host\t$service\t$returncode\t$output" | $sendscript --url=$nagiosurl --token=$token --usestdin
}


# Start of main script
check_parameters $#
check_configfile $1
. $1		# read configuration file
check_configfile $2

if [ -d "/share/MD0_DATA/.qpkg/Optware/libexec" ]; then
	echocommand="echo -e"	# on a qnap
	plugindir=/share/MD0_DATA/.qpkg/Optware/libexec
else
	if [ -d "/share/HDA_DATA/.qpkg/Optware/libexec" ]; then
		echocommand="echo -e"   # on a qnap
		plugindir=/share/HDA_DATA/.qpkg/Optware/libexec
	else
		echocommand="echo"	# no qnap
	fi
fi

# Svae uniq hosts
uniqhosts=$tmpdir/nagiosslavehosts.conf
cat $2 | cut -d, -f1 | sort | uniq > $uniqhosts

if [ -e $plugindir/check_icmp ]
then
        plugin="check_icmp -w500,50% -c 1000,100% -t 20 -m 10"
else
        plugin="check_icmp.sh"
fi

while read inputline
do
        host=$inputline
        output="`$plugindir/$plugin $host 2>&1`"
        returncode=$?
        $echocommand "$host\t$returncode\t$output" | $sendscript --url=$nagiosurl --token=$token --usestdin
done < $uniqhosts

while read inputline
do
	process_services $inputline 
done < $2
exit 0
