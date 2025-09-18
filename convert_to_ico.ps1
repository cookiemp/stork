# Convert PNG to ICO with high quality
Add-Type -AssemblyName System.Drawing

# Load the PNG image
$png = [System.Drawing.Image]::FromFile("$PWD\stork.png")

# Create a bitmap from the PNG
$bitmap = New-Object System.Drawing.Bitmap($png)

# Get the icon handle
$hIcon = $bitmap.GetHicon()

# Create icon from handle
$icon = [System.Drawing.Icon]::FromHandle($hIcon)

# Save to file stream
$fileStream = [System.IO.File]::Create("$PWD\stork_high_res.ico")
$icon.Save($fileStream)
$fileStream.Close()

# Clean up
$icon.Dispose()
$bitmap.Dispose()
$png.Dispose()

Write-Host "Converted stork.png to stork_high_res.ico"