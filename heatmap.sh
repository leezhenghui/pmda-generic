#!/bin/bash
TS=`date +%Y%m%d-%T`
NETFLIX_ENVIRONMENT=test
export NETFLIX_ENVIRONMENT
INSTANCE=`wget -q -O - http://169.254.169.254/latest/meta-data/instance-id`
S3BUCKET="s3://nflx.cldperf.test/pcp/$INSTANCE"
# /usr/bin/s3cp README $S3BUCKET/README1
#DIR
WEBDIR=/usr/share/pcp/webapps/heatmap
WDIR=/mnt/logs/pcp/generic/HEATMAP
BDIR=/var/lib/pcp/pmdas/generic/BINHeatMap
#FILE
SVG=$WEBDIR/heatmap.svg
PERF=$WDIR/perf.data.$TS
#
if [ ! -d "$WDIR" ]
then 
/bin/mkdir -p $WDIR
fi

if [ ! -d "$WEBDIR" ]
then 
/bin/mkdir -p $WEBDIR
fi
#
if [ -d "$WEBDIR" ]
then 
/bin/rm $SVG
fi
#
#
/usr/bin/perf record -o $PERF -e block:block_rq_issue -e block:block_rq_complete -a sleep 120 &> /dev/null 
timeout 20 /usr/bin/perf script -i $PERF| awk '{ gsub(/:/, "") } $5 ~ /issue/ { ts[$6, $10] = $4 } $5 ~ /complete/ { if (l = ts[$6, $9]) { printf "%.f %.f\n", $4 * 1000000, ($4 - l) * 1000000; ts[$6, $10] = 0 } }' > $WDIR/out.lat_us
#
$BDIR/trace2heatmap.pl --unitstime=us --unitslat=us --grid --maxlat=100000 $WDIR/out.lat_us >$SVG
#/usr/bin/s3cp $SVG $S3BUCKET/heatmap-$TS.svg &> /dev/null
#clean up
#/bin/rm $PERF
#/bin/rm $WDIR/out.lat_us
