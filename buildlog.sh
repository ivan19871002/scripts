MYPATH=$(dirname $0)
rm $WORKSPACE/archive/CHANGES.txt 2>/dev/null

DATE=$(date +"%m-%d-%Y")
LAST=$(cat "$HOME/changedate")
if [ -z "$LAST" ]
then
    echo "First run"
fi

if [ "$DATE" != "$LAST" ]
then
    CHANGES=$(repo forall -c 'git log --oneline --no-merges --since $LAST')
fi
if [ -z "$CHANGES" ]
then
    echo "No changes since last build" > $WORKSPACE/archive/CHANGES.txt
else
    echo $CHANGES > $WORKSPACE/archive/CHANGES.txt
fi

echo "$DATE" >> $HOME/changedate
