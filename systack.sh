#!/bin/bash

# environment
#. /etc/profile.d/netflix_environment.sh
PATH=/bin:/usr/bin:$PATH
TS=$(date +%Y-%m-%d_%T)
HOSTNAME=$(uname -n)
PMADIR=/usr/lib/jvm/perf-map-agent
WEBDIR=/usr/share/pcp/webapps/systack
WDIR=/mnt/logs/pcp/generic/SYSTACK
BDIR=/var/lib/pcp/pmdas/generic/BINFlameGraph
SVG=$WEBDIR/systack.svg
PERF=$WDIR/perf.data.$TS
FOLDED=$WDIR/perf-cpu-stacks.folded
S3BUCKET="s3://nflx.cldperf.$NETFLIX_ENVIRONMENT/pcp/$EC2_INSTANCE_ID"

# ensure output directories exist
[ ! -d "$WDIR" ] && mkdir -p $WDIR
[ ! -d "$WEBDIR" ] && mkdir -p $WEBDIR
[ -d "$WEBDIR" -a -e "$SVG" ] && rm $SVG

# profile
perf record -o $PERF -a -g -F 97 sleep 60 1>> /dev/null 2>> /dev/null

# lower our priority before flame graph generation, to reduce CPU contention:
renice -n 19 -p $$ 1>>/dev/null 2>> /dev/null

# generate java symbol maps
for pid in $(pgrep -x java); do
        mapfile=/tmp/perf-$pid.map
        if [ -e $PMADIR ]; then
                cd $PMADIR
                # XXX todo: set JAVA_HOME based on running pid
                JAVA_HOME=/usr/lib/jvm/java-8-oracle
		if [ -d $JAVA_HOME ]; then
			# run as java user to avoid "well-known file is not secure" error
			JAVA_USER=$(ps ho user -p $pid)
			sudo -u $JAVA_USER $JAVA_HOME/bin/java -cp attach-main.jar:$JAVA_HOME/lib/tools.jar net.virtualvoid.perf.AttachOnce $pid 1>> /dev/null 2>> /dev/null 
			chown root:root $mapfile
		fi
        else
                # dummy map to include an error message in the flame graph
                echo "000000000000 f00000000000 missing_perf_map" > $mapfile
        fi
done

# generate flame graph and stash it away with the folded profile on s3
timeout 20 perf script -i $PERF | $BDIR/stackcollapse-perf.pl | grep -v cpu_idle > $FOLDED
$BDIR/flamegraph.pl --color=java --title="CPU Flame Graph (no idle): $HOSTNAME, $TS" < $FOLDED > $SVG
#s3cp $SVG $S3BUCKET/perf-cpu-stacks-$TS.svg &> /dev/null
#s3cp $FOLDED $S3BUCKET/perf-cpu-stacks-$TS.folded &> /dev/null

# $PERF file left behind for debug or custom reports (will be overwritten next time)
