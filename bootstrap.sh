#!/bin/bash

export LD_LIBRARY_PATH=/usr/local/lib
echo $LD_LIBRARY_PATH

$JBOSS_HOME/bin/standalone.sh -b 0.0.0.0 &

while : ; do
    sleep 10
    $ATLAS_HOME/install/bin/AssimpWorker --stomp-user $STOMP_USER --stomp-pass $STOMP_PASS
#    echo $?
#    [[ $? -eq 0 ]] || break
done

