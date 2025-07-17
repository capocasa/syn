import unittest
import std/os
import ../src/syn

when defined(generatePlots):
  import ../src/syn/plot

suite "Visualizations (manual review)":
  test "generate waveform plots":
    when not defined(generatePlots):
      skip()
    else:
      # Create output directory
      createDir("test_output")
      
      # Generate saw wave plot
      proc sawProc(phase: uint): float32 = saw(phase)
      let sawImage = plot(sawProc)
      sawImage.writeFile("test_output/saw.png")
      
      # Generate sawd wave plot
      proc sawdProc(phase: uint): float32 = sawd(phase)
      let sawdImage = plot(sawdProc)
      sawdImage.writeFile("test_output/sawd.png")
      
      # Generate pulse wave plot
      proc pulseProc(phase: uint): float32 = pulse(phase, 0.5)
      let pulseImage = plot(pulseProc)
      pulseImage.writeFile("test_output/pulse.png")
      
      # Generate pulse wave with different duty cycle
      proc pulseQuarterProc(phase: uint): float32 = pulse(phase, 0.25)
      let pulseQuarterImage = plot(pulseQuarterProc)
      pulseQuarterImage.writeFile("test_output/pulse_25.png")
      
      echo "Visualization plots generated in test_output/"
      echo "Files created:"
      echo "  - saw.png (sawtooth wave)"
      echo "  - sawd.png (downward sawtooth)"
      echo "  - pulse.png (square wave 50%)"
      echo "  - pulse_25.png (square wave 25%)"