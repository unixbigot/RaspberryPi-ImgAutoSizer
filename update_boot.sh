#!/bin/bash -e
#set -x
cd $1
if grep init_resize cmdline.txt
then
   echo "No action"
else
   true
   #echo "Patching cmdline.txt"   
   #sed -ie '1s/$/ init=\/usr\/lib\/raspi-config\/init_resize.sh/' cmdline.txt
fi
touch ssh
