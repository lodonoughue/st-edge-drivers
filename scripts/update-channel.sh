#!/bin/bash
if [ "$1" = "" ]
then
  echo "Usage: $0 <channel configuration file>.yml"
  exit 1
fi

ROOT=$(dirname $0)/..
export $(cat ${ROOT}/.env | xargs)

smartthings edge:channels:update $CHANNEL_ID -i $1
