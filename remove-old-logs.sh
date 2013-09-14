#!/bin/bash

files=$(find /home/gmillz/logs -type f | wc -l)

if [ "$files" > 20 ]
then
  a=$(( $files - "20" ))
  ls -t | tail -n $a | sort | xargs rm
fi