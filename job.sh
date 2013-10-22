if [ -z "$HOME" ]
then
    echo HOME not in environment, guessing...
    export HOME=$(awk -F: -v v="$USER" '{if ($1==v) print $6}' /etc/passwd)
fi

cd $WORKSPACE
mkdir -p ../slim-build
cd ../slim-build
export WORKSPACE="$PWD"

rm -rf scripts
git clone git://github.com/gmillz/scripts.git

export PATH=${PATH}:$WORKSPACE/scripts:~/bin

cd scripts
chmod a+x ./build.sh
exec ./build.sh
