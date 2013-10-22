if [ -z "$HOME" ]
then
    echo HOME not in environment, guessing...
    export HOME=$(awk -F: -v v="$USER" '{if ($1==v) print $6}' /etc/passwd)
fi

if [ ! -d "scripts" ]
then
    git clone git://github.com/gmillz/scripts.git
fi

export PATH=${PATH}:~/scripts:~/bin

cd hudson
exec ./build.sh