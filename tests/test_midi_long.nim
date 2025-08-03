import unittest
import ../src/syn/input

# Helper to create test MIDI events
proc createMidiEvent(eventType: uint8, data1: uint8, data2: uint8, channel: uint8 = 0): array[3, uint8] =
  result[0] = eventType or channel
  result[1] = data1
  result[2] = data2

suite "MIDI toArrays Big Tests":
  
  test "Complex musical scenario with full feature set":
    var events: seq[(int, array[3, uint8])] = @[]
    
    # Setup a complex musical scenario across 64 samples with 8 voice polyphony
    # and comprehensive control tracking
    
    # Initial control setup
    events.add((0, createMidiEvent(0xB0, 1, 64)))    # ModWheel = 64
    events.add((0, createMidiEvent(0xB0, 64, 127)))  # Sustain on
    events.add((0, createMidiEvent(0xC0, 42, 0)))    # Program = 42
    events.add((0, createMidiEvent(0xD0, 80, 0)))    # Channel pressure = 80
    
    # Chord progression: C major (frames 4-20)
    events.add((4, createMidiEvent(0x90, 60, 100)))  # C4 - voice 0
    events.add((5, createMidiEvent(0x90, 64, 95)))   # E4 - voice 1
    events.add((6, createMidiEvent(0x90, 67, 90)))   # G4 - voice 2
    
    # Add some modulation during the chord
    events.add((8, createMidiEvent(0xB0, 1, 80)))    # ModWheel increase
    events.add((10, createMidiEvent(0xA0, 60, 50)))  # C4 aftertouch
    events.add((12, createMidiEvent(0xE0, 0x20, 0x50))) # Pitch bend
    
    # Melody line over the chord (frames 16-40)
    events.add((16, createMidiEvent(0x90, 72, 110))) # C5 - voice 3
    events.add((20, createMidiEvent(0x80, 72, 0)))   # C5 off
    events.add((21, createMidiEvent(0x90, 74, 105))) # D5 - voice 3 (reused)
    events.add((25, createMidiEvent(0x80, 74, 0)))   # D5 off
    events.add((26, createMidiEvent(0x90, 76, 100))) # E5 - voice 3 (reused)
    
    # Bass line (frames 24-48)
    events.add((24, createMidiEvent(0x90, 48, 120))) # C3 - voice 4
    events.add((32, createMidiEvent(0x80, 48, 0)))   # C3 off
    events.add((33, createMidiEvent(0x90, 43, 115))) # G2 - voice 4 (reused)
    
    # More control changes
    events.add((30, createMidiEvent(0xB0, 1, 40)))   # ModWheel decrease
    events.add((35, createMidiEvent(0xD0, 100, 0)))  # Channel pressure increase
    
    # Release the main chord (frames 40-44)
    events.add((40, createMidiEvent(0x80, 60, 0)))   # C4 off
    events.add((42, createMidiEvent(0x80, 64, 0)))   # E4 off
    events.add((44, createMidiEvent(0x80, 67, 0)))   # G4 off
    
    # New chord: Am (frames 48-60)
    events.add((48, createMidiEvent(0x90, 57, 95)))  # A3 - voice 0 (reused)
    events.add((49, createMidiEvent(0x90, 60, 90)))  # C4 - voice 1 (reused) 
    events.add((50, createMidiEvent(0x90, 64, 85)))  # E4 - voice 2 (reused)
    
    # Final modulation and release
    events.add((55, createMidiEvent(0xB0, 1, 0)))    # ModWheel to 0
    events.add((56, createMidiEvent(0xB0, 64, 0)))   # Sustain off
    events.add((58, createMidiEvent(0x80, 76, 0)))   # E5 off
    events.add((60, createMidiEvent(0x80, 43, 0)))   # G2 off
    events.add((61, createMidiEvent(0x80, 57, 0)))   # A3 off
    events.add((62, createMidiEvent(0x80, 60, 0)))   # C4 off
    events.add((63, createMidiEvent(0x80, 64, 0)))   # E4 off
    
    let (voices, controls) = toArrays(events, N=64, polyphony=8, aftertouch=true, 
                                   ccs=[ModWheel, Sustain, Program, Pressure, Bend, BendFine])
    
    # Test key checkpoints in the musical progression
    
    # Frame 0: Initial state with controls set
    check controls[0][0] == 64      # ModWheel initial
    check controls[1][0] == 127     # Sustain on
    check controls[2][0] == 42      # Program set
    check controls[3][0] == 80      # Channel pressure
    check controls[4][0] == 0       # Bend not set yet (default 0)
    check controls[5][0] == 0       # BendFine not set yet (default 0)
    
    # Frame 6: All three chord notes should be active
    check voices[0][0][6] == 60     # C4 in voice 0
    check voices[0][1][6] == 100    # velocity
    check voices[1][0][6] == 64     # E4 in voice 1
    check voices[1][1][6] == 95     # velocity
    check voices[2][0][6] == 67     # G4 in voice 2
    check voices[2][1][6] == 90     # velocity
    
    # Frame 12: After pitch bend and modwheel change
    check controls[0][12] == 80     # ModWheel increased
    check controls[4][12] == 80     # Bend MSB (0x50 = 80)
    check controls[5][12] == 32     # BendFine LSB (0x20 = 32)
    
    # Frame 16: Melody note starts
    check voices[3][0][16] == 72    # C5 in voice 3
    check voices[3][1][16] == 110   # velocity
    
    # Frame 24: D5 still playing (before note off at frame 25)
    check voices[3][0][24] == 74    # D5 still playing at frame 24
    check voices[3][1][24] == 105   # velocity maintained
    
    # Frame 30: After bass and controls
    check voices[4][0][30] == 48    # C3 bass note
    check voices[4][1][30] == 120   # bass velocity
    check controls[0][30] == 40     # ModWheel decreased
    
    # Frame 45: After chord release, before new chord
    check voices[0][0][45] == 0     # C4 released (voice inactive)
    check voices[1][0][45] == 0     # E4 released (voice inactive)  
    check voices[2][0][45] == 0     # G4 released (voice inactive)
    check voices[3][0][45] == 76    # E5 still playing
    check voices[4][0][45] == 43    # G2 bass note (changed)
    
    # Frame 50: New Am chord established
    check voices[0][0][50] == 57    # A3 in voice 0 (reused)
    check voices[1][0][50] == 60    # C4 in voice 1 (reused)
    check voices[2][0][50] == 64    # E4 in voice 2 (reused)
    
    # Frame 63: Final state - everything released
    check voices[0][0][63] == 0     # All voices released (inactive)
    check voices[1][0][63] == 0
    check voices[2][0][63] == 0
    check voices[3][0][63] == 0
    check voices[4][0][63] == 0
    check controls[0][63] == 0      # ModWheel at 0
    check controls[1][63] == 0      # Sustain off
    
    # Test aftertouch functionality
    check voices[0][2][10] == 50    # C4 aftertouch at frame 10
    check voices[0][2][9] == 0      # No aftertouch before
    check voices[0][2][11] == 50    # Forward-filled aftertouch
    
    # Verify control forward-filling works correctly
    # ModWheel should maintain value until next change
    check controls[0][7] == 64      # Initial value maintained
    check controls[0][8] == 80      # New value starts
    check controls[0][29] == 80     # Value maintained until frame 30
    check controls[0][30] == 40     # New value starts
    check controls[0][54] == 40     # Value maintained until frame 55
    
    # Verify pitch bend forward-filling
    check controls[4][11] == 0      # No bend before frame 12 (default 0)
    check controls[4][12] == 80     # Bend starts
    check controls[4][13] == 80     # Forward-filled
    check controls[4][62] == 80     # Still maintained at end
    
    echo "Complex musical scenario test completed successfully"
    echo "Verified: voice allocation, note tracking, control changes, aftertouch, forward-filling"

  test "Voice reuse and polyphony limits":
    var events: seq[(int, array[3, uint8])] = @[]
    
    # Fill all 8 voices then test reuse patterns
    for i in 0..7:
      events.add((i, createMidiEvent(0x90, uint8(60 + i), uint8(100 + i))))
    
    # Try to add 9th note (should be dropped)
    events.add((8, createMidiEvent(0x90, 69, 109)))
    
    # Release first 4 voices
    for i in 0..3:
      events.add((16 + i, createMidiEvent(0x80, uint8(60 + i), 0)))
    
    # Add 4 new notes (should reuse voices 0-3)
    for i in 0..3:
      events.add((24 + i, createMidiEvent(0x90, uint8(72 + i), uint8(110 + i))))
    
    let (voices, controls) = toArrays(events, N=32, polyphony=8, ccs=[ModWheel])
    
    # Verify initial 8 notes are allocated
    for i in 0..7:
      check voices[i][0][i + 1] == uint8(60 + i)    # Note appears after its frame
      check voices[i][1][i + 1] == uint8(100 + i)   # Velocity
    
    # Verify 9th note was dropped (no voice should have note 69)
    var foundNote69 = false
    for voice in 0..7:
      if voices[voice][0][9] == 69:
        foundNote69 = true
    check not foundNote69
    
    # Verify voice reuse after releases
    for i in 0..3:
      check voices[i][0][24 + i] == uint8(72 + i)   # New notes in reused voices
      check voices[i][1][24 + i] == uint8(110 + i)  # New velocities
    
    echo "Voice reuse and polyphony limit handling verified"

  test "Channel filtering with multiple channels":
    let events = [
      (0, createMidiEvent(0x90, 60, 100, 0)),   # Channel 0 - allowed
      (1, createMidiEvent(0x90, 62, 101, 1)),   # Channel 1 - filtered
      (2, createMidiEvent(0x90, 64, 102, 2)),   # Channel 2 - filtered  
      (3, createMidiEvent(0x90, 65, 103, 9)),   # Channel 9 - allowed
      (4, createMidiEvent(0x90, 67, 104, 15)),  # Channel 15 - filtered
      (5, createMidiEvent(0xB0, 1, 50, 0)),     # ModWheel ch 0 - allowed
      (6, createMidiEvent(0xB0, 1, 60, 1)),     # ModWheel ch 1 - filtered
      (7, createMidiEvent(0xB0, 1, 70, 9))      # ModWheel ch 9 - allowed
    ]
    
    let (voices, controls) = toArrays(events, N=16, polyphony=8, 
                                   ccs=[ModWheel], channels=[0'i8, 9'i8])
    
    # Only channels 0 and 9 should appear
    check voices[0][0][1] == 60     # Channel 0 note
    check voices[0][1][1] == 100    # Channel 0 velocity
    check voices[1][0][4] == 65     # Channel 9 note
    check voices[1][1][4] == 103    # Channel 9 velocity
    
    # Channels 1, 2, 15 should be completely absent
    var foundFilteredNotes = false
    for voice in 0..7:
      for frame in 0..15:
        if voices[voice][0][frame] in [62'u8, 64'u8, 67'u8]:
          foundFilteredNotes = true
    check not foundFilteredNotes
    
    # Control changes should also be filtered
    check controls[0][6] == 50      # ModWheel from ch 0
    check controls[0][8] == 70      # ModWheel from ch 9 (forward-filled from frame 7)
    
    echo "Multi-channel filtering verified for both notes and controls"

  test "Stress test: Rapid note changes":
    var events: seq[(int, array[3, uint8])] = @[]
    
    # Create rapid note on/off pattern
    for frame in 0..31:
      if frame mod 4 == 0:
        # Note on every 4 frames
        events.add((frame, createMidiEvent(0x90, uint8(60 + frame div 4), uint8(80 + frame))))
      elif frame mod 4 == 2:
        # Note off 2 frames later
        events.add((frame, createMidiEvent(0x80, uint8(60 + (frame - 2) div 4), 0)))
    
    let (voices, controls) = toArrays(events, N=32, polyphony=8, ccs=[ModWheel])
    
    # Verify rapid on/off pattern
    check voices[0][0][0] == 60     # First note on
    check voices[0][0][1] == 60     # Forward-filled
    check voices[0][0][2] == 0      # Note off (voice inactive)
    check voices[0][0][4] == 61     # Second note on (voice 0 reused)
    check voices[0][0][5] == 61     # Forward-filled
    check voices[0][0][6] == 0      # Note off (voice inactive)
    
    # By frame 16, we should have voice reuse
    check voices[0][0][16] == 64    # Voice 0 reused for 5th note
    
    echo "Rapid note change stress test completed"
