if [ -z "$HOME" ]
then
    echo HOME not in environment, guessing...
    export HOME=$(awk -F: -v v="$USER" '{if ($1==v) print $6}' /etc/passwd)
fi

git clone git://github.com/gmillz/scripts.git

export PATH=${PATH}:~/scripts:~/bin

cd scripts
chmod a+x ./build.sh
exec ./build.sh
