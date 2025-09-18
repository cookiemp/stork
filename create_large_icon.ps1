# PowerShell script to create a large Windows ICO file
# This creates an ICO file with multiple resolutions including high-DPI sizes

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

# Load the source PNG image
$sourceImage = [System.Drawing.Image]::FromFile("$PWD\stork.png")

# Create a new icon with multiple sizes
$sizes = @(16, 24, 32, 48, 64, 96, 128, 256)
$iconImages = @()

foreach ($size in $sizes) {
    # Create a new bitmap of the target size
    $bitmap = New-Object System.Drawing.Bitmap($size, $size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    
    # Set high quality rendering
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    
    # Draw the resized image
    $graphics.DrawImage($sourceImage, 0, 0, $size, $size)
    
    # Convert to icon format
    $iconHandle = $bitmap.GetHicon()
    $icon = [System.Drawing.Icon]::FromHandle($iconHandle)
    
    $iconImages += $icon
    
    $graphics.Dispose()
    $bitmap.Dispose()
}

# Save as high-quality ICO file
$iconImages[7].Save("$PWD\stork_large.ico")

# Clean up
$sourceImage.Dispose()
foreach ($icon in $iconImages) {
    $icon.Dispose()
}

Write-Host "Created stork_large.ico with high resolution"