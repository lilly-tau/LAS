#!/usr/bin/env bash

TEST=false
DEBUG=false
while getopts "dqt" OPT; do
	case $OPT in
	t) TEST=true;;
	d) DEBUG=true;;
	q)
		set -x;;
	esac
done

if [[ ! -d "build" ]]; then
	mkdir -p build || exit 1
fi

fasm2 src/main.asm build/las || exit 1

if [[ "$TEST" = true ]]; then
	FINPUT=true
	INPUT="test.las"
	if [[ $FINPUT = true ]]; then
		cat "$INPUT" > /tmp/finput
	else
		printf "$INPUT" > /tmp/finput
	fi
	if [[ "$DEBUG" = true ]]; then
		gdb -ex "set args < /tmp/finput > build/output" build/las
	else
		build/las < /tmp/finput > build/output
	fi
	rm /tmp/finput
fi

set +x
