#!/bin/sh

#SYMBOL=$1
SYMBOL="_ptrace"
#PATH=$2
LIBRARY="Scuttlegobot.framework/Versions/A/Scuttlegobot"

PATH=${SOURCE_ROOT}/${LIBRARY}
echo $PATH

RESULT=`/usr/bin/nm ${PATH} | /usr/bin/grep ${SYMBOL}`
echo $RESULT

if [ -n "$RESULT" ]; then
    echo "error: ILLEGAL SYMBOL '${SYMBOL}' FOUND"
    exit 1
fi

