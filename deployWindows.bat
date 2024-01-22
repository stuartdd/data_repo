call flutter build windows --release

IF %ERRORLEVEL% NEQ 0 (
 echo "Build failed"
 exit 1
)

@ echo off
set TS=%date:~6,4%_%date:~3,2%_%date:~0,2%_T_%time:~0,2%_%time:~3,2%_%time:~6,2%
echo "**************************************************"
echo "Build OK at %TS%"
echo "**************************************************"

if exist ..\..\myapps\Release (
  rmdir ..\..\myapps\Release /s /q
  echo "Old Release dir removed"
  echo "**************************************************"
) 

if exist build\windows\x64\runner\Release (
  robocopy  build\windows\x64\runner\Release ..\..\myapps\Release /s /e /NFL /NDL /NJH /NJS /np
  IF %ERRORLEVEL% NEQ 0 (
    echo "Failed to copy build\windows\x64\runner\Release to Release"
    echo "--------------------------------------------------"
    exit 1
  )  
)
if exist ..\..\myapps\Release (
  echo "Release directory copied OK"
  echo "**************************************************"
) else (
  echo "Release directory was NOT copied"
  echo "--------------------------------------------------"
  exit 1
)


if exist ..\..\myapps\data_repo\data_repo_config.json (
  copy  ..\..\myapps\data_repo\data_repo_config.json ..\..\myapps\Release
) 
if exist ..\..\myapps\Release\data_repo_config.json (
  echo "Configuration file data_repo_config.json copied OK"
) else (
  echo "Configuration file data_repo_config.json NOT copied to Release"
)

if exist ..\..\myapps\data_repo\data_repo_appState.json (
  copy  ..\..\myapps\data_repo\data_repo_appState.json ..\..\myapps\Release
) 
if exist ..\..\myapps\Release\data_repo_appState.json (
  echo "Configuration file data_repo_appState.json copied OK"
) else (
  echo "Configuration file data_repo_appState.json NOT copied to Release"
)
echo "**************************************************"

if exist ..\..\myapps\data_repo (
  ren ..\..\myapps\data_repo "data_repo_%TS%"
  echo "data_repo backup [data_repo_%TS%] created"
) else (
  echo "data_repo does not exist"
)
echo "**************************************************"

ren ..\..\myapps\Release data_repo
if exist ..\..\myapps\data_repo (
  echo "data_repo created from release"
  echo "Deploy data_repo completed"
  echo "++++++++++++++++++++++++++++++++++++++++++++++++++"
) else (
  echo "ERROR: data_repo does not exist"
  echo "--------------------------------------------------"
)



