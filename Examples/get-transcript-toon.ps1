# Example: Get YouTube transcript in TOON format
# TOON (Token-Oriented Object Notation) is a compact, human-readable format
# designed for LLM prompts. See: https://github.com/toon-format/toon

Import-Module "$PSScriptRoot\..\PSYT.psm1" -Force

# Get transcript in TOON format
# Source: https://www.youtube.com/watch?v=GikIJpUv6oo
$transcriptParams = @{
    videoId            = 'GikIJpUv6oo'
    IncludeTitle       = $true
    IncludeDescription = $true
    OutputFormat       = 'TOON'
}

$toonTranscript = Get-Transcript @transcriptParams

# Display the TOON formatted output
Write-Host "`nTOON Format Output:" -ForegroundColor Green
Write-Host "==================`n" -ForegroundColor Green
$toonTranscript

# The TOON format is optimized for LLM consumption:
# - Uses tabular format for uniform arrays (transcript entries)
# - Explicitly declares array length and field names
# - Uses CSV-style rows for compact representation
# - Perfect for feeding to AI models with minimal token usage
