import pixie
export pixie

proc plot*(callback: proc(phase: uint): float32, width: int = 300, height: int = 300): Image =
  ## Plot a waveform callback function to a 2-bit image
  ## Returns a pixie Image that can be saved or processed further
  result = newImage(width, height)
  result.fill(color(1, 1, 1, 1))  # White background
  
  let centerY = height.float32 / 2.0
  let maxAmplitude = centerY
  
  # Sample the waveform across the full phase range
  for x in 0..<width:
    # Map x coordinate to phase value (0 to high(uint))
    let phase = uint((x.float64 / width.float64) * high(uint).float64)
    
    # Get the waveform value (-1.0 to 1.0)
    let value = callback(phase)
    
    # Map value to y coordinate (flip y-axis so -1 is at bottom)
    # Use floating-point arithmetic for better precision
    let y = centerY - (value * maxAmplitude)
    
    # Clamp y to image bounds
    let clampedY = max(0, min(height - 1, int(y.round)))
    
    # Draw the point
    result[x, clampedY] = color(0, 0, 0, 1)  # Black point