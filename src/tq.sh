#!/usr/local/bin/bash

# Print usage
[[ $# -lt 1 ]] && echo Usage: $0 [queue_name] [parameter] [parameter2] OR $0 --COMMAND [parameter] && exit

QUEUE=$1
PARAMETER=$2
PARAMETER2=$3

# create directories
QUEUE_BASE_DIRECTORY=/tmp/tq/${QUEUE}
QUEUE_DIRECTORY=${QUEUE_BASE_DIRECTORY}/queue
CONSUMER_DIRECTORY=${QUEUE_BASE_DIRECTORY}/consumers
mkdir -p $CONSUMER_DIRECTORY
mkdir -p $QUEUE_DIRECTORY

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

  CONSUMER_COUNT="$(get_consumer_count)"

#  echo "consumer count" $CONSUMER_COUNT $CONSUMER_COUNT2
}

get_consumer_count() {
  echo `ls -1 ${CONSUMER_DIRECTORY}| wc -l`
}

delete_old_logs() {
  find ${QUEUE_BASE_DIRECTORY}/*.log -mtime +7 -exec rm {} \; 2>/dev/null
}

main() {
  configure
  delete_old_logs

  add_to_queue "$CONSUMER"
    # start consumer if needed
#    echo consumer count $CONSUMER_COUNT max $PARALLEL

  if [ "$CONSUMER_COUNT" -lt "$PARALLEL" ]; then
    start_new_consumer $QUEUE &
  fi
}

add_to_queue() {
  echo "$1" > ${QUEUE_DIRECTORY}/$$
}

get_first_file() {
  for filename in ${QUEUE_DIRECTORY}/*; do
    [ -e "$filename" ] || continue

    echo $filename

    break
  done
}

consume_queue() {
  for (( ; ; ))
  do
    filename="$(get_first_file)"
    [ -e "$filename" ] || break

    read -r line<$filename

    rm $filename

    if [ $DEBUG == '1' ]; then
      eval "${line}"
    else
      eval "${line}" >>${QUEUE_BASE_DIRECTORY}/$$.log 2>&1
    fi
  done

#  echo "consumer done!"
}

start_new_consumer() {
  # save pidfile
  PIDFILE=${CONSUMER_DIRECTORY}/$$
  echo $QUEUE >> ${PIDFILE}

  if [ $1 == 'true' ]; then
    DEBUG=1
  else
    DEBUG=0
  fi

  if [ $DEBUG == '1' ]; then
    while sleep 1; do consume_queue; done
  else
    consume_queue
  fi

  # remove pidfile
  rm ${PIDFILE}
}

main