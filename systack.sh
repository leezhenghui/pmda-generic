#!/bin/bash

# environment
PATH=/bin:/usr/bin:$PATH
TS=$(date +%Y-%m-%d_%T)
HOSTNAME=$(uname -n)
PMADIR=/usr/lib/jvm/perf-map-agent
WEBDIR=/usr/share/pcp/webapps/systack
WDIR=/var/log/pcp/generic/SYSTACK
BDIR=/var/lib/pcp/pmdas/generic/BINFlameGraph
SVG=$WEBDIR/systack.svg
PERF=$WDIR/perf.data.$TS
FOLDED=$WDIR/perf-cpu-stacks.folded

# ensure output directories exist
[ ! -d "$WDIR" ] && mkdir -p $WDIR
[ ! -d "$WEBDIR" ] && mkdir -p $WEBDIR
[ -d "$WEBDIR" -a -e "$SVG" ] && rm $SVG

# profile
perf record -o $PERF -a -g -F 49 sleep 60 1>> /dev/null 2>> /dev/null

# lower our priority before flame graph generation, to reduce CPU contention:
renice -n 19 -p $$ 1>>/dev/null 2>> /dev/null

# generate java symbol maps
for pid in $(pgrep -x java); do
        mapfile=/tmp/perf-$pid.map
	# perf-map-agent output may be in /out subdir, or not:
        if [ -e $PMADIR/out ]; then
                cd $PMADIR/out
	elif [ -e $PMADIR ]; then
		cd $PMADIR
	else
                # dummy map to include an error message in the flame graph
                echo "000000000000 f00000000000 missing_perf_map" > $mapfile
		continue
	fi
	# XXX todo: set JAVA_HOME based on running pid
	JAVA_HOME=/usr/lib/jvm/java-8-oracle
	if [ -d $JAVA_HOME ]; then
		# run as java user to avoid "well-known file is not secure" error
		JAVA_USER=$(ps ho user -p $pid)
		if [[ "$JAVA_USER" == [0-9]* ]]; then
			# long usernames can break traditional tools; roll our own:
			JAVA_USER=$(awk -v uid=$JAVA_USER -F: '$3 == uid { print $1 }' /etc/passwd)
		fi
		[ -e $mapfile ] && rm $mapfile
		sudo -u $JAVA_USER $JAVA_HOME/bin/java -cp attach-main.jar:$JAVA_HOME/lib/tools.jar net.virtualvoid.perf.AttachOnce $pid 1>> /dev/null 2>> /dev/null
		chown root:root $mapfile
	fi
done

# fix node.js symbol ap ownerships
gotnode=0
for pid in $(pgrep -x node); do
        mapfile=/tmp/perf-$pid.map
	if [ ! -e $mapfile ]; then
		# dummy map to include an error message in the flame graph
		echo "000000000000 f00000000000 missing_perf_map" > $mapfile
		continue
	fi
	gotnode=1
	user=$(stat -c '%U' $mapfile)
	if [[ "$user" == root ]]; then
		continue
	fi
	# Change ownership to root for perf, but retain rw access for the
	# process. This last step may not be strictly necessary: if node keeps
	# the FD open and keeps writing to it, it may not reevaluate
	# permissions.
	setfacl -m u:$user:rw $mapfile
	chown root:root $mapfile
done

# decide upon a palette
if (( gotnode )); then
	color=js
else
	color=java
fi

timeout 20 perf script -i $PERF | $BDIR/stackcollapse-perf.pl | grep -v cpu_idle > $FOLDED
$BDIR/flamegraph.pl --minwidth=0.5 --color=$color --hash --title="CPU Flame Graph (no idle): $HOSTNAME, $TS" < $FOLDED > $SVG

# $PERF file left behind for debug or custom reports (will be overwritten next time)
