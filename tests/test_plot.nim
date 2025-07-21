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
      
      # Generate triangle wave plots
      proc triangleProc(phase: uint): float32 = triangle(phase, 0.5)
      let triangleImage = plot(triangleProc)
      triangleImage.writeFile("test_output/triangle.png")
      
      proc triangle25Proc(phase: uint): float32 = triangle(phase, 0.25)
      let triangle25Image = plot(triangle25Proc)
      triangle25Image.writeFile("test_output/triangle_25.png")
      
      proc triangle75Proc(phase: uint): float32 = triangle(phase, 0.75)
      let triangle75Image = plot(triangle75Proc)
      triangle75Image.writeFile("test_output/triangle_75.png")
      
      # Generate bandlimited sawtooth wavetable plot
      var sawTable: array[2048, float32]
      # Fill with naive sawtooth using saw procedure
      for i in 0..<2048:
        let phase = uint(i) * (high(uint) div 2048)
        sawTable[i] = saw(phase)
      
      # Bandlimit in place (using 48kHz sample rate, cutoff at 5kHz for visible effect)
      var bandlimited = sawTable
      bandlimit(sawTable, bandlimited, 5000.0f32, 48000.0f32)
      sawTable = bandlimited
      
      # Create proc for linear interpolated lookup
      proc bandlimitedSawProc(phase: uint): float32 = lin(sawTable, phase)
      let bandlimitedSawImage = plot(bandlimitedSawProc)
      bandlimitedSawImage.writeFile("test_output/bandlimited_saw.png")
      
      # Generate bandlimited sawd wavetable plot
      var sawdTable: array[2048, float32]
      # Fill with naive sawd using sawd procedure
      for i in 0..<2048:
        let phase = uint(i) * (high(uint) div 2048)
        sawdTable[i] = sawd(phase)
      
      # Bandlimit in place (using 48kHz sample rate, cutoff at 5kHz for visible effect)
      var bandlimitedSawd = sawdTable
      bandlimit(sawdTable, bandlimitedSawd, 5000.0f32, 48000.0f32)
      sawdTable = bandlimitedSawd
      
      # Create proc for linear interpolated lookup
      proc bandlimitedSawdProc(phase: uint): float32 = lin(sawdTable, phase)
      let bandlimitedSawdImage = plot(bandlimitedSawdProc)
      bandlimitedSawdImage.writeFile("test_output/bandlimited_sawd.png")
      
      # Generate bandlimited pulse wavetable plot
      var pulseTable: array[2048, float32]
      # Fill with naive pulse using pulse procedure (50% duty cycle)
      for i in 0..<2048:
        let phase = uint(i) * (high(uint) div 2048)
        pulseTable[i] = pulse(phase, 0.5)
      
      # Bandlimit in place (using 48kHz sample rate, cutoff at 5kHz for visible effect)
      var bandlimitedPulse = pulseTable
      bandlimit(pulseTable, bandlimitedPulse, 5000.0f32, 48000.0f32)
      pulseTable = bandlimitedPulse
      
      # Create proc for linear interpolated lookup
      proc bandlimitedPulseProc(phase: uint): float32 = lin(pulseTable, phase)
      let bandlimitedPulseImage = plot(bandlimitedPulseProc)
      bandlimitedPulseImage.writeFile("test_output/bandlimited_pulse.png")
      
      # Generate bandlimited triangle wavetable plot
      var triangleTable: array[2048, float32]
      # Fill with naive triangle using triangle procedure (50% slope)
      for i in 0..<2048:
        let phase = uint(i) * (high(uint) div 2048)
        triangleTable[i] = triangle(phase, 0.5)
      
      # Bandlimit in place (using 48kHz sample rate, cutoff at 5kHz for visible effect)
      var bandlimitedTriangle = triangleTable
      bandlimit(triangleTable, bandlimitedTriangle, 5000.0f32, 48000.0f32)
      triangleTable = bandlimitedTriangle
      
      # Create proc for linear interpolated lookup
      proc bandlimitedTriangleProc(phase: uint): float32 = lin(triangleTable, phase)
      let bandlimitedTriangleImage = plot(bandlimitedTriangleProc)
      bandlimitedTriangleImage.writeFile("test_output/bandlimited_triangle.png")
      
      echo "Visualization plots generated in test_output/"
      echo "Files created:"
      echo "  - saw.png (sawtooth wave)"
      echo "  - sawd.png (downward sawtooth)"
      echo "  - pulse.png (square wave 50%)"
      echo "  - pulse_25.png (square wave 25%)"
      echo "  - triangle.png (triangle wave 50%)"
      echo "  - triangle_25.png (triangle wave 25%)"
      echo "  - triangle_75.png (triangle wave 75%)"
      echo "  - bandlimited_saw.png (bandlimited sawtooth wavetable)"
      echo "  - bandlimited_sawd.png (bandlimited downward sawtooth wavetable)"
      echo "  - bandlimited_pulse.png (bandlimited pulse wavetable)"
      echo "  - bandlimited_triangle.png (bandlimited triangle wavetable)"