
flutter build linux
status=$?
if test $status -eq 0
then
    echo "Build Success"
    cd ~/flutter/apps/data_repo
    pwd

    if [ -d data ]; then
        echo "Remove 'data' directory"
        rm -rf data
    fi

    echo "Copy 'data' directory"
    cp -r ~/StudioProjects/data_repo/build/linux/x64/release/bundle/data .

    if [ -d lib ]; then
        echo "Remove 'lib' directory"
        rm -rf lib
    fi

    echo "Copy 'lib' directory"
    cp -r ~/StudioProjects/data_repo/build/linux/x64/release/bundle/lib .

    if [ -f data_repo ]; then
        echo "Remove 'data_repo' file"
        rm data_repo
    fi

    echo "Copy 'data_repo' file"
    cp ~/StudioProjects/data_repo/build/linux/x64/release/bundle/data_repo .

    ls -lta
fi
exit $status

