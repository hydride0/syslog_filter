#!/usr/bin/env bash

if [ "$#" -ne 1 ]; then
    echo "Usage: ./run.sh <image identifier>"
    exit 1
fi

docker run -it -v $(pwd)/output:/var/lib/syslog-ng/output -v $(pwd)/cert.d:/var/lib/syslog-ng/cert.d:ro -v $(pwd)/ca.d:/var/lib/syslog-ng/ca.d:ro -p 6514:6514 $1 bash
