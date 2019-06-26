#!/usr/local/bin/bash

FIFO_LOCATION=/tmp/
TIMEOUT=5

# Print usage
[[ $# -lt 1 ]] && echo Usage: $0 [queue_name] [parameter] [parameter2] OR $0 --COMMAND [parameter] && exit

COMMAND=$0
QUEUE=$1
PARAMETER=$2
PARAMETER2=$3

# read config
. /etc/tq.conf

configure() {
	PARALLEL_VARIABLE="queue_${QUEUE}_parallel"
	CONSUMER_VARIABLE="queue_${QUEUE}_consumer"

	CONSUMER_TEMPLATE="${!CONSUMER_VARIABLE}"
	PARALLEL=${!PARALLEL_VARIABLE}

	[[ ! $CONSUMER_TEMPLATE ]] && echo Queue $QUEUE not configured && exit -1

	CONSUMER=$CONSUMER_TEMPLATE
	if [ "$PARAMETER" ]; then
		CONSUMER=${CONSUMER/\%s/$PARAMETER}
	fi

	if [ "$PARAMETER2" ]; then
		CONSUMER=${CONSUMER/\%s/$PARAMETER2}
	fi

	FIFO_FILE=$FIFO_LOCATION$QUEUE.fifo
	CONSUMER_COUNT=`ps -auxww|grep "${COMMAND}"|grep -e "${QUEUE} d" -e "${QUEUE} c"|wc -l`
}

main() {
	isCommand

	if [ $? == 1 ]; then
		runCommand
		return
	fi

	configure
	create_fifo_file

	if [ "${PARAMETER}" == "" ] || [ "${PARAMETER}" == "consume" ]; then
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

isCommand() {
	if [[ $QUEUE == --* ]]; then 
		return 1
	else 
		return 0
	fi
}

printQueues() {
	for var in ${!queue_@}; do
		if [[ $var == *_consumer ]]; then
			tmp=${var#*_}
			echo ${tmp%_*}
		fi
	done
}

runCommand() {
	if [ $QUEUE == '--queues' ]; then
		printQueues
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

consumer() {
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

