function Invoke-GeminiAPI {
    param(
        [Parameter(Mandatory)]
        [string]$Instructions,

        [Parameter(Mandatory)]
        [string]$UserInput
    )

    $API_KEY = $env:GeminiKey
    if (-not $API_KEY) {
        Write-Error "API key is missing. Please set the 'GeminiKey' environment variable."
        return
    }

    $Body = @{
        contents = @(
            @{
                role  = 'model'
                parts = @(@{ text = $Instructions })
            },
            @{
                role  = 'user'
                parts = @(@{ text = $UserInput })
            }
        )
    } | ConvertTo-Json -Depth 6

    $Url = "https://generativelanguage.googleapis.com/v1/models/gemini-pro:generateContent?key=$API_KEY"

    try {
        Invoke-RestMethod -Uri $Url -Method Post -ContentType 'application/json' -Body $Body
    } catch {
        Write-Error "Failed to invoke Gemini API: $_"
    }
}

function Invoke-GeminiAI {
    param(
        [Parameter(Mandatory)]
        [string]$UserInput,

        [Parameter(Mandatory)]
        [string]$Instructions
    )

    $response = Invoke-GeminiAPI -Instructions $Instructions -UserInput $UserInput
    if (-not $response) { return }

    $contentText = $response.candidates[0].content.parts[0].text

    # Check if 'glow' is available for markdown rendering
    if (Get-Command -Name glow -ErrorAction SilentlyContinue) {
        $contentText | glow
    } else {
        $contentText
    }
}

Import-Module "$PSScriptRoot\..\PSYT.psm1"

$Instructions = @'
Summarize the key points of this video transcript,
'@

# Source: https://www.youtube.com/watch?v=7hNbYOjh-1k
$geminiParams = @{
    Instructions = $Instructions
    UserInput    = (Get-Transcript -videoId '7hNbYOjh-1k' | ConvertTo-Csv | Out-String)
}

Invoke-GeminiAI @geminiParams