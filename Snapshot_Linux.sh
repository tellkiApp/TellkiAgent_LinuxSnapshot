######################################################################################################################
## This script was developed by Guberni and is part of Tellki monitoring solution                     		 		##
##                                                                                                      	 		##
## December, 2014                     	                                                                	 		##
##                                                                                                      	 		##
## Version 1.0                                                                                          	 		##
##																									    	 		##
## DESCRIPTION: Collect server snapshot (processes running, CPU and memory usage,...). 						 		##
##																											 		##
## SYNTAX: ./Snapshot_Linux.sh             														 					##
##																											 		##
## EXAMPLE: ./Snapshot_Linux.sh          														    	 			##
##																											 		##
##                                      ############                                                    	 		##
##                                      ## README ##                                                    	 		##
##                                      ############                                                    	 		##
##																											 		##
## This script is used combined with runremote_Infos.sh script, but you can use as standalone. 			    		##
##																											 		##
## runremote:Infos.sh - executes input script locally or at a remove server, depending on the LOCAL parameter.		##
##																											 		##
## SYNTAX: sh "runremote_Infos.sh" <HOST> <INFO_UUID> <USER_NAME> <PASS_WORD> <TEMP_DIR> <SSH_KEY> <LOCAL> 	 		##
##																											 		##
## EXAMPLE: (LOCAL)  sh "runremote_Infos.sh" "Snapshot_Linux.sh" "192.168.1.1" "1" "" "" "" "" "1"              	##
## 			(REMOTE) sh "runremote_Infos.sh" "Snapshot_Linux.sh" "192.168.1.1" "1" "user" "pass" "/tmp" "null" "0"  ##
##																											 		##
## HOST - hostname or ip address where script will be executed.                                         	 		##
## INFO_UUID - (internal): only used by tellki default monitors.       	 											##
## USER_NAME - user name required to connect to remote host. Empty ("") for local monitoring.           	 		##
## PASS_WORD - password required to connect to remote host. Empty ("") for local monitoring.            	 		##
## TEMP_DIR - (remote monitoring only): directory on remote host to copy scripts before being executed.		 		##
## SSH_KEY - private ssh key to connect to remote host. Empty ("bull") if password is used.                 	 	##
## LOCAL - 1: local monitoring / 0: remote monitoring                                                   	 		##
######################################################################################################################

TS=`date -u "+%Y-%m-%dT%H:%M:%SZ"`

INFO_UUID="3"
SCRIPT="`basename $0`"
TEMPDIR="`dirname $0`"


uptime=`cat /proc/uptime | awk '{print $1}'`
procsblocked=`cat /proc/stat | grep procs_blocked | awk '{print $2}'`
#vmstatOUT=`vmstat`
queuelength=`vmstat |tail -1|awk '{print $1}'`
#cpuuser;cpusystem                              
cpu=`vmstat|tail -1|awk '{print $(NF-3)";"$(NF-2)}'`


uptimeOUT=`uptime`
#loadavg1min;loadavg5min;loadavg15min
load=`echo $uptimeOUT |awk -F':' '{print $NF}' | awk -F',' '{print $1";"$2";"$3}'| sed 's/ //g'`


#freeOUT=`free`
#swapused;swapfree
swap=`free | grep Swap | awk '{print int($3/1024)";"int($4/1024)}'`
#memused;memfree
mem=`free  | grep Mem | awk '{print int($3/1024)";"int($4/1024)}'`


#

ProcListcmd="ps --no-headers -eo user,pid,%cpu,%mem,vsz=VirtMem,rss=PhysMem,lstart,time,maj_flt=MajPageFlts,min_flt=MinPageFlts,nlwp=Threads,stat,pri,args"

$ProcListcmd > $TEMPDIR/snapout

exec 0<$TEMPDIR/snapout

while read line
do
	#colUser;colPid;colCpu;colMem;colVsz;colRss
	colUser=`echo $line| awk '{print $1";"$2";"$3";"$4";"$5";"$6}'`
	colLstart=`echo $line| awk '{print $7,$8,$9,$10,$11}'`
	#convert lstart to utc date
	colLstartUTC=`date -d "$colLstart" -u "+%Y-%m-%dT%H:%M:%SZ"`	
	#colTime;colMajflt;colThcount;colStat;colPri;colArgs
	colTime=`echo $line| awk '{print $12";"$13";"$14";"$15";"$16";"$17}'`
	# save complete command with all parameters
	ProcArgs=`echo $line | awk '{for (i=18;i<=NF;i++){printf "%s ", $i}}'`
	# truncate process characters to maximum of 80
	ProcArgsTrunc=`expr substr "$ProcArgs" 1 80` 
	ProcLine=`echo -n "$colUser;$colLstartUTC;$colTime;$ProcArgsTrunc^"`
    	ProcSnap="$ProcSnap$ProcLine"
done

if [ "$ProcSnap" = "" ]
then
	#Unable to collect metrics
	exit 8 
else 
	echo "$TS|$INFO_UUID|$ProcSnap?$swap;$mem?$cpu?$load?$queuelength;$procsblocked;$uptime"
fi

rm -f $TEMPDIR/snapout
