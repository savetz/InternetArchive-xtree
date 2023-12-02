#!/bin/sh
if [ "$1" ]
   then
   ./xtree.sh -html "$1" > tempfile.$$
   ./xtree2html.py < tempfile.$$ > "$1".html
   rm -f tempfile.$$
else
   echo "Usage: $0 collection-identifier"
fi