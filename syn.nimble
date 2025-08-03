# Package

version       = "0.1.0"
author        = "Carlo Capocasa"
description   = "The fast, small and liberally licensed pffft fast-fourier-transform (FFT) library wrapped for Nim"
license       = "MIT"
srcDir        = "src"
installDirs   = @["clib"]

# Dependencies

requires "nim >= 2.0.0"
requires "nimsimd"
requires "pffft >= 0.2"
#requires "mmops"

# Development dependencies
when not defined(release):
  requires "pixie"

