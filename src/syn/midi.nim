import macros

type
  ControlType* = enum
    # CC control messages (0-127)
    BankSelect = 0
    ModWheel = 1
    BreathController = 2
    FootController = 4
    Portamento = 5
    DataEntry = 6
    Volume = 7
    Balance = 8
    Pan = 10
    Expression = 11
    Sustain = 64
    Portamento2 = 65
    Sostenuto = 66
    SoftPedal = 67
    Legato = 68
    Hold2 = 69
    FilterResonance = 71
    ReleaseTime = 72
    AttackTime = 73
    FilterCutoff = 74
    Reverb = 91
    Tremolo = 92
    Chorus = 93
    Detune = 94
    Phaser = 95
    
    # MIDI event types (128+)
    NoteOff = 0x80
    NoteOn = 0x90
    Aftertouch = 0xA0
    Cc = 0xB0
    Program = 0xC0
    Pressure = 0xD0
    Bend = 0xE0
    BendFine = 0xF8    # Synthetic: fine pitch bend control


template type*(data: openArray[byte]): uint8 =
  uint8(data[0] and 0xF0)

template chan*(data: openArray[byte]): uint8 =
  uint8(data[0] and 0x0F)

template note*(data: openArray[byte]): uint8 =
  assert (data[0] and 0xF0) in [0x80'u8, 0x90'u8, 0xA0'u8]
  uint8(data[1])

template velocity*(data: openArray[byte]): uint8 =
  assert (data[0] and 0xF0) in [0x80'u8, 0x90'u8, 0xA0'u8]
  uint8(data[2])

template cc*(data: openArray[byte]): uint8 =
  assert (data[0] and 0xF0) == 0xB0
  uint8(data[1])

template val*(data: openArray[byte]): uint8 =
  assert (data[0] and 0xF0) == 0xB0
  uint8(data[2])

template program*(data: openArray[byte]): uint8 =
  assert (data[0] and 0xF0) == 0xC0
  uint8(data[1])

template bend*(data: openArray[byte]): uint16 =
  assert (data[0] and 0xF0) == 0xE0
  uint16(data[1]) or (uint16(data[2]) shl 7)

template `type=`*(data: var openArray[byte], value: uint8) =
  data[0] = uint8((value and 0xF0) or (data[0] and 0x0F))

template `chan=`*(data: var openArray[byte], value: range[0'u8..15'u8]) =
  data[0] = uint8((data[0] and 0xF0) or (value and 0x0F))

template `note=`*(data: var openArray[byte], value: range[0'u8..127'u8]) =
  assert (data[0] and 0xF0) in [0x80'u8, 0x90'u8, 0xA0'u8]
  data[1] = uint8(value)

template `velocity=`*(data: var openArray[byte], value: range[0'u8..127'u8]) =
  assert (data[0] and 0xF0) in [0x80'u8, 0x90'u8, 0xA0'u8]
  data[2] = uint8(value)

template `cc=`*(data: var openArray[byte], value: range[0'u8..127'u8]) =
  assert (data[0] and 0xF0) == 0xB0
  data[1] = uint8(value)

template `val=`*(data: var openArray[byte], value: range[0'u8..127'u8]) =
  assert (data[0] and 0xF0) == 0xB0
  data[2] = uint8(value)

template `program=`*(data: var openArray[byte], value: range[0'u8..127'u8]) =
  assert (data[0] and 0xF0) == 0xC0
  data[1] = uint8(value)

template `bend=`*(data: var openArray[byte], value: range[0'u16..16383'u16]) =
  assert (data[0] and 0xF0) == 0xE0
  data[1] = uint8(value and 0x7F)
  data[2] = uint8((value shr 7) and 0x7F)


template isSysEx*(data: openArray[byte]): bool =
  data[0] == 0xF0 and data[^1] == 0xF7

template manufacturerId*(data: openArray[byte]): uint8 =
  assert data.isSysEx
  data[1]

template sysExData*(data: openArray[byte]): openArray[byte] =
  assert data.isSysEx
  data[2..^2]


proc `$`*(data: openArray[byte]): string {.used.} =
  if data.len == 0:
    return "Empty MIDI Event"
  
  if data.isSysEx:
    return "SysEx (manufacturer: " & $data.manufacturerId & ", " & $(data.len - 3) & " data bytes)"
  
  let eventType = data.type
  let channel = data.chan
  
  # Use automatic string representation for ControlType enum
  if eventType >= 0x80'u8:  # MIDI event type
    try:
      let controlType = ControlType(eventType)
      case controlType:
      of NoteOff: 
        return $controlType & "(ch=" & $channel & ", note=" & $data.note & ", vel=" & $data.velocity & ")"
      of NoteOn: 
        return $controlType & "(ch=" & $channel & ", note=" & $data.note & ", vel=" & $data.velocity & ")"
      of Aftertouch: 
        return $controlType & "(ch=" & $channel & ", note=" & $data.note & ", pressure=" & $data.velocity & ")"
      of Cc: 
        return $controlType & "(ch=" & $channel & ", cc=" & $data.cc & ", val=" & $data.val & ")"
      of Program: 
        return $controlType & "(ch=" & $channel & ", program=" & $data.program & ")"
      of Pressure: 
        return $controlType & "(ch=" & $channel & ", pressure=" & $data[1] & ")"
      of Bend: 
        return $controlType & "(ch=" & $channel & ", bend=" & $data.bend & ")"
      else:
        return $controlType & "(type=" & $eventType & ", " & $data.len & " bytes)"
    except:
      return "Unknown MIDI Event(type=" & $eventType & ", " & $data.len & " bytes)"
  else:
    return "Unknown Event(type=" & $eventType & ", " & $data.len & " bytes)"

macro unrolledFind*(arr: typed, val: typed): untyped =
  let arrType = arr.getType()
  if arrType.kind != nnkBracketExpr or arrType[1].kind != nnkIntLit:
    return quote do: `arr`.find(`val`)

  result = newNimNode(nnkIfStmt)
  for i in 0..<arrType[1].intVal.int:
    result.add newNimNode(nnkElifBranch).add(
      newNimNode(nnkInfix).add(newIdentNode("=="), newNimNode(nnkBracketExpr).add(arr, newLit(i)), val),
      newLit(i))
  result.add newNimNode(nnkElse).add(newLit(-1))

macro jumpFind*(arr: typed, val: typed): untyped =
  ## Optimized find for static arrays using case statements
  let arrType = arr.getType()
  if arrType.kind != nnkBracketExpr or arrType[1].kind != nnkIntLit:
    return quote do: `arr`.find(`val`)

  result = newNimNode(nnkCaseStmt)
  result.add(val)
  
  for i in 0..<arrType[1].intVal.int:
    let branch = newNimNode(nnkOfBranch)
    branch.add(newNimNode(nnkBracketExpr).add(arr, newLit(i)))
    branch.add(newLit(i))
    result.add(branch)
  
  result.add newNimNode(nnkElse).add(newLit(-1))

# Array-based polyphonic MIDI processing with voice allocation  
proc toArrays*[F, D](
  events: openArray[(F, D)],
  N: static int,
  polyphony: static int = 8,
  aftertouch: static bool = false,
  ccs: static array = [Sustain, Bend, BendFine],
  channels: static openArray[int8] = []
): auto {.noinit.} =
  ## Generates polyphonic MIDI arrays from an array of (frame, midi_data) tuples.
  ## Each tuple should be (SomeInt, array[3, uint8]) where:
  ## - SomeInt is the frame number
  ## - array[3, uint8] is the MIDI data [status_byte, data1, data2]
  ## Returns (noteData, globalData) where:
  ## - noteData: [voice][data][sample] as uint8 values  
  ## - globalData: [control][sample] as uint8 values for specified global controls
  ## Uses 0xFF as sentinel (MIDI is 7-bit (0-127) anyway).
  
  const sentinel = high(uint8)  # 0xFF, MSB set
  
  result = (default(array[polyphony, array[2 + (when aftertouch: 1 else: 0), array[N, uint8]]]), 
            default(array[ccs.len, array[N, uint8]]))
  
  
  # Voice allocation state - note 0 = inactive, note > 0 = active with that note
  var notes: array[polyphony, uint8]
  
  # Initialize voice data with sentinel values
  for voiceId in 0..<polyphony:
    for frame in 0..<N:
      result[0][voiceId][0][frame] = sentinel  # note
      result[0][voiceId][1][frame] = sentinel  # velocity
      when aftertouch:
        result[0][voiceId][2][frame] = sentinel  # aftertouch
  
  # Initialize global data with sentinel values  
  for cc in 0..<ccs.len:
    for sample in 0..<N:
      result[1][cc][sample] = sentinel
  
    
  # Apply sparse MIDI events with voice allocation
  for eventTuple in events:
    let frame = int(eventTuple[0])
    let data = eventTuple[1]
    
    if frame < N:
      # Channel filtering
      when channels.len > 0:
        var found = false
        for allowedChannel in channels:
          if (data[0] and 0x0F) == uint8(allowedChannel):
            found = true
            break
        if not found:
          continue
      
      let eventType = uint8(data[0] and 0xF0)  # Get status byte without channel
      case eventType:
      of NoteOn.uint8:
          if data[2] > 0:  # Real note on (velocity > 0)
            let freeVoice = unrolledFind(notes, 0'u8)
            if freeVoice >= 0:
              notes[freeVoice] = uint8(data[1])
              result[0][freeVoice][0][frame] = uint8(data[1])  # note
              result[0][freeVoice][1][frame] = uint8(data[2])  # velocity
              when aftertouch:
                result[0][freeVoice][2][frame] = 0  # No aftertouch yet
            # else: TODO: warn about dropped note - no available voices
          else:  # Velocity 0 = note off
            let voiceNum = unrolledFind(notes, uint8(data[1]))
            if voiceNum >= 0:
              notes[voiceNum] = 0
              result[0][voiceNum][0][frame] = 0
              result[0][voiceNum][1][frame] = 0
              when aftertouch:
                result[0][voiceNum][2][frame] = 0
        
      of NoteOff.uint8:
          let voiceNum = unrolledFind(notes, uint8(data[1]))
          if voiceNum >= 0:
            notes[voiceNum] = 0
            result[0][voiceNum][0][frame] = 0
            result[0][voiceNum][1][frame] = 0
            when aftertouch:
              result[0][voiceNum][2][frame] = 0
        
      of Aftertouch.uint8:
          when aftertouch:
            let voiceNum = unrolledFind(notes, uint8(data[1]))
            if voiceNum >= 0:
              result[0][voiceNum][2][frame] = uint8(data[2])
              
      of Cc.uint8:
          let controlIndex = jumpFind(ccs, ControlType(data[1]))
          if controlIndex >= 0:
            result[1][controlIndex][frame] = uint8(data[2])
              
      of Program.uint8:
          let controlIndex = jumpFind(ccs, Program)
          if controlIndex >= 0:
            result[1][controlIndex][frame] = uint8(data[1])
              
      of Pressure.uint8:
          let controlIndex = jumpFind(ccs, Pressure)
          if controlIndex >= 0:
            result[1][controlIndex][frame] = uint8(data[1])
              
      of Bend.uint8:
          let bendIndex = jumpFind(ccs, Bend)
          if bendIndex >= 0:
            result[1][bendIndex][frame] = uint8(data[2])     # MSB as main bend control
          let bendFineIndex = jumpFind(ccs, BendFine)
          if bendFineIndex >= 0:
            result[1][bendFineIndex][frame] = uint8(data[1]) # LSB as fine control
        
      else:
          discard  # Ignore other MIDI events
  
  # Forward fill pass - maintain voice state until next event
  for i in 0..<polyphony:
    var lastNote: uint8 = 0
    var lastVelocity: uint8 = 0
    when aftertouch:
      var lastAftertouch: uint8 = 0
    
    for frame in 0..<N:
      # Handle aftertouch updates first (independent of note events)
      when aftertouch:
        if result[0][i][2][frame] != sentinel:
          lastAftertouch = result[0][i][2][frame]
      
      # Check if this sample has new data for this voice
      if result[0][i][0][frame] != sentinel:  # Non-sentinel = actual event data
        lastNote = result[0][i][0][frame]
        lastVelocity = result[0][i][1][frame]
        when aftertouch:
          if result[0][i][2][frame] == sentinel:
            # Note event but no aftertouch - preserve existing aftertouch
            result[0][i][2][frame] = lastAftertouch
      else:
        # Fill with last known values
        result[0][i][0][frame] = lastNote
        result[0][i][1][frame] = lastVelocity
        when aftertouch:
          result[0][i][2][frame] = lastAftertouch
  
  # Forward fill pass for global controls
  for cc in 0..<ccs.len:
    var lastCc: uint8 = 0
    
    for frame in 0..<N:
      if result[1][cc][frame] != sentinel:  # Non-sentinel = actual event data
        lastCc = result[1][cc][frame]
      else:
        # Fill with last known value (0 if no data yet)
        result[1][cc][frame] = lastCc
