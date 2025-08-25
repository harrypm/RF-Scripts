# RF Scripts


Scripts repository for use with the [decode projects](https://github.com/oyvindln/vhs-decode/wiki).


# Clockgen Scripts


- Direct

Direct offers direct output from both cards at 40msps 8-bit ideal for lower end systems that can't resample with SoX or resampling is prefered to be done manually later for HiFi FM RF audio.

- Resampled

This script was the orginal script, now its a go to for higher end systems that can cope with real-time SoX resampling or 4:1 downsampling for HiFi FM RF. 

- SoX Benchmark

This script simply benchmarks your CPUs proformace abbility with SoX usefull to find out if somthing is very wrong or yours systems abbilitys.


# Auto Audio Align

- aligin

This script is ment for easy global use of 48kh and 46khz files from HiFi-Decode / Baseband capture from MISRC/Clockgen Mod. will take .JSON decode data and or .wav/.flac audio files either first or last.


# Proxy

- proxy

This script is a master proxy genaration script, AVC stock config is Youtube supported and Odysee ready, also has OPUS/HEVC, uses web-ready MP4.
