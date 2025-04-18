


# pngslim 
&emsp;&emsp; – _when every byte counts!_  

Batch optimization of PNG images for MS Windows, using multiple tools to achieve the smallest file size, with scant regard for time.  

Produced by Andrew C.E. Dent, 2025.  
<br>


## Usage

1. Unzip the 'pngslim' folder and place in your chosen location.
2. Drag & drop* your PNG files on `pngslim.cmd` to run.
3. Have fun slimming away those surplus bytes! :-)

> [!NOTE]  
> Due to limitations of MS Windows, the maximum number of files that you can drag & drop depends on the total text length of the image file paths+names. If the script doesn't run or you see the following error message : `Windows cannot access the specified device, path, or file...`, you should reduce the number of selected files (typically <100), and consider moving your files to shorten the path names (e.g. "C:\png\").  


### Script parameters
By default the script parameters are highly tuned for the majority of use cases but advanced users may wish to tweak them.

- `ForceRGBA` : [0/1] will rewrite the image as an RGBA image at 32 bits per pixel (or RGB 24 bpp for fully opaque images) and then only optimize in that color mode, or restore the original if not compressed. This limits the possible compression methods and may produce larger files, so is *not* recommended (default is off, 0).  

- `ReduceDiskWrites` : [0/1] Avoid writing files to disk when possible, to reduce wear on the drive (default is on, 1). This may slightly reduce the compression that can be achieved, limiting the trial of randomized Huffman tables.  

- `LargeFileSize` : The uncompressed file size in bytes that determines a small/ large image and adjusts processing effort accordingly. The default 66400 bytes corresponds to an image larger than 128 x 128 pixels.  


### Limitations

**Compatibility** – Although this software produces fully compliant PNG images, a minority of image editors and viewers contain bugs which may cause problems displaying these optimized images. Always backup images before optimizing and test compatibility for your given application. Images with extended bit depths, at 16 bits per channel, will not be optimized.

**Security** – This script should not be used on secure systems or to process unknown files from third parties. Malicious files and/ or crafted file names, can make the script and utility programs behave in unexpected ways. This is a fundamental limitation of the scripting environment used (Windows Batch).

> [!CAUTION]  
> **Disk wear** – The optimization process can write each file *hundreds* of times to disk. For some storage media, including Solid State Drives (SSDs), this may cause excessive wear and shorten the life of the device. It is strongly recommended that you use a RAM drive (fast and robust) or other media that can tolerate heavy write cycles.


## Legal

The software ('pngslim' script) is provided 'as-is', without any express or implied warranty. In no event will the author be held liable for any damages arising from the use of this software. Permission is granted to anyone to use this software for any purpose, including commercial applications, and to alter it and redistribute it freely. The software is dedicated to the Public Domain.

The additional software included in the 'pngslim' package ('apps') is provided for convenience. The additional software is the property of other authors and may be subject to different licensing and legal conditions. Please check the original authors' websites for details and latest information. I have no affiliation with the authors of the included software.



## Included programs

All binaries are compiled for 32 bit Windows (w32):

- [advdef](https://github.com/amadvance/advancecomp) v2.5 (22-Jan-2023) by Andrea Mazzoleni.

- [DeflOpt](http://web.archive.org/web/20131208161446/http://www.walbeehm.com/download/index.html) v2.07 (05-Sep-2007) by Ben Jos Walbeehm.

- [defluff](https://web.archive.org/web/20230604215335/https://encode.su/threads/1214-defluff-a-deflate-huffman-optimizer) v0.3.2 (07-Apr-2011) by Joachim Henke. 

- [Huffmix](https://encode.su/threads/1313-Huffmix-a-PNGOUT-r-catalyst) v0.6b2 (06-May-2014) by Frédéric Kayser.

- [OptiPNG](http://optipng.sourceforge.net/) v0.7.7 (27-Dec-2017) by Cosmin Truta.

- [pngcheck](http://www.libpng.org/pub/png/apps/pngcheck.html) v3.0.3 (25-Apr-2021) by Alexander Lehmann, Andreas Dilger, Greg Roelofs.

- [PNGOUT](http://advsys.net/ken/utils.htm) (13-Feb-2015) by Ken Silverman. 

- [pngrewrite](http://entropymine.com/jason/pngrewrite/) v1.4.0 (8-Jun-2010) by Jason Summers. 


## Thanks!

Inspiration came from a script by Jens Rex, 2005. http://hydrogenaudio.org/forums/?showtopic=22036

Big thanks to: David Blake, counting_pine, fred01, markcramer, Greg Roelofs, Ken Silverman, Sined, Thundik81, Cosmin Truta, UncleBuck, Zardalu and others. Finally a massive thanks to all authors of the software on which this script depends, and those pioneers developing and optimizing the PNG standard.



## History

**v1.2 Development 2025** 
- Smarter Trial (1). Identify fully opaque images and avoid unnecessary trials with transparency.
- Improved Trial (2) - optimizing number of Huffman blocks and PNGOUT Deflate strategy. Trial is smarter, faster and may improve compression for large images. Removed `HuffmanTrials` parameter (now unnecessary) and increased maximum number of blocks from 512 to 1024. Trial is skipped early for files well optimized with a single block.
- Improved Trial (3) - optimizing Huffman tables. Removed `RandomTableTrials` from user parameters. Skip trial entirely for (small) images that only have static Huffman blocks.
- Extend Trial (4) - final compression sweep includes defluff working with DeflOpt and Huffmix.
- Provide more info: processing time per image and more accurate file reduction %.
- File validation: Large files over 10MiB will not be processed.
- Added PNGOUT parameters for efficiency and correctness: use `-kp` to avoid palette trials and `-f6` to avoid filter trials, where possible.
- Changed OptiPNG parameters `−nb −nc −np` to the more compact `-nx`, when disabling all lossless image reductions.
- Improved script readability: indents changed back from tabs to spaces(!);  removed use of `start /belownormal` to run PNGOUT; removed inline comments; made verbose output ('logging') clearer.
- Reformatted 'README' for markdown and tweaked text. Added a 'Limitations' section.
- Update 'advdef.exe' to version 2.5 (was 1.15). Adds 'libdeflate' and 'Zopfli' compression engines; many improvements and fixes.
- Added 'defluff.exe' program v0.3.2 (07-Apr-2011). Provides some low-level optimizations for Deflate data.
- Added 'huffmix.exe' program v0.6b2 (06-May-2014). It selects the smallest Huffman blocks from two related files and combines them into a new file.
- Updated PNGOUT license.

**v1.1 12-Sep-2021**
- Added an early trial with OptiPNG, to losslessly reduce 16 to 8 bit per channel. True 16bpc files are still rejected as 'unsupported'.
- Added `ForceRGBA` option. Certain applications require PNG files to be in the RGB+Alpha color mode, at the cost of compression. Default is off.
- Added PNG validation: Basic file attributes tested (greater than 67 bytes); File data checked with pngcheck on input and output.
- Hardened script against malicious filename input (names properly enclosed).
- Improved script readability: Indented with tabs; More consistent label and variable naming; Expanded FOR loops over multiple lines; Avoid long lines (<80chrs); External commands (executables) are identified with '.exe'.
- Fixed up typos and small details in Readme.
- Bundled programs will no longer be UPX compressed. The space saving is not necessary and provides a minor speed up. Programs' license information added.
- Added 'pngcheck.exe' program v3.0.3 (25-Apr-2021) for file validation.
- Updated 'OptiPNG.exe' to v0.7.7 (was v0.6.3). Unpacked the distributed file, removing UPX compression. Various vulnerability fixes; Upgrades libpng and zlib; Adds options -nx, -strip, -clobber, -debug; Changes the activity display output from STDOUT to STDERR.
- Updated 'pngrewrite.exe' to version 1.4.0 (was 1.3.0). Maintenance release.
- Updated 'pngout.exe' to 13-Feb-2015 release (was 22-Sep-2009). This gives better randomness when the -r switch is used; Fixes -f5 to generate block boundaries in a consistent and correct manner; Adds -f6 option to reuse filters line-by-line from a source PNG file. 

**v1.0 25-Sep-2009**
- Release of version 1.0, with smarter, more efficient processing!
- Trial 1 to determine the best Color and Pre-filter type has been re-written. This adjusts the effort used according to the size of the image. While this should give a speed boost, it should *not* affect compression. Typically compression should be equal or slightly improved. Let me know if this is not your experience.
- With the re-write, some of the User variable were no longer necessary and removed. The script requires less tweaking now and should work great for you out of the box.
- Checked UPX compression of apps (v3.03W -ultra-brute -compress-icons=3). Compressed 'pngoptimizercl' and 'pngrewrite'.

**v1.0beta3 23-Sep-2009**
- Update introduces first step in making the script a bit smarter and efficient.
- Bug fix, for setting the program path using the 'App' directory (from 1.0b2).
- Improved the routine for determining the optimum number of Huffman blocks, and the Deflate strategy used by PNGOUT. It should be noticeably faster for large images, and may yield better compression in some cases.
- This is the first part of the script re-write, introducing improvements in readability and the addition of debug/ geek feedback in the Verbose mode (v=0/1).

**v1.0beta2 21-Sep-2009**
- Small update release- no compression improvements.
- Reduced the default number of Huffman block trials saving time for large images (MinBlockSize: 128 to 256bytes, LimitBlocks: 256 to 200 max). These are probably more optimal settings.
- The color-filter trial tests less block thresholds (skip /b512), but this should not affect final compression (Huffman blocks are optimized in Trial 2) and helps improve speed.
- Testing revealed that in rare instances the color-filter choice was not optimal when using the quicker PNGOUT mode (/s1). The better but much slower mode is now always used (/s0). For many users the original mode would be sufficient.
- More extensive color-filter trials with OptiPNG at 'stage24' may boost speed, as less randomized trials will be tested with PNGOUT if OptiPNG is superior.
- Priority of Huffman trials (block number and random tables) increased from Low to Below Normal for faster processing.
- Trial 3 updated to remove PNGOUT best strategy (/s0) which is already tested.
- Added the minimal 256byte zlib window size to final, ultimate OptiPNG trial.
- Tweaked compression trial 4 message to report number of trials (RandomTrials).
- Applications have been updated and placed in a separate 'apps' folder.

**v1.0beta1 25-Mar-2008**
- This update shifts the emphasis further towards compression, with even less concern for speed / efficiency. More brute force trials are explored initially, to avoid hitting local minima too early and then wasting time with later trials.
- As several changes have been implemented, this release is marked as a beta awaiting feedback from the community.
- Renumbered the script stages ('01'>'10', etc.) for greater flexibility.
- Simpler detection of 16bpp / unsupported images using PNGOUT's exitcodes.
- Added 'PngOptimizer' program which sets transparent (A=0) pixels to black and often improves compression. Although this is technically a lossy process removing color data, these regions will never be seen in the PNG image.
- It may no longer be necessary to include 'pngrewrite', but until this has been tested, I will leave the script as is.
- More trials with some logic to determine best color and filter combination. As a result 'stage20' has been subdivided. Grayscale images should be tested first, with non productive trials skipped. Please test my processing; comments welcome!
- Removed 'StartSize' variable and now reuse 'zs' as a general file size counter.
- Some longer running trials (PNGOUT) now run at low priority (start /low /b).
- Changed executable names to lowercase and removed '.exe' extension from script.
- After compressing each image, the percentage slimmed is now reported.
- Updated 'DeflOpt' (UPX compressed) and 'PNGOUT' to latest versions.
- The following enhancements were suggested by 'fred01' (many thanks!):
- Script uses set- / endlocal, so should play nicer with batch scripting.
- If any of the bundled programs are not found, an error message is now produced.
- Zlib upgraded (1.2.2.1828 from AdvanceComp) to the latest version (1.2.3) and then compressed with UPX 3.02. The main changes are security fixes, so hopefully this wont cause any problems.

**v0.91 21-Aug-2007**
- Added 'VersionText' variable for identifying customized scripts (i.e. 'Fast', 'Extreme', etc.)
- Check added for detecting 'zlib.dll'.
- First step of uncompressing PNG with PNGOUT now always uses RGBA (-c6).
- Reordered trials in 'Stage02' and added a PNGOUT trial with some default settings. This may occasionally find better color and filter parameters, improving compression.
- Used UPX 3.01 (--ultra-brute) to compress the packaged software except for pngout.exe and OptiPNG.exe (it seems the originals are already compressed).
- Updated 'readme.txt', reformatted for fixed width and included details of PNGOUT license.

**v0.9 09-Jul-2007**
- Fixed missing quotes for checking if required programs are present.
- Reduced range of Huffman blocks tested (Trial 2) for quicker processing.
- Slight syntax changes for future porting efforts.
- After Stage01 (where metadata is stripped), all further compression stages have been set to preserve meta data (-k1). Hence, ancillary chunks can be kept by editing the script to skip the first stage.
- Updated the included software to latest versions.
- Removed the 'pngexpand' script. I believe few users would benefit from it.
- Updated 'readme.txt'. Added warning for mobile phone developers.

**v0.8 20-Jan-2007**
- The pngslim directory is now set automatically by reading the directory of the script and setting the executable search path to this directory. This removes the need to edit the script manually; More user friendly.
- The minimum block size was increased to be more practical (64 > 128bytes), reducing number of trials (hence time) for larger images.
- Unsupported formats of PNG files (e.g. 16bpp) are checked for and skipped.
- Window title is more compact for easier viewing when minimized.
- Added 'pngexpand' script to help avoid bugs in Photoshop and other editors.
- 'readme.txt' file cleaned up.

**v0.7 04-Jan-2007**
- Stage02: Initial compression with OptiPNG tests all filters (0-5).
- Stage02/Trial3: Added /s0 to test default Huffman tables and improve compression before Stage03.

**v0.6 01-Jan-2007**
- First public release.

---

https://github.com/ace-dent/pngslim/releases
