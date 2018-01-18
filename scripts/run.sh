#!/bin/bash

if [[ "$RESTORE" == "true" ]]; then
  ./restore.sh
else
  if [[ "$CRON_INTERVALS" == "true" ]] || [ -n "$CRON_TIME" ]; then
    ./cron.sh
  else
    ./backup.sh
  fi
fi
