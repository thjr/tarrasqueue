#!/usr/local/bin/bash

FIFO_LOCATION=/tmp/
TIMEOUT=5

# Print usage
[[ $# -lt 1 ]] && echo Usage: $0 Queue parameter [parameter] && exit

QUEUE=$1
PARAMETER=$2

# read config
. /etc/tq.conf

PARALLEL_VARIABLE=queue_$1_parallel
CONSUMER_VARIABLE=queue_$1_consumer

CONSUMER_TEMPLATE="${!CONSUMER_VARIABLE}"
PARALLEL=${!PARALLEL_VARIABLE}

[[ ! $CONSUMER_TEMPLATE ]] && echo Queue $QUEUE not configured

if [ "$PARAMETER" ]; then
	CONSUMER=${CONSUMER_TEMPLATE/\%s/$PARAMETER}
else
	CONSUMER=$CONSUMER_TEMPLATE
fi

FIFO_FILE=$FIFO_LOCATION$QUEUE.fifo
CONSUMER_COUNT=`ps -auxww|grep "$0"|grep -e "${QUEUE} d" -e "${QUEUE} c"|wc -l`

main() {
	create_fifo_file

	if [ "$PARAMETER" == "" ] || [ "$PARAMETER" == "consume" ]; then
		consumer false
	elif [ "$PARAMETER" = "debug" ]; then
		consumer true
	else
		      	# start consumer if needed
			if [ "$CONSUMER_COUNT" -lt "$PARALLEL" ]; then
#				echo starting new consumer
				eval "$0 $QUEUE consume" &
			fi

		      	# add command to the queue
#			echo Sending "${CONSUMER}" to queue
		      	echo "$CONSUMER" > $FIFO_FILE

	fi
}

create_fifo_file() {
	# Create the FIFO file if missing

	[[ -e "$FIFO_FILE" ]] || mkfifo "$FIFO_FILE"
}

consume_fifo() {
      	while read -u 3 -t $TIMEOUT line; do
#		echo running "${line}"

		if [ $DEBUG == '1' ]; then
			(eval "${line}")&
		else 
        		(eval "${line}")&>/tmp/$QUEUE.log
		fi
      	done
}

consumer(){
      	# Associate file descriptor 3 to the FIFO
      	exec 3<"$FIFO_FILE"

	if [ $1 == 'true' ]; then
		DEBUG=1
	else
		DEBUG=0
	fi

	if [ $DEBUG == '1' ]; then
		while sleep 1; do consume_fifo; done
	else
		consume_fifo
	fi
}

main

