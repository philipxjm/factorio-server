@ECHO OFF

SET DXCOMPILER="c:\Program Files (x86)\Windows Kits\8.1\bin\x64\fxc.exe"
SET OUTPUT_PATH=
SET FLAGS=/O3

rem CALL :BUILD_VERTEX_SHADER NightVision.hlsl VSMain
CALL :BUILD_PIXEL_SHADER  game.psh ps_main
CALL :BUILD_PIXEL_SHADER  zoom-to-world.psh ps_main
CALL :BUILD_PIXEL_SHADER  alpha-mask.psh ps_main
pause
EXIT /B 0

:BUILD_VERTEX_SHADER
CALL %DXCOMPILER% %FLAGS% /Tvs_2_0 /E %2 /Fo %OUTPUT_PATH%%2.%~n1.cso %1
EXIT /B 0

:BUILD_PIXEL_SHADER
CALL %DXCOMPILER% %FLAGS% /Tps_2_a /E %2 /Fo %OUTPUT_PATH%%~n1.cso %1
EXIT /B 0

