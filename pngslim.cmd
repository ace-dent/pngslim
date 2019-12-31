@echo off & setlocal enableextensions

:: pngslim 
:: v1.1 (01-Jan-2020)
:: By Andrew C.E. Dent, dedicated to the Public Domain.

set Huff_Trials=15
set Rand_Trials=100
set LargeFileSize=66400

set VersionText=(v1.1)

echo Started batch %date% %time% - pngslim %VersionText%.
echo.

:: Check programs are available for the script
set PngDir="%~dp0apps\"
PATH %PngDir%;%PATH% >nul
if not exist %PngDir%advdef.exe echo File 1 missing! & goto theend
if not exist %PngDir%deflopt.exe echo File 2 missing! & goto theend
if not exist %PngDir%optipng.exe echo File 3 missing! & goto theend
if not exist %PngDir%pngoptimizercl.exe echo File 4 missing! & goto theend
if not exist %PngDir%pngout.exe echo File 5 missing! & goto theend
if not exist %PngDir%pngrewrite.exe echo File 6 missing! & goto theend
if not exist %PngDir%zlib.dll echo File 7 missing! & goto theend
:: Check some png files have been provided
if .%1==. (
	echo Drag-and-drop a selection of PNG files to optimize them.
	goto theend
)
set v=0
set zs=0
set zx=0
set TotalBytes=0
for %%i in (%*) do set /a TotalFiles+=1


:start
	set /a PngNum+=1
	if /I %~x1 NEQ .png goto nextfile
	title [%PngNum%/%TotalFiles%] pngslim %VersionText%
	echo %~z1b - Optimizing: %1
	set z0=%~z1
	copy %1 %1.backup >nul

:stage10
	pngout -q -s4 -f0 -c6 -k0 -force %1
	if errorlevel 1 echo Cannot compress: Unsupported PNG format. & goto stage99

	if %v%==1 echo %~z1b - T0S1: Written uncompressed file with stripped metadata.
	set LargeFile=0
	if %~z1 GTR %LargeFileSize% set LargeFile=1
	set /a Huff_MaxBlocks=%~z1/256
	if %Huff_MaxBlocks% GTR 512 set Huff_MaxBlocks=512
	if %v%==1 echo %~z1b - T0S2: File metrics: Max Huff blocks %Huff_MaxBlocks%, Large file: %LargeFile%.

	pngoptimizercl -file:%1 >nul
	pngrewrite %1 %1
	start /belownormal /b /wait pngout.exe -q -k1 -ks -s1 %1
	echo %~z1b - Lossy stage complete (optimized metadata, palette and transparency).



::
:: Trial (1) - Determine optimum color type and delta filter.
::

echo %~z1b - Compression trial 1 running (Color and filter settings)...
set ImgColr="Unknown"

:T1_Step1_Gray
	pngout -q -s4 -c0 -d8 %1
	if ERRORLEVEL 3 goto T1_Step1_GrayA
	set ImgColr="Gray"
	if %LargeFile%==0 (
		for %%i in (1,2) do for /L %%j in (0,1,5) do pngout -q -k1 -s0 -n%%i -f%%j -c0 -d1 %1
		for %%i in (1,2) do for /L %%j in (0,1,5) do pngout -q -k1 -s0 -n%%i -f%%j -c0 -d2 %1
		for %%i in (1,2) do for /L %%j in (0,1,5) do pngout -q -k1 -s0 -n%%i -f%%j -c0 -d4 %1
		for %%i in (1,2) do for /L %%j in (0,1,5) do pngout -q -k1 -s0 -n%%i -f%%j -c0 -d8 %1
	)
	if %LargeFile%==1 (
		for %%i in (0,256) do for %%j in (0,5) do pngout -q -k1 -s1 -b%%i -f%%j -c0 -d1 %1
		for %%i in (0,256) do for %%j in (0,5) do pngout -q -k1 -s1 -b%%i -f%%j -c0 -d2 %1
		for %%i in (0,256) do for %%j in (0,5) do pngout -q -k1 -s1 -b%%i -f%%j -c0 -d4 %1
		for %%i in (0,256) do for %%j in (0,5) do pngout -q -k1 -s1 -b%%i -f%%j -c0 -d8 %1
	)
	if %v%==1 echo %~z1b - T1S1: Tested color setting -c0 (Gray).


:T1_Step1_GrayA
	pngout -q -s4 -c4 %1
	if ERRORLEVEL 3 goto T1_Step1_Pal
	set ImgColr="Gray"
	if %LargeFile%==0 for %%i in (1,2) do for /L %%j in (0,1,5) do pngout -q -k1 -s0 -n%%i -f%%j -c4 %1
	if %LargeFile%==1 for %%i in (0,256) do for %%j in (0,5) do pngout -q -k1 -s1 -b%%i -f%%j -c4 %1
	if %v%==1 echo %~z1b - T1S1: Tested color setting -c4 (Gray+Alpha).


:T1_Step1_Pal
	pngout -q -s4 -c3 -d8 %1
	if ERRORLEVEL 3 goto T1_Step1_RGB
	if %LargeFile%==0 (
		for %%i in (1,2) do for /L %%j in (0,1,5) do pngout -q -k1 -s0 -n%%i -f%%j -c3 -d1 %1
		for %%i in (1,2) do for /L %%j in (0,1,5) do pngout -q -k1 -s0 -n%%i -f%%j -c3 -d2 %1
		for %%i in (1,2) do for /L %%j in (0,1,5) do pngout -q -k1 -s0 -n%%i -f%%j -c3 -d4 %1
		for %%i in (1,2) do for /L %%j in (0,1,5) do pngout -q -k1 -s0 -n%%i -f%%j -c3 -d8 %1
	)
	if %LargeFile%==1 (
		for %%i in (0,256) do for %%j in (0,5) do pngout -q -k1 -s1 -b%%i -f%%j -c3 -d1 %1
		for %%i in (0,256) do for %%j in (0,5) do pngout -q -k1 -s1 -b%%i -f%%j -c3 -d2 %1
		for %%i in (0,256) do for %%j in (0,5) do pngout -q -k1 -s1 -b%%i -f%%j -c3 -d4 %1
		for %%i in (0,256) do for %%j in (0,5) do pngout -q -k1 -s1 -b%%i -f%%j -c3 -d8 %1
	)
	if %v%==1 echo %~z1b - T1S1: Tested color setting -c3 (Paletted).


:T1_Step1_RGB
	if %ImgColr%=="Gray" goto T1_Step2
	pngout -q -s4 -c2 %1
	if ERRORLEVEL 3 goto T1_Step1_RGBA
	if %LargeFile%==0 for %%i in (1,2) do for /L %%j in (0,1,5) do pngout -q -k1 -s0 -n%%i -f%%j -c2 %1
	if %LargeFile%==1 for %%i in (0,256) do for %%j in (0,5) do pngout -q -k1 -s1 -b%%i -f%%j -c2 %1
	if %v%==1 echo %~z1b - T1S1: Tested color setting -c2 (RGB).


:T1_Step1_RGBA
	if %LargeFile%==0 for %%i in (1,2) do for /L %%j in (0,1,5) do pngout -q -k1 -s0 -n%%i -f%%j -c6 %1
	if %LargeFile%==1 for %%i in (0,256) do for %%j in (0,5) do pngout -q -k1 -s1 -b%%i -f%%j -c6 %1
	if %v%==1 echo %~z1b - T1S1: Tested color setting -c6 (RGB+Alpha).


:T1_Step2
	if %v%==1 echo %~z1b - T1S2: Testing Delta filters for chosen color type...
	if %LargeFile%==0 (
		for %%i in (0,3) do for /L %%j in (0,1,5) do pngout -q -k1 -ks -s%%i -b256 -f%%j %1
		optipng -q -nb -nc -zc1-9 -zm8-9 -zs0-3 -f0-5 %1
		optipng -q -zc1-9 -zm8-9 -zs0-3 -f0-5 %1
	)
	if %LargeFile%==1 (
		for %%i in (0,256) do for /L %%j in (1,1,4) do pngout -q -k1 -ks -s1 -b%%i -f%%j %1
		for %%i in (128) do for /L %%j in (0,1,5) do pngout -q -k1 -ks -s1 -b%%i -f%%j %1
		start /belownormal /b /wait pngout -q -k1 -ks -s0 -n1 %1
		optipng -q -nb -nc -zc9 -zm8 -zs0-3 -f0-5 %1
		optipng -q -zc9 -zm8 -zs0-3 -f0-5 %1
	)

:T1_End
	echo %~z1b - Compression trial 1 complete (Color and filter type).



::
:: Trial (2) - Determine optimum number of Huffman blocks and Deflate strategy with PNGOUT
::

echo %~z1b - Compression trial 2 running (Deflate settings)...
set Huff_Blocks=1
set Huff_Best=1
set Huff_Count=0
set Huff_Base=%~z1
if %v%==1 echo %~z1b - T2S1: Seeking optimum number of Huffman blocks...

:T2_Step1_Loop
	set /a Huff_Blocks+=1
	start /belownormal /b /wait pngout -q -k1 -ks -s3 -n%Huff_Blocks% %1
	pngout -q -k1 -ks -s0 -n%Huff_Blocks% %1
	if ERRORLEVEL 2 set /a Huff_Count+=1
	if %~z1 LSS %Huff_Base% (
		set Huff_Count=0
		set Huff_Base=%~z1
		set Huff_Best=%Huff_Blocks%
	)
	if %v%==1 echo %~z1b - T2S1: Best %Huff_Base%b with %Huff_Best% blocks. Tested %Huff_Blocks%, Count %Huff_Count%.
	if %Huff_Blocks% GEQ %Huff_MaxBlocks% goto T2_Step2
	if %Huff_Count% GEQ %Huff_Trials% goto T2_Step2
	goto T2_Step1_Loop

:T2_Step2
	if %v%==1 echo %~z1b - T2S2: Test different settings to ensure best number of blocks
	set /a Huff_Blocks=%Huff_Best%-1
	set Huff_Count=1
	if %Huff_Best% LEQ 1 (
		set Huff_Blocks=1
		set Huff_Count=2
	)

:: Testing different Deflate strategies and random Huffman tables for optimal number of blocks
:T2_Step2_Loop
	for /L %%i in (1,1,10) do for %%j in (0,2,3) do pngout -q -k1 -ks -s%%j -n%Huff_Blocks% -r %1
	if %v%==1 echo %~z1b - T2S2: Tested %Huff_Blocks% block(s) with Deflate strategies 0,2,3.
	set /a Huff_Blocks+=1 & set /a Huff_Count+=1
	if %Huff_Count% GTR 3 goto T2_End
	goto T2_Step2_Loop

:T2_End
	echo %~z1b - Compression trial 2 complete (Huffman blocks and Deflate strategy).



::
:: Trial (3) - Test randomized Huffman tables
::

:T3_Step1_Loop
	set zs=%~z1
	echo %~z1b - Compression trial 3 running (%Rand_Trials%x random Huffman tables)...
	for /L %%i in (1,1,%Rand_Trials%) do start /belownormal /b /wait pngout -q -k1 -ks -s0 -r %1
	if %~z1 LSS %zs% goto T3_Step1_Loop
	echo %~z1b - Compression trial 3 complete (Randomized Huffman tables).

::
:: Trial (4) - Final compression sweep
::

for %%i in (32k,16k,8k,4k,2k,1k,512,256) do optipng -q -nb -nc -zw%%i -zc1-9 -zm1-9 -zs0-3 -f0-5 %1
for /L %%i in (1,1,4) do advdef -q -z%%i %1
deflopt -s -k %1 >nul
echo %~z1b - Final compression sweep finished.


:stage99
	:: if %~z1 GTR %z0% copy %1 %1._fail >nul
	if %~z1 GEQ %z0% (
		del %1
		rename "%~1.backup" "%~nx1"
		echo Original file restored; could not compress further.
	)
	set /a zs=%z0%-%~z1
	set /a zx=(%zs%*100)/%z0%
	set /a TotalBytes+=%zs%
	if %~z1 LSS %z0% (
		del %1.backup
		echo Optimized: "%~n1". Slimmed %zx%%%, %zs% bytes.
	)

:nextfile
	echo.
	shift
	if .%1==. goto close
	goto start

:close
	title Optimization complete.
	echo.
	echo Finished %date% %time% - pngslim %VersionText%.
	echo Processed %TotalFiles% files. Slimmed %TotalBytes% bytes.

:theend
	endlocal
	pause
	title %ComSpec%