#!/bin/bash

# A full-featured shell (not `busybox` in case of Alpine or alike) is needed
# for proper signal handling`bash`

set -e

function stop() {
	echo
 	echo "** Stopping UPS daemon ***********"
	echo
	upsd -c stop

	echo
	echo "** Stopping UPS drivers **********"
	echo
	upsdrvctl stop
}

function start() {
	echo
	echo "** Starting UPS drivers **********"
	echo
	upsdrvctl start

	echo
	echo "** Starting UPS daemon ***********"
	echo
	upsd -FF
}

# Ensure UPS drivers are correctly stopped on exit, otherwise some hardware
# could be left in an invalid state (e.g. UPS models with a cheap USB-serial
# adapters)
trap stop EXIT INT HUP

start
