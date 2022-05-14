@echo off & setlocal enableextensions


:: pngslim 
::  - by Andrew C.E. Dent, dedicated to the Public Domain.

  set Version=(v1.2 pre-release)

  set RandomTableTrials=100
  set LargeFileSize=66400
  set ForceRGBA=0
  
  :: Log verbose output: NUL (none) / CON (console display)
  set log="NUL"


  echo Started %date% %time% - pngslim %Version%.
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
    huffmix.exe
    optipng.exe
    pngcheck.exe
    pngoptimizercl.exe
    pngout.exe
    pngrewrite.exe
    zlib.dll
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

  set FileSize=0
  set FileSizeReduction=0
  set TotalBytesSaved=0
  set TotalFiles=0
  set ErrorsLogged=0

  :: Count total files to process
  for /f "tokens=*" %%i in ("%*") do (
    for %%j in (%%i) do set /a TotalFiles+=1
  )

:SelectFile
  set /a CurrentFile+=1
  set Status=[%CurrentFile%/%TotalFiles%] pngslim %Version%
  title %Status%

  :: Basic file validation
  if /I "%~x1" NEQ ".png" goto NextFile
  if %~z1 LSS 67 goto NextFile

  echo %~z1b - Optimizing: "%~1"

  :: Check PNG file for errors
  pngcheck.exe -q "%~1"
  if errorlevel 1 (
    pngcheck.exe -vvt "%~1" > "%~1".error.log
    set /a ErrorsLogged+=1
    echo Error detected: Skipped invalid file.
    goto NextFile
  )

  set OriginalFileSize=%~z1

  copy /Z "%~1" "%~1.backup" >nul
  fc.exe /B "%~1" "%~1.backup" >nul
  if errorlevel 1 (
    set /a ErrorsLogged+=1
    echo System error: Backup file corrupted.
    goto Close
  )


:PreprocessFile

  :: Losslessly reduce 16 to 8bit per channel, if possible
  optipng.exe -q -i0 -zc1 -zm8 -zs3 -f0 -force "%~1"

  :: Strip metadata and create an uncompressed, 32bpp RGBA bitmap
  pngout.exe -q -s4 -f0 -c6 -k0 -force "%~1"
  if errorlevel 1 (
    echo Cannot compress: Unsupported PNG format.
    goto RestoreFile
  )
  >>%log% echo %~z1b - T0S1 Written uncompressed file with stripped metadata.

  set ImageColorMode="Undetermined"
  set ImageTransparencyMode="Undetermined"

  set LargeFile=0
  if %~z1 GTR %LargeFileSize% set LargeFile=1

  set /a FileMaxHuffmanBlocks=%~z1/256
  if %FileMaxHuffmanBlocks% GTR 1024 set FileMaxHuffmanBlocks=1024
  >>%log% echo %~z1b - T0S2 File metrics: Max Huffman blocks = %FileMaxHuffmanBlocks%, Large file = %LargeFile%.


  :: Skip steps that modify color depth for Forced RGBA images
  if %ForceRGBA%==1 (
    echo %~z1b - Preprocessing complete ^(Saved RGBA image, stripped metadata^).
    echo %~z1b - Compression trial 1 running ^(RGBA Color and filter settings^)...
    goto T1_Step1_RGBA
  )

  :: pngoptimizercl.exe -file:"%~1" >nul
  pngrewrite.exe "%~1" "%~1" 2>nul
  pngout.exe -q -k1 -ks -kp -f6 -s1 "%~1"
  echo %~z1b - Preprocessing complete (optimized metadata, palette and transparency).



::
:: Trial (1) - Determine optimum color type and delta filter.
::

  echo %~z1b - Compression trial 1 running (Color and filter settings)...

:T1_Step1_Gray
  pngout.exe -q -s4 -c0 -d8 "%~1"
  if errorlevel 3 goto T1_Step1_Gray+Alpha
  set ImageColorMode="Gray"
  set ImageTransparencyMode="Basic"
  for %%i in (1,2,4,8) do (
    if %LargeFile%==0 (
      for %%j in (1,2) do (
        for /L %%k in (0,1,5) do ( 
          pngout.exe -q -k1 -s0 -d%%i -n%%j -f%%k -c0 "%~1"
        )
      )
    )
    if %LargeFile%==1 (
      for %%j in (0,256) do (
        for %%k in (0,5) do (
          pngout.exe -q -k1 -s1 -d%%i -b%%j -f%%k -c0 "%~1"
        )
      )
    )
  )
  >>%log% echo %~z1b - T1S1 Tested color setting -c0 (Gray).


:T1_Step1_Gray+Alpha
  pngout.exe -q -s4 -c4 "%~1"
  if errorlevel 3 goto T1_Step1_Paletted
  set ImageColorMode="Gray"
  if %ImageTransparencyMode% NEQ "Basic" (
    set ImageTransparencyMode="Multiple" 
  )
  if %LargeFile%==0 (
    for %%i in (1,2) do (
      for /L %%j in (0,1,5) do (
        pngout.exe -q -k1 -s0 -n%%i -f%%j -c4 "%~1"
      )
    )
  )
  if %LargeFile%==1 (
    for %%i in (0,256) do (
      for %%j in (0,5) do (
        pngout.exe -q -k1 -s1 -b%%i -f%%j -c4 "%~1"
      )
    )
  )
  >>%log% echo %~z1b - T1S1 Tested color setting -c4 (Gray+Alpha).


:T1_Step1_Paletted
  pngout.exe -q -s4 -c3 -d8 "%~1"
  if errorlevel 3 goto T1_Step1_RGB
  if %ImageColorMode% NEQ "Gray" (
    set ImageColorMode="Paletted" 
  )
  for %%i in (1,2,4,8) do (
    if %LargeFile%==0 (
      for %%j in (1,2) do (
        for /L %%k in (0,1,5) do (
          pngout.exe -q -k1 -s0 -d%%i -n%%j -f%%k -c3 "%~1"
        )
      )
    )
    if %LargeFile%==1 (
      for %%j in (0,256) do (
        for %%k in (0,5) do (
          pngout.exe -q -k1 -s1 -d%%i -b%%j -f%%k -c3 "%~1"
        )
      )
    )
  )
  >>%log% echo %~z1b - T1S1 Tested color setting -c3 (Paletted).


:T1_Step1_RGB
  if %ImageColorMode%=="Gray" goto T1_Step2
  pngout.exe -q -s4 -c2 "%~1"
  if errorlevel 3 goto T1_Step1_RGBA
  if %ImageColorMode% NEQ "Gray" (
    if %ImageColorMode% NEQ "Paletted" (
      set ImageColorMode="RGB" 
    )
  )
  set ImageTransparencyMode="Basic"
  if %LargeFile%==0 (
    for %%i in (1,2) do (
      for /L %%j in (0,1,5) do (
        pngout.exe -q -k1 -s0 -n%%i -f%%j -c2 "%~1"
      )
    )
  )
  if %LargeFile%==1 (
    for %%i in (0,256) do (
      for %%j in (0,5) do (
        pngout.exe -q -k1 -s1 -b%%i -f%%j -c2 "%~1"
      )
    )
  )
  >>%log% echo %~z1b - T1S1 Tested color setting -c2 (RGB).


:T1_Step1_RGBA
  if  %ForceRGBA% NEQ 1 (
    if %ImageColorMode% NEQ "Gray" (
      if %ImageColorMode% NEQ "Paletted" (
        set ImageColorMode="RGB" 
      )
    )
    if %ImageTransparencyMode% NEQ "Basic" (
      set ImageTransparencyMode="Multiple" 
    )
  )
  if %LargeFile%==0 (
    for %%i in (1,2) do (
      for /L %%j in (0,1,5) do (
        pngout.exe -q -k1 -s0 -n%%i -f%%j -c6 "%~1"
      )
    )
  )
  if %LargeFile%==1 (
    for %%i in (0,256) do (
      for %%j in (0,5) do (
        pngout.exe -q -k1 -s1 -b%%i -f%%j -c6 "%~1"
      )
    )
  )
  >>%log% echo %~z1b - T1S1 Tested color setting -c6 (RGB+Alpha).


:T1_Step2
  >>%log% echo %~z1b - T1S2 Testing Delta filters for chosen color type...
  if %LargeFile%==0 (
    for %%i in (0,3) do (
      for /L %%j in (0,1,5) do (
        pngout.exe -q -k1 -ks -kp -s%%i -b256 -f%%j "%~1"
      )
    )
    optipng.exe -q -nx -zc1-9 -zm8-9 -zs0-3 -f0-5 "%~1"
    if %ForceRGBA% NEQ 1 optipng.exe -q -zc1-9 -zm8-9 -zs0-3 -f0-5 "%~1"
  )
  if %LargeFile%==1 (
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
  echo %~z1b - Compression trial 1 complete (Color and filter type).



::
:: Trial (2) - Determine optimum number of Huffman blocks and Deflate strategy with PNGOUT
::

  echo %~z1b - Compression trial 2 running (Deflate settings)...

  set BestBlocks="Undetermined"
  for /f "tokens=2 delims=n" %%i in ('pngout.exe -L "%~1"') do (
    set BestBlocks=%%i
  )
  >>%log% echo %~z1b - T2S0 Initial number of Huffman blocks = %BestBlocks%.


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
  >>%log% echo %~z1b - T2S1 Tested: %TrialBlocks% blocks (try %TrialCounter%/5). Best: %BestBlocks% blocks.
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
    if %LargeFile%==0 (
      for /L %%i in (1,1,10) do (
        pngout.exe -q -k1 -ks -f6 -s%%s -n%TrialBlocks% -r "%~1"
      )
    )
  )
  >>%log% echo %~z1b - T2S2 Tested %TrialBlocks% block(s) with pngout strategies 0,2,3.
  set /a TrialBlocks+=1
  set /a TrialCounter+=1
  if %TrialCounter% GTR 3 goto T2_End
  goto T2_Step2_Loop


:T2_End
  for /f "tokens=2 delims=n" %%i in ('pngout.exe -L "%~1"') do (
    set BestBlocks=%%i
  )
  >>%log% echo %~z1b - T2S2 Optimal number of Huffman blocks = %BestBlocks%.

  echo %~z1b - Compression trial 2 complete (Huffman blocks and Deflate strategy).



::
:: Trial (3) - Test randomized Huffman tables
::

:T3_Step1_Loop
  set FileSize=%~z1
  echo %~z1b - Compression trial 3 running (%RandomTableTrials%x random Huffman tables)...
  for /L %%i in (1,1,%RandomTableTrials%) do (
    pngout.exe -q -k1 -ks -kp -f6 -s0 -r "%~1"
  )
  if %~z1 LSS %FileSize% goto T3_Step1_Loop
  echo %~z1b - Compression trial 3 complete (Randomized Huffman tables).



::
:: Trial (4) - Final compression sweep
::

  echo %~z1b - Compression trial 4 running (Alternative compression engines)...

  for %%i in (32k,16k,8k,4k,2k,1k,512,256) do (
    optipng.exe -q -nx -zw%%i -zc1-9 -zm1-9 -zs0-3 -f0-5 "%~1"
  )
  >>%log% echo %~z1b - T4S1 Tested OptiPNG

  for /L %%i in (1,1,4) do (
    advdef.exe -q -z%%i "%~1"
  )
  >>%log% echo %~z1b - T4S2 Tested advdef
  
  deflopt.exe -s -k "%~1" >nul
  >>%log% echo %~z1b - T4S3 Tested deflopt
  
  echo %~z1b - Final compression sweep finished.



:PostprocessFile

  :: Files expanded over a threshold size, are copied for debugging
  set /a FailSize=((%OriginalFileSize%*1001)/1000)+2
  if %log%=="CON" (
    echo  Original size: %OriginalFileSize%b. 
    echo  Failure size: %FailSize%b. Margin = 0.1%% + 2 bytes.
    if %~z1 GTR %FailSize% (
      copy %1 %1._fail >nul
      echo  Processed size: %~z1b. Larger file copied for debugging. 
    )
  )

  :: Basic output file validation
  if %~z1 LSS 67 (
    echo %~z1b - Error detected: File too small.
    set /a ErrorsLogged+=1
    goto RestoreFile
  )
  if %~z1 GEQ %OriginalFileSize% (
    echo %~z1b - Could not compress file further.
    goto RestoreFile
  )

  :: Check output PNG file for errors
  pngcheck.exe -q "%~1"
  if errorlevel 1 (
    pngcheck.exe -vvt "%~1" > "%~1".error.log
    set /a ErrorsLogged+=1
    echo Error detected: Optimized file is not valid.
    goto RestoreFile
  )

  set /a FileSize=%OriginalFileSize%-%~z1
  set /a FileSizeReduction=(%FileSize%*100)/%OriginalFileSize%
  set /a TotalBytesSaved+=%FileSize%

  echo Optimized: "%~n1". Slimmed %FileSizeReduction%%%, %FileSize% bytes.
  del "%~1.backup"
  goto NextFile


:RestoreFile
  del "%~1"
  rename "%~1.backup" "%~nx1"
  if errorlevel 1 (
    set /a ErrorsLogged+=1
    echo System error: Failed to rename backup file.
    goto Close
  )
  echo Original file restored.

:NextFile
  echo.
  shift /1
  if "%~a1"=="" goto Close
  goto SelectFile

:Close
  title Optimization complete.
  set TotalFiles=%CurrentFile%
  echo.
  echo Finished %date% %time% - pngslim %Version%.
  echo Processed %TotalFiles% files. Slimmed %TotalBytesSaved% bytes.
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