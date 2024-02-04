#!/bin/bash

export xxx="final DateTime buildDateExt = DateTime.fromMillisecondsSinceEpoch($(date "+%s000"));"
echo "$xxx" > lib/build_date.dart
export yyy="const String buildPathExt = '$(pwd)';"
echo "$yyy" >> lib/build_date.dart

echo "Build date created:"
cat lib/build_date.dart

echo "Build: Linux Release"

flutter build linux --release
status=$?

if test $status -eq 0
then
    echo "Build Success"
    
    export localDir=$(dirname "$0")/linux/flutter/ephemeral/linux/x64/release/bundle
    echo "Build Path: $localDir"
    if [ ! -d $localDir ]; then
        echo "Build Path not found:$localDir"
        export localDir=$(dirname "$0")/build/linux/x64/release/bundle
        if [ ! -d $localDir ]; then
            echo "Build Path not found:$localDir"
            exit 1
        fi
    fi

    cd $localDir
    export localDir=$(pwd)
    echo "Full localDir: $localDir"

    export outDir=~/development/apps/data_repo
    if [ ! -d $outDir ]; then
      export outDir=~/flutter/apps/data_repo
      if [ ! -d $outDir ]; then
          echo "Output path not found:$outDir"
          exit 1
      fi
    fi
    cd $outDir
    export outDir=$(pwd)
    echo "Full outDir: $outDir"


    if [ -d data ]; then
        echo "Remove 'data' directory"
        rm -rf data
    fi

    echo "Copy 'data' directory"
    cp -r $localDir/data .

    if [ -d lib ]; then
        echo "Remove 'lib' directory"
        rm -rf lib
    fi

    echo "Copy 'lib' directory"
    cp -r $localDir/lib .

    if [ -f data_repo ]; then
        echo "Remove 'data_repo' file"
        rm data_repo
    fi

    echo "Copy 'data_repo' file"
    cp $localDir/data_repo .

    ls -lta
fi
exit $status

