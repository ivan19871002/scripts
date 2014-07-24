#!/bin/bash

AVAIL=`df -h | grep /home | awk '{print $4}'`
TOTAL=`df -h | grep /home | awk '{print $2}'`

echo $AVAIL/$TOTAL
