#!/bin/bash
if [ "$1" = "" ]
then
  echo "Usage: $0 <driver>/"
  exit 1
fi

ROOT=$(dirname $0)/..
export $(cat ${ROOT}/.env | xargs)

smartthings edge:drivers:package $1 --channel $CHANNEL_ID --hub $HUB_ID
