#!/bin/bash

grep "XK_" /usr/include/X11/keysymdef.h|sed 's/ XK_/ /g'

grep "XK_" /usr/include/X11/XF86keysym.h|sed 's/XK_//g'
