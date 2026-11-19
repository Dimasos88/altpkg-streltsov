#!/bin/sh
set -e
DIR=\
cd \
rm -rf /tmp/Show-1.0
mkdir -p /tmp/Show-1.0
cp Show.c Makefile /tmp/Show-1.0/
tar -czvf Show-1.0.tar.gz -C /tmp Show-1.0
echo 'Show-1.0.tar.gz created successfully'
