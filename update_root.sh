#!/bin/bash -e
set -x
cd $1
rm -f etc/hostname
rm -f etc/salt/minion_id
rm -rf etc/salt/pki/*
