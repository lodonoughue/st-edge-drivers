#!/bin/bash
pushd $(dirname "${BASH_SOURCE[0]}") > /dev/null
trap 'popd > /dev/null' EXIT

export $(cat ../.env | xargs) && smartthings edge:channels:update $CHANNEL_ID -i ../channels/lodonoughue-drivers.json
