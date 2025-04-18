@echo off & setlocal enableextensions


:: pngslim
::  - by Andrew C.E. Dent, dedicated to the Public Domain.
  set Version=(v1.2 pre-release)

  set ForceRGBA=0
  set ReduceDiskWrites=1

  :: Log verbose output: NUL (none) / CON (console display)
  set log="NUL"



  echo Started %date% %time% - "%~n0" %Version%.
  echo.

  :: Check programs are available for the script
  pushd "%~dp0apps\"
  if errorlevel 1 (
    echo Directory not found.
    goto TheEnd
  )

  for %%i in (
    advdef.exe
    deflopt.exe
    defluff.exe
    huffmix.exe
    optipng.exe
    pngcheck.exe
    pngout.exe
    pngrewrite.exe
  ) do (
    if not exist %%i (
      echo Program not found: %%i.
      goto TheEnd
    )
  )

  :: Check some files have been provided
  if "%~a1"=="" (
    echo Drag-and-drop a selection of PNG files to optimize.
    goto TheEnd
  )

  :: Global variables
  set LargeFileSize=66400
  set SessionID=%random%
  set TotalFiles=0
  set TotalBytesSaved=0
  set ErrorsLogged=0

  :: Count total files to process
  for %%i in (%*) do set /a TotalFiles+=1

  :: Check regional time separator for later benchmarking. Defaults to `:`
  set Key="HKCU\Control Panel\International"
  for /f "skip=2 tokens=3" %%a in ('reg.exe query %Key% /v sTime') do (
    set "TimeSeparator=%%a"
  )
  if not defined TimeSeparator set TimeSeparator=:



:SelectFile

  set /a CurrentFile+=1
  set Status=[%CurrentFile%/%TotalFiles%] pngslim %Version%
  title %Status%

  :: Basic file validation
  if /I "%~x1" NEQ ".png" (
    echo File skipped: "%~1" - invalid file type.
    goto NextFile
  )
  if %~z1 LSS 67 (
    echo File skipped: "%~1" - invalid file.
    goto NextFile
  )
  if %~z1 GTR 10485760 (
    echo Large file skipped: "%~1" - exceeds 10 MiB.
    goto NextFile
  )

  echo %~z1b - Optimizing: "%~1"

  :: Check PNG file for errors
  pngcheck.exe -q "%~1"
  if errorlevel 1 (
    pngcheck.exe -vvt "%~1" > "%~1.%SessionID%.error.log"
    set /a ErrorsLogged+=1
    echo Error detected: Skipped invalid file.
    goto NextFile
  )

  set FileSizeOriginal=%~z1

  copy /Z "%~1" "%~1.%SessionID%.backup" >nul
  fc.exe /B "%~1" "%~1.%SessionID%.backup" >nul
  if errorlevel 1 (
    set /a ErrorsLogged+=1
    echo System error: Backup file corrupted!
    goto Close
  )

  :: Benchmark start time
  set "WallClockStartDate=%date%"
  call set "t=%%time:%TimeSeparator%0=%TimeSeparator% %%"
  set WallClockUnits=seconds
  set /a WallClockStart=(%t:~0,2%*3600)+(%t:~3,2%*60)+%t:~6,2%



:PreprocessFile

  :: Losslessly reduce 16 to 8bit per channel, if possible
  optipng.exe -q -i0 -zc1 -zm8 -zs3 -f0 -force "%~1"

  :: Strip metadata and create an uncompressed, 32bpp RGBA baseline
  pngout.exe -q -k0 -s4 -f0 -c6 -force "%~1"
  if errorlevel 1 (
    echo Cannot compress: Unsupported PNG format.
    goto RestoreFile
  )
  >>%log% echo %~z1b - T0S1 Written uncompressed file with stripped metadata.

  :: File metrics
  set LargeFile=0
  if %~z1 GTR %LargeFileSize% set LargeFile=1
  set /a FileMaxHuffmanBlocks=%~z1/256
  if %FileMaxHuffmanBlocks% GTR 1024 set FileMaxHuffmanBlocks=1024
  >>%log% echo %~z1b - T0S2 Max Huffman blocks = %FileMaxHuffmanBlocks%. Large file = %LargeFile%.

  :: Image analysis
  set ImageColorMode="Undetermined"
  set ImageTransparencyMode="Undetermined"
  set ImageIsFullyOpaque="Undetermined"
  :: Try to re-encode the image with minimal colors for analysis
  pngrewrite.exe "%~1" "%~1.%SessionID%.temp.png" 2>nul
  :: If pngrewrite failed to create an indexed image (contains 256+ unique colors)
  ::   try an RGB which may have a simple, single transparent mask color.
  if not exist "%~1.%SessionID%.temp.png" (
    pngout.exe -q -c2 -s1 -force "%~1" "%~1.%SessionID%.temp.png"
    if errorlevel 3 set ImageIsFullyOpaque="No - contains transparency"
  )
  if exist "%~1.%SessionID%.temp.png" (
    pngcheck.exe -v "%~1.%SessionID%.temp.png" | findstr.exe /i "transparency alpha" >nul
    if errorlevel 1 (
      set ImageIsFullyOpaque="Yes"
    ) else (
      set ImageIsFullyOpaque="No - contains transparency"
    )
    del "%~1.%SessionID%.temp.png"
  )
  >>%log% echo %~z1b - T0S3 Opaque image: %ImageIsFullyOpaque:~1,-1%.

  :: Skip steps that modify color depth for Forced RGB/A images
  if %ForceRGBA% EQU 1 (
    echo %~z1b - Preprocessing complete ^(saved RGBA image, stripped metadata^).
    echo %~z1b - Compression trial 1 running ^(RGB/A Color and filter settings^)...
    goto T1_Step1_RGB
  )

  pngrewrite.exe "%~1" "%~1" 2>nul
  pngout.exe -q -k1 -ks -kp -f6 -s1 "%~1"
  echo %~z1b - Preprocessing complete (minimized metadata, palette and transparency).



::
:: Trial (1) - Determine optimum color type and delta filter.
::

  echo %~z1b - Compression trial 1 running (Color and filter settings)...

:T1_Step1_Gray
  pngout.exe -q -k1 -s4 -c0 -d8 "%~1"
  if errorlevel 3 goto T1_Step1_Gray+Alpha
  set ImageColorMode="Gray"
  set ImageTransparencyMode="Basic"
  for %%i in (1,2,4,8) do (
    if %LargeFile% EQU 0 (
      for %%j in (1,2) do (
        for /L %%k in (0,1,5) do (
          pngout.exe -q -k1 -s0 -d%%i -n%%j -f%%k -c0 "%~1"
        )
      )
    )
    if %LargeFile% EQU 1 (
      for %%j in (0,256) do (
        for %%k in (0,5) do (
          pngout.exe -q -k1 -s1 -d%%i -b%%j -f%%k -c0 "%~1"
        )
      )
    )
  )
  >>%log% echo %~z1b - T1S1 Tested color setting -c0 (Gray).


:T1_Step1_Gray+Alpha
  if %ImageIsFullyOpaque%=="Yes" (
    goto T1_Step1_Paletted
  )
  pngout.exe -q -k1 -s4 -c4 "%~1"
  if errorlevel 3 goto T1_Step1_Paletted
  set ImageColorMode="Gray"
  if %ImageTransparencyMode% NEQ "Basic" (
    set ImageTransparencyMode="Multiple"
  )
  if %LargeFile% EQU 0 (
    for %%i in (1,2) do (
      for /L %%j in (0,1,5) do (
        pngout.exe -q -k1 -s0 -n%%i -f%%j -c4 "%~1"
      )
    )
  )
  if %LargeFile% EQU 1 (
    for %%i in (0,256) do (
      for %%j in (0,5) do (
        pngout.exe -q -k1 -s1 -b%%i -f%%j -c4 "%~1"
      )
    )
  )
  >>%log% echo %~z1b - T1S1 Tested color setting -c4 (Gray+Alpha).


:T1_Step1_Paletted
  pngout.exe -q -k1 -s4 -c3 -d8 "%~1"
  if errorlevel 3 goto T1_Step1_RGB
  if %ImageColorMode% NEQ "Gray" (
    set ImageColorMode="Paletted"
  )
  for %%i in (1,2,4,8) do (
    if %LargeFile% EQU 0 (
      for %%j in (1,2) do (
        for /L %%k in (0,1,5) do (
          pngout.exe -q -k1 -s0 -d%%i -n%%j -f%%k -c3 "%~1"
        )
      )
    )
    if %LargeFile% EQU 1 (
      for %%j in (0,256) do (
        for %%k in (0,5) do (
          pngout.exe -q -k1 -s1 -d%%i -b%%j -f%%k -c3 "%~1"
        )
      )
    )
  )
  >>%log% echo %~z1b - T1S1 Tested color setting -c3 (Paletted).


:T1_Step1_RGB
  if %ForceRGBA% EQU 1 (
    if not %ImageIsFullyOpaque%=="Yes" (
      goto T1_Step1_RGBA
    )
  )
  if %ImageColorMode%=="Gray" goto T1_Step2
  pngout.exe -q -k1 -s4 -c2 "%~1"
  if errorlevel 3 goto T1_Step1_RGBA
  if %ImageColorMode% NEQ "Gray" (
    if %ImageColorMode% NEQ "Paletted" (
      set ImageColorMode="RGB"
    )
  )
  set ImageTransparencyMode="Basic"
  if %LargeFile% EQU 0 (
    for %%i in (1,2) do (
      for /L %%j in (0,1,5) do (
        pngout.exe -q -k1 -s0 -n%%i -f%%j -c2 "%~1"
      )
    )
  )
  if %LargeFile% EQU 1 (
    for %%i in (0,256) do (
      for %%j in (0,5) do (
        pngout.exe -q -k1 -s1 -b%%i -f%%j -c2 "%~1"
      )
    )
  )
  >>%log% echo %~z1b - T1S1 Tested color setting -c2 (RGB).


:T1_Step1_RGBA
  if %ImageIsFullyOpaque%=="Yes" (
    goto T1_Step2
  )
  if %ForceRGBA% NEQ 1 (
    if %ImageColorMode% NEQ "Gray" (
      if %ImageColorMode% NEQ "Paletted" (
        set ImageColorMode="RGB"
      )
    )
    if %ImageTransparencyMode% NEQ "Basic" (
      set ImageTransparencyMode="Multiple"
    )
  )
  if %LargeFile% EQU 0 (
    for %%i in (1,2) do (
      for /L %%j in (0,1,5) do (
        pngout.exe -q -k1 -s0 -n%%i -f%%j -c6 "%~1"
      )
    )
  )
  if %LargeFile% EQU 1 (
    for %%i in (0,256) do (
      for %%j in (0,5) do (
        pngout.exe -q -k1 -s1 -b%%i -f%%j -c6 "%~1"
      )
    )
  )
  >>%log% echo %~z1b - T1S1 Tested color setting -c6 (RGB+Alpha).


:T1_Step2
  >>%log% echo %~z1b - T1S2 Testing Delta filters for chosen color type...
  if %LargeFile% EQU 0 (
    for %%i in (0,3) do (
      for /L %%j in (0,1,5) do (
        pngout.exe -q -k1 -ks -kp -s%%i -b256 -f%%j "%~1"
      )
    )
    optipng.exe -q -nx -zc1-9 -zm8-9 -zs0-3 -f0-5 "%~1"
    if %ForceRGBA% NEQ 1 optipng.exe -q -zc1-9 -zm8-9 -zs0-3 -f0-5 "%~1"
  )
  if %LargeFile% EQU 1 (
    for %%i in (0,256) do (
      for /L %%j in (1,1,4) do (
        pngout.exe -q -k1 -ks -kp -s1 -b%%i -f%%j "%~1"
      )
    )
    for /L %%j in (0,1,5) do (
      pngout.exe -q -k1 -ks -kp -s1 -b128 -f%%j "%~1"
    )
    pngout.exe -q -k1 -ks -kp -f6 -s0 -n1 "%~1"
    optipng.exe -q -nx -zc9 -zm8 -zs0-3 -f0-5 "%~1"
    if %ForceRGBA% NEQ 1 optipng.exe -q -zc9 -zm8 -zs0-3 -f0-5 "%~1"
  )

:T1_End
  for /f "tokens=2 delims=c " %%i in ('pngout.exe -L "%~1"') do (
    set ImageColorMode=%%i
  )
  >>%log% echo %~z1b - T1S2 Optimum color mode: -c%ImageColorMode%.
  echo %~z1b - Compression trial 1 complete (Color and filter type).



::
:: Trial (2) - Determine optimum number of Huffman blocks and Deflate strategy with PNGOUT
::

  echo %~z1b - Compression trial 2 running (Deflate settings)...

  set BestBlocks="Undetermined"
  for /f "tokens=2 delims=n" %%i in ('pngout.exe -L "%~1"') do (
    set BestBlocks=%%i
  )
  >>%log% echo %~z1b - T2S0 Initial number of Huffman blocks: %BestBlocks%.


  :: Exit trial early for images where a single Huffman block is optimal
  if %BestBlocks% LSS 3 (
    pngout.exe -q -k1 -ks -kp -f6 -s0 -n3 "%~1"
    pngout.exe -q -k1 -ks -kp -f6 -s3 -n3 "%~1"
    for /f "tokens=2 delims=n" %%i in ('pngout.exe -L "%~1"') do (
      set BestBlocks=%%i
    )
  )
  if %BestBlocks% LEQ 1 (
    >>%log% echo %~z1b - T2S0 Single Huffman block is optimal.
    goto T2_Step2
  )


:: Step 1 - Coarse scan for optimal number of Huffman blocks
:T2_Step1
  >>%log% echo %~z1b - T2S1 Search for optimum number of Huffman blocks
  set BestSize=%~z1
  set TrialCounter=0
  set TrialBlocks=4

:T2_Step1_Loop
  pngout.exe -q -k1 -ks -kp -f6 -s0 -n%TrialBlocks% "%~1"
  pngout.exe -q -k1 -ks -kp -f6 -s3 -n%TrialBlocks% "%~1"

  if %~z1 LSS %BestSize% (
    set TrialCounter=1
    set BestSize=%~z1
    set BestBlocks=%TrialBlocks%
  ) else (
    set /a TrialCounter+=1
  )
  >>%log% echo %~z1b - %time:~0,5% Tested: %TrialBlocks% blocks (try %TrialCounter%/5). Best: %BestBlocks% blocks.
  if %TrialCounter% GEQ 5 goto T2_Step1_End
  if %TrialBlocks% GEQ %FileMaxHuffmanBlocks% goto T2_Step1_End
  set /a TrialBlocks+=2
  goto T2_Step1_Loop

:T2_Step1_End
  :: Check whether a larger number of blocks is better and re-run Step 1 if required
  set /a TrialDifference=%BestBlocks%-%TrialBlocks%-1
  if %TrialDifference% GTR 8 set TrialDifference=8
  if %BestBlocks% GTR %TrialBlocks% (
    set TrialCounter=0
    set /a TrialBlocks=%BestBlocks%-%TrialDifference%
    >>%log% echo %~z1b - T2S1 Extended trial- restarting Step 1 with more blocks.
    goto T2_Step1_Loop
  )


:: Step 2 - Refined scan around the optimized number of Huffman blocks
:T2_Step2
  >>%log% echo %~z1b - T2S2 Testing settings to ensure optimum number of blocks

  if %BestBlocks% LEQ 1 (
    set TrialBlocks=1
    set TrialCounter=2
  ) else (
    set /a TrialBlocks=%BestBlocks%-1
    set TrialCounter=1
  )

:T2_Step2_Loop
  for %%s in (0,2,3) do (
    pngout.exe -q -k1 -ks -f6 -s%%s -n%TrialBlocks% "%~1"
    :: Test random Huffman tables (x10) for small files
    if %LargeFile% EQU 0 (
      for /L %%i in (1,1,10) do (
        pngout.exe -q -k1 -ks -f6 -s%%s -n%TrialBlocks% -r "%~1"
      )
    )
  )
  >>%log% echo %~z1b - %time:~0,5% Tested %TrialBlocks% block(s) with pngout strategies 0,2,3.
  set /a TrialBlocks+=1
  set /a TrialCounter+=1
  if %TrialCounter% GTR 3 goto T2_End
  goto T2_Step2_Loop


:T2_End

  for /f "tokens=2 delims=n" %%i in ('pngout.exe -L "%~1"') do (
    set BestBlocks=%%i
  )
  >>%log% echo %~z1b - T2S2 Optimum number of Huffman blocks: %BestBlocks%.

  echo %~z1b - Compression trial 2 complete (Huffman blocks and Deflate strategy).



::
:: Trial (3) - Test randomized Huffman tables
::

  echo %~z1b - Compression trial 3 running (Randomize initial Huffman tables)...
  :: From extensive testing, 100 consecutive trials is optimal.
  :: For faster processing set to 1, to effectively skip this stage.
  set RandomTableTrials=100

  :: Test the image is really best optimized with only static Huffman blocks
  if %BestBlocks% EQU 0 (
    deflopt.exe -s -k -b "%~1" >nul
    for /f "tokens=2 delims=n" %%i in ('pngout.exe -L "%~1"') do (
      set BestBlocks=%%i
    )
  )
  if %BestBlocks% EQU 0 (
    >>%log% echo %~z1b - T3S1 Skipping trial. No dynamic Huffman blocks to optimize.
    goto T3_End
  )


:T3_Step1_Loop
  set FileSize=%~z1
  echo %~z1b - Compression trial 3 running (%RandomTableTrials%x random Huffman tables)...
  for /L %%i in (1,1,%RandomTableTrials%) do (
    pngout.exe -q -k1 -ks -kp -f6 -s0 -r "%~1"
  )
  if %~z1 LSS %FileSize% goto T3_Step1_Loop

:T3_End
  echo %~z1b - Compression trial 3 complete (Randomize initial Huffman tables).



::
:: Trial (4) - Final compression sweep
::

  echo %~z1b - Compression trial 4 running (Alternative compression engines)...

  for %%i in (32k,16k,8k,4k,2k,1k,512,256) do (
    optipng.exe -q -nx -zw%%i -zc1-9 -zm1-9 -zs0-3 -f0-5 "%~1"
  )
  >>%log% echo %~z1b - T4S1 Tested OptiPNG.

  for /L %%i in (1,1,3) do (
    advdef.exe -q -z%%i -i200 "%~1"
  )
  >>%log% echo %~z1b - T4S2 Tested advdef (zlib, libdeflate, 7z).
  advdef.exe -q -z4 -i500 "%~1"
  >>%log% echo %~z1b - T4S3 Tested advdef (Zoplfi).

  deflopt.exe -s -k -b "%~1" >nul
  >>%log% echo %~z1b - T4S4 Tested deflopt.

  defluff.exe <"%~1" >"%~1.%SessionID%.temp.png" 2>nul
  deflopt.exe -s -k -b "%~1.%SessionID%.temp.png" >nul
  huffmix.exe -q "%~1" "%~1.%SessionID%.temp.png" "%~1"
  del "%~1.%SessionID%.temp.png"
  if %BestBlocks% GEQ 2 (
    deflopt.exe -s -k "%~1" >nul
  )
  >>%log% echo %~z1b - T4S5 Tested defluff and deflopt.

  echo %~z1b - Final compression sweep finished.



:PostprocessFile

  :: Benchmark end time
  call set "t=%%time:%TimeSeparator%0=%TimeSeparator% %%"
  set /a WallClockEnd=(%t:~0,2%*3600)+(%t:~3,2%*60)+%t:~6,2%
  :: Check if we crossed midnight
  if not "%WallClockStartDate%"=="%date%" (
    set /a WallClockEnd+=86400
  )
  set /a WallClockElapsed=%WallClockEnd%-%WallClockStart%
  :: Convert longer times to minutes
  if %WallClockElapsed% GEQ 180 (
    set /a WallClockElapsed/=60
    set WallClockUnits=minutes
  )
  echo Processing took ~%WallClockElapsed% %WallClockUnits%.

  :: Files expanded over a threshold size may be copied for debugging
  set /a FailSize=((%FileSizeOriginal%*1001)/1000)+2
  if not %log%=="NUL" (
    if %~z1 GTR %FailSize% (
      echo  Original size : %FileSizeOriginal%b.
      echo  Failure size  : %FailSize%b. Margin = 0.1%% + 2 bytes.
      copy /Z "%~1" "%~1.%SessionID%._fail" >nul
      echo  Processed size: %~z1b. Larger file copied for debugging.
    )
  )

  :: Basic output file validation
  if %~z1 LSS 67 (
    echo %~z1b - Error detected: File too small.
    set /a ErrorsLogged+=1
    goto RestoreFile
  )
  if %~z1 GEQ %FileSizeOriginal% (
    echo %~z1b - Could not compress file further.
    goto RestoreFile
  )

  :: Check output PNG file for errors
  pngcheck.exe -q "%~1"
  if errorlevel 1 (
    pngcheck.exe -vvt "%~1" > "%~1.%SessionID%.error.log"
    set /a ErrorsLogged+=1
    echo Error detected: Optimized file is not valid.
    goto RestoreFile
  )

  :: Benchmark file size reduction
  set /a FileBytesSaved=%FileSizeOriginal%-%~z1
  set /a TotalBytesSaved+=%FileBytesSaved%
  :: Calculate high precision percentage without overflowing 32 bit signed integer
  if %FileBytesSaved% LEQ 214000 (
    set /a "FileReductionPercentX100=(100*100*%FileBytesSaved%)/%FileSizeOriginal%"
  ) else (
    set /a "FileReductionPercentX100=((100*%FileBytesSaved%)/%FileSizeOriginal%)*100"
  )
  :: Format the percentage to always show 2 signifcant figures
  if %FileReductionPercentX100% LEQ 99 (
    set FileReductionPct=0.%FileReductionPercentX100%
  ) else (
    if %FileReductionPercentX100% LEQ 999 (
      set FileReductionPct=%FileReductionPercentX100:~0,1%.%FileReductionPercentX100:~1,1%
    ) else (
      set /a FileReductionPct=%FileReductionPercentX100%/100
    )
  )

  echo Optimized: "%~n1" - slimmed %FileBytesSaved% bytes, ~%FileReductionPct%%% saving.
  if exist "%~1" (
    del "%~1.%SessionID%.backup"
  ) else (
    set /a ErrorsLogged+=1
    echo System error: Primary file missing!
    goto Close
  )
  goto NextFile


:RestoreFile
  if exist "%~1.%SessionID%.backup" (
    del "%~1"
  ) else (
    set /a ErrorsLogged+=1
    echo System error: Backup file missing!
    goto Close
  )
  rename "%~1.%SessionID%.backup" "%~nx1"
  if errorlevel 1 (
    set /a ErrorsLogged+=1
    echo System error: Failed to rename backup file.
    goto Close
  )
  echo Original file restored - %~z1b.

:NextFile
  echo.
  shift /1
  if "%~a1"=="" goto Close
  goto SelectFile

:Close
  title Optimization complete.
  set TotalFiles=%CurrentFile%
  echo.
  echo Finished %date% %time% - "%~n0" %Version%.
  echo Processed %TotalFiles% files. Slimmed %TotalBytesSaved% bytes in total.
  if %ErrorsLogged% GTR 0 (
    echo.
    echo WARNING! %ErrorsLogged% Errors logged.
    echo.
  )

:TheEnd
  popd
  endlocal
  pause
  title %comspec%
  goto:eof
