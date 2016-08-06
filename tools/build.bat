@ECHO OFF
REM This file is a part of PasDev project
REM https://github.com/adm244/pasdev

SETLOCAL
REM [customize those variables]
SET buildfiles="..\code\%prjname%.pas"

SET debug=-Ci -Co -Cr
SET release=-O3 -Si -Xs -XS -WC
SET buildargs=%release% -FE"%~dp0..\bin" %buildfiles%
REM ###########################

SET edit=edit
SET setprjname=setname

IF [%1]==[%edit%] GOTO EditBuildFile
IF [%1]==[%setprjname%] GOTO SetProjectName
IF [%1]==[] GOTO Build
GOTO Error

:Build
ECHO: Build started...

IF NOT EXIST "%~dp0..\bin" MKDIR "%~dp0..\bin"
"%compiler%" %buildargs%

ECHO: Build finished.
GOTO:EOF

:EditBuildFile
START "" "%editor%" "%editorargs%" "%~dp0%~n0.bat"
GOTO:EOF

:SetProjectName
IF [%2]==[] ECHO: ERROR: Name for a project was NOT specified! && GOTO:EOF

ECHO: Changing project name to %2...
ENDLOCAL
SET prjname=%2
ECHO: Done!
GOTO:EOF

:Error
ECHO: ERROR: wrong arguments passed!
GOTO:EOF
