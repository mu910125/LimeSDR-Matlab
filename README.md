# LimeSDR-Matlab

### General
This repository contains a wrapper for LimeSDR-USB drivers that allows to work from Matlab.
All necessary files for the wrapper is located in the folder "_library".
You can find basic examples for the usage of the library in the folder "_examples".
Code is updated to support the current version of LimeSuit(19.04).
Before starting, run `help limeSDR.build_thunk` to view instructions on how to have MATLAB build a Thunk file to use in conjunction with libLimeSuite.

#### Repository structure
1. ***_library***      - folder with wrapper files
2. ***_examples***     - folder that contains basic how to use Matlab with LimeSDR for transmission and reception. Also there is an example for simulateneous transmission and reception.
3. ***_testbenches***  - folder with scripts that check performance of LimeSDR such as average channel alignment, coherence and etc.
4. ***_tools*** - additional code components and user defined functions that are required for main scripts.
5. ***_results***      - folder with simulation results

### Prerequisites
1. Matlab 2022b
2. LimeSuite 22.09
2. Compatible compiler (VS++ is recommended)
3. LimeSDR-USB

### Installation
Steps for the successfull installation:
1. Check that the compatible compiler is installed and Matlab recongises it (`mex --setup`)
2. Check that the LimeSuite 22.09 is installed (you need to copy LimeSuite.dll file to _library dir)
3. Run from Matlab `limeSDR.build_thunk();`
4. Connect LimeSDR-USB
5. Update Firmware `limeutil --update`
6. Run one of the examples

### System configuration
Original system configuration:
1. Windows 11 Pro
2. Visual Studio Professional 2022 (compiler)
3. Matlab 2022b
4. LimeSDR-USB

### Known issues
Library for the Simulink was not modified and probably doesn't work.

### Reference
The code is based on the work from [Jockover](https://github.com/jocover/Simulink-MATLAB-LimeSDR) and [RakhDamir](https://github.com/RakhDamir/LimeSDR-Matlab)



# License #
This code is distributed under an [MIT License](LICENSE.MIT).
