#!/bin/bash
pushd $(dirname "${BASH_SOURCE[0]}") > /dev/null
trap 'popd > /dev/null' EXIT

smartthings edge:channels:update "94d9169e-c2da-428e-8521-7822e2bf78f3" -i ../channels/lodonoughue-drivers.json
