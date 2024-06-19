function Invoke-GeminiAI {
    param(
        [Parameter(Mandatory)]
        [string]$UserInput,

        [Parameter(Mandatory)]
        [string]$Instructions
    )

    function Invoke-GeminiAPI {
        param(
            [string]$Instructions,
            [string]$UserInput
        )

        $API_KEY = $env:GeminiKey
        if (-not $API_KEY) {
            Write-Error "API key is missing. Please set the 'GeminiKey' environment variable."
            return
        }

        $Headers = @{
            'Content-Type' = 'application/json'
        }

        $Body = @{
            contents = @(
                @{
                    role  = 'model'
                    parts = @(
                        @{
                            'text' = $Instructions
                        }
                    )
                },
                @{
                    role  = 'user'
                    parts = @(
                        @{
                            'text' = $UserInput
                        }
                    )
                }
            )
        } | ConvertTo-Json -Depth 6

        $Url = "https://generativelanguage.googleapis.com/v1/models/gemini-pro:generateContent?key=$API_KEY"

        try {
            $response = Invoke-RestMethod -Uri $Url -Method Post -Headers $Headers -Body $Body
            return $response
        } catch {
            Write-Error "Failed to invoke Gemini API: $_"
        }
    }

    # Check if 'glow' is available
    $useGlow = Get-Command -Name glow -ErrorAction SilentlyContinue

    $response = Invoke-GeminiAPI -Instructions $Instructions -UserInput $UserInput

    if ($response) {
        $contentText = $response.candidates[0].content.parts[0].text
        if ($useGlow) {
            $contentText | glow
        } else {
            $contentText
        }
    }
}

Import-Module "$PSScriptRoot\..\PSYT.psm1"

# Ref: https://github.com/danielmiessler/fabric/blob/main/patterns/extract_insights/system.md
$Instructions = @'
Summarize the key points of this video transcript,
'@

# Source: https://www.youtube.com/watch?v=7hNbYOjh-1k
$geminiParams = @{
    Instructions = $Instructions
    UserInput    = (Get-Transcript -videoId '7hNbYOjh-1k' | ConvertTo-Csv | Out-String)
}

Invoke-GeminiAI @geminiParams