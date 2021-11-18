#! /bin/bash
USER=$1
PASS=$2

PASS_DECODED=$(echo "$PASS" | base64 -d)

usermod --password $(echo $PASS_DECODED | openssl passwd -1 -stdin) $USER