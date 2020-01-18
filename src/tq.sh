#!/usr/local/bin/bash

FIFO_LOCATION=/tmp/
TIMEOUT=5

# Print usage
[[ $# -lt 1 ]] && echo Usage: $0 [queue_name] [parameter] [parameter2] OR $0 --COMMAND [parameter] && exit

COMMAND=$0
QUEUE=$1
PARAMETER=$2
PARAMETER2=$3

# create directories
QUEUE_DIRECTORY=/tmp/tq/${QUEUE}
CONSUMER_DIRECTORY=${QUEUE_DIRECTORY}/consumers
mkdir -p $CONSUMER_DIRECTORY

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

  FIFO_FILE=${FIFO_LOCATION}${QUEUE}.fifo

  CONSUMER_COUNT=$((`ps -auxww|grep "tq-consume"|grep -e "${QUEUE}"|wc -l` ))

#	echo "consumer count" $CONSUMER_COUNT
}

main() {
  configure
  create_fifo_file

  if [[ $COMMAND == *tq-consume* ]]; then
    consumer false
  elif [[ $COMMAND == *tq-debug* ]]; then
    consumer true
  else
    # start consumer if needed
#    echo consumer count $CONSUMER_COUNT max $PARALLEL

    if [ "$CONSUMER_COUNT" -lt "$PARALLEL" ]; then
      start_new_consumer $QUEUE
    fi

    add_to_queue "$CONSUMER" $FIFO_FILE
  fi
}

start_new_consumer() {
#  echo starting new consumer for $1
  eval "tq-consume $1" &>>/tmp/$QUEUE.log & disown
}

add_to_queue() {
# echo Sending "$1" to queue "$2"
  echo "$1" > $2
}

create_fifo_file() {
	# Create the FIFO file if missing

  [[ -e "$FIFO_FILE" ]] || mkfifo "$FIFO_FILE"
}

consume_fifo() {
#  echo "start consuming fifo with timeout " $TIMEOUT

  while read -u 3 -t $TIMEOUT line; do
#    echo running "${line}"

    if [ $DEBUG == '1' ]; then
      eval "${line}"
    else
      eval "${line}" >>${QUEUE_DIRECTORY}/$$.log
    fi
  done

#  echo "consumer done!"
}

consumer() {
#  echo "running consumer process for " $FIFO_FILE

  # save pidfile
  CONSUMER_PID=$$
  echo $QUEUE >> ${CONSUMER_DIRECTORY}/${CONSUMER_PID}

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

  # remove pidfile
  rm ${CONSUMER_DIRECTORY}/${CONSUMER_PID}
}

main