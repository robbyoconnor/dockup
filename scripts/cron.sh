#!/bin/bash

: ${CRON_HOURLY:="0 */1 * * *"}
: ${CRON_DAILY:="15 4 * * *"}
: ${CRON_WEEKLY:="30 3 * * 1"}
: ${CRON_MONTHLY:="45 2 1 * *"}
LOGFIFO='/dockup/cron.fifo'

if [[ ! -e "$LOGFIFO" ]]; then
    mkfifo "$LOGFIFO"
fi
env | grep -v 'affinity:container' | sed -e 's/^\([^=]*\)=\(.*\)/export \1="\2"/' > /dockup/env.conf # Save current environment

if [[ "$CRON_INTERVALS" = "true" ]]; then
  echo "${CRON_HOURLY} cd /dockup && . ./env.conf && ./backup.sh hourly >> $LOGFIFO 2>&1" > crontab.conf
  echo "${CRON_DAILY} cd /dockup && . ./env.conf && ./backup.sh daily >> $LOGFIFO 2>&1" >> crontab.conf
  echo "${CRON_WEEKLY} cd /dockup && . ./env.conf && ./backup.sh weekly >> $LOGFIFO 2>&1" >> crontab.conf
  echo "${CRON_MONTHLY} cd /dockup && . ./env.conf && ./backup.sh monthly >> $LOGFIFO 2>&1" >> crontab.conf
  echo "=> Running dockup interval backups as a cronjob"
elif [ -n "$CRON_TIME" ]; then
  echo "${CRON_TIME} cd /dockup && . ./env.conf && ./backup.sh >> $LOGFIFO 2>&1" > crontab.conf
  echo "=> Running dockup backups as a cronjob for ${CRON_TIME}"
fi

crontab ./crontab.conf
cron
tail -n +0 -f "$LOGFIFO"
