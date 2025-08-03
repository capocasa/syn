import unittest
import ../src/syn/input

# Helper to create test MIDI events
proc createMidiEvent(eventType: uint8, data1: uint8, data2: uint8, channel: uint8 = 0): array[3, uint8] =
  result[0] = eventType or channel
  result[1] = data1
  result[2] = data2

suite "MIDI toArrayFromEvents Tests":
  
  test "Basic note on/off":
    let events = [
      (1, createMidiEvent(0x90, 60, 100)),  # Note on C4 (60) at frame 1, velocity 100
      (3, createMidiEvent(0x80, 60, 0))     # Note off C4 at frame 3  
    ]
    
    let (voices, controls) = toArrayFromEvents(events, N=4, polyphony=2)
    
    # Check voice 0 gets the note: frame 0=0, frame 1=note on, frame 2=hold, frame 3=note off
    check voices[0][0] == [0'u8, 60, 60, 0]      # notes
    check voices[0][1] == [0'u8, 100, 100, 0]    # velocities
    
    # Check voice 1 stays empty
    check voices[1][0] == [0'u8, 0, 0, 0]        # notes
    check voices[1][1] == [0'u8, 0, 0, 0]        # velocities

  test "Polyphonic notes":
    let events = [
      (0, createMidiEvent(0x90, 60, 80)),   # Note on C4 at frame 0
      (1, createMidiEvent(0x90, 64, 90)),   # Note on E4 at frame 1  
      (2, createMidiEvent(0x80, 60, 0))     # Note off C4 at frame 2
    ]
    
    let (voices, controls) = toArrayFromEvents(events, N=4, polyphony=2)
    
    # Voice 0: C4 from frame 0-2, then off
    check voices[0][0] == [60'u8, 60, 0, 0]      # notes
    check voices[0][1] == [80'u8, 80, 0, 0]      # velocities
    
    # Voice 1: E4 from frame 1 onwards
    check voices[1][0] == [0'u8, 64, 64, 64]     # notes  
    check voices[1][1] == [0'u8, 90, 90, 90]     # velocities

  test "Control changes":
    let events = [
      (1, createMidiEvent(0xB0, 1, 50)),    # ModWheel (CC 1) = 50 at frame 1
      (2, createMidiEvent(0xB0, 7, 127)),   # Volume (CC 7) = 127 at frame 2
      (3, createMidiEvent(0xC0, 42, 0))     # Program change to 42 at frame 3
    ]
    
    let (voices, controls) = toArrayFromEvents(events, N=4, polyphony=2, ccs=[ModWheel, Volume, Program])
    
    check controls[0] == [0'u8, 50, 50, 50]          # ModWheel
    check controls[1] == [0'u8, 0, 127, 127]         # Volume
    check controls[2] == [0'u8, 0, 0, 42]            # Program

  test "Pitch bend":
    let events = [
      (1, createMidiEvent(0xE0, 0x20, 0x50))  # Pitch bend: LSB=0x20, MSB=0x50 at frame 1
    ]
    
    let (voices, controls) = toArrayFromEvents(events, N=4, polyphony=2)
    
    check controls[1] == [0'u8, 80, 80, 80]          # Bend (MSB=0x50=80) - index 1 in default [Sustain, Bend, BendFine]
    check controls[2] == [0'u8, 32, 32, 32]          # BendFine (LSB=0x20=32) - index 2

  test "Channel filtering":
    let events = [
      (0, createMidiEvent(0x90, 60, 100, 0)),  # Note on channel 0
      (1, createMidiEvent(0x90, 64, 110, 1)),  # Note on channel 1 (should be filtered out)
      (2, createMidiEvent(0x90, 67, 120, 0))   # Note on channel 0 again
    ]
    
    let (voices, controls) = toArrayFromEvents(events, N=4, polyphony=2, channels=[0'i8])
    
    # Only channel 0 events should be processed (E4 on channel 1 filtered out)
    check voices[0][0] == [60'u8, 60, 60, 60]        # C4 in voice 0 (channel 0)
    check voices[0][1] == [100'u8, 100, 100, 100]    # velocity
    check voices[1][0] == [0'u8, 0, 67, 67]          # G4 in voice 1 (channel 0)
    check voices[1][1] == [0'u8, 0, 120, 120]        # velocity

  test "Aftertouch":
    let events = [
      (0, createMidiEvent(0x90, 60, 100)),  # Note on C4
      (2, createMidiEvent(0xA0, 60, 75))    # Poly aftertouch for C4 at frame 2
    ]
    
    let (voices, controls) = toArrayFromEvents(events, N=4, polyphony=2, aftertouch=true)
    
    check voices[0][0] == [60'u8, 60, 60, 60]        # notes
    check voices[0][1] == [100'u8, 100, 100, 100]    # velocities  
    check voices[0][2] == [0'u8, 0, 75, 75]          # aftertouch (0 initially, then 75)

  test "Voice dropping when full":
    let events = [
      (0, createMidiEvent(0x90, 60, 100)),  # Voice 0
      (1, createMidiEvent(0x90, 64, 110)),  # Voice 1  
      (2, createMidiEvent(0x90, 67, 120))   # Should be dropped
    ]
    
    let (voices, controls) = toArrayFromEvents(events, N=4, polyphony=2)
    
    # Should only have two voices active, third note dropped
    check voices[0][0] == [60'u8, 60, 60, 60]        # C4 in voice 0
    check voices[0][1] == [100'u8, 100, 100, 100]    # velocity
    check voices[1][0] == [0'u8, 64, 64, 64]         # E4 in voice 1  
    check voices[1][1] == [0'u8, 110, 110, 110]      # velocity
    # G4 should be dropped - no evidence in either voice

  test "Note on velocity 0 equals note off":
    let events = [
      (0, createMidiEvent(0x90, 60, 100)),  # Note on C4
      (2, createMidiEvent(0x90, 60, 0))     # Note on with velocity 0 (equals note off)
    ]
    
    let (voices, controls) = toArrayFromEvents(events, N=4, polyphony=2)
    
    check voices[0][0] == [60'u8, 60, 0, 0]          # Note on then off
    check voices[0][1] == [100'u8, 100, 0, 0]        # Velocity persists then off

  test "Channel pressure":
    let events = [
      (1, createMidiEvent(0xD0, 90, 0))  # Channel pressure at frame 1
    ]
    
    let (voices, controls) = toArrayFromEvents(events, N=4, polyphony=2, ccs=[Pressure, Bend, BendFine])
    
    check controls[0] == [0'u8, 90, 90, 90]          # Channel pressure

  test "Multiple channels filter":
    let events = [
      (0, createMidiEvent(0x90, 60, 100, 0)),  # Channel 0 - allowed
      (1, createMidiEvent(0x90, 64, 110, 1)),  # Channel 1 - filtered  
      (2, createMidiEvent(0x90, 67, 120, 9))   # Channel 9 - allowed
    ]
    
    let (voices, controls) = toArrayFromEvents(events, N=4, polyphony=2, channels=[0'i8, 9'i8])
    
    # Should only see channels 0 and 9
    check voices[0][0] == [60'u8, 60, 60, 60]        # Channel 0 note
    check voices[1][0] == [0'u8, 0, 67, 67]          # Channel 9 note
    # Channel 1 note should be completely absent