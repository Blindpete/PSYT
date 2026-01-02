<#
.SYNOPSIS
This module contains functions to work with YouTube video IDs and retrieve video transcripts.

.DESCRIPTION
The PSYT module provides functions to validate YouTube video IDs, retrieve the HTML content of a YouTube video page, get language options with links for video captions, and retrieve the transcript of a YouTube video.

.FUNCTIONS
1. Test-YouTubeVideoId
    - Validates a string to check if it contains a valid YouTube video ID.
    - Returns the video ID if found, or an empty array if no valid video ID is found.

2. Get-VideoPageHtml
    - Retrieves the HTML content of a YouTube video page using the video ID.
    - Returns the HTML content if successful, or null if failed.

3. Get-LangOptionsWithLink
    - Retrieves the language options with links for video captions using the video ID.
    - Returns an array of objects containing the video title, description, language, and link for each language option.

4. Get-RawTranscript
    - Retrieves the raw transcript of a YouTube video using the caption link.
    - Returns an array of objects containing the start time, duration, and text of each transcript part.

5. Get-Transcript
    - Retrieves the transcript of a YouTube video using the video ID.
    - Returns an object containing the video title, description, language, and transcript parts.
    - Optional parameters: IncludeTitle, IncludeDescription, OutputFormat.
    - Supports three output formats: PSObject, Markdown (default), and TOON.
    - TOON (Token-Oriented Object Notation) is a compact format optimized for LLM consumption.


.PARAMETER videoId
The YouTube video ID or YouTube Url.

.PARAMETER IncludeTitle
Specifies whether to include the video title in the transcript object. Default is false.

.PARAMETER IncludeDescription
Specifies whether to include the video description in the transcript object. Default is false.

.PARAMETER OutputFormat
Specifies the output format: PSObject, Markdown (default), or TOON. TOON format is optimized for LLM prompts with minimal token usage.

.EXAMPLE
PS C:\> Test-YouTubeVideoId -InputString "https://www.youtube.com/watch?v=vc79sJ9VOqk"
Returns: "vc79sJ9VOqk"

.EXAMPLE
PS C:\> Get-Transcript -videoId "GikIJpUv6oo" -IncludeTitle -IncludeDescription
Returns: Markdown formatted transcript with title, description, and transcript table.

.EXAMPLE
PS C:\> Get-Transcript -videoId "GikIJpUv6oo" -OutputFormat PSObject
Returns: PowerShell object containing the video language and transcript parts.

.EXAMPLE
PS C:\> Get-Transcript -videoId "GikIJpUv6oo" -IncludeTitle -OutputFormat TOON
Returns: TOON formatted transcript optimized for LLM consumption.

.NOTES
This module requires the Invoke-WebRequest cmdlet to be available.

.LINK
GitHub: https://github.com/Blindpete/PSYT

#>
function Test-YouTubeVideoId {
    param (
        [string]$InputString
    )

    # Regular expression pattern for YouTube video ID
    $pattern = '(?:https?:\/\/)?(?:www\.)?(?:youtube\.com|youtu\.be)\/(?:watch\?v=)?(?:embed\/)?(?:v\/)?(?:shorts\/)?(?:\S*[^\w\-\s])?(?<id>[\w\-]{11})(?:\S*)?'

    if ($InputString -match $pattern) {
        $videoId = $matches['id']
        Write-Verbose "Valid YouTube video ID found: $videoId"
        return $videoId
    } elseif ($InputString -match '^[\w\-]{11}$') {
        Write-Verbose "Valid YouTube video ID format: $InputString"
        return $InputString
    } else {
        Write-Verbose 'No valid YouTube video ID found in the string.'
        return @()
    }
}

function Get-PSYTWebSession {
    [CmdletBinding()]
    param()

    if (-not $script:PSYT_WebSession) {
        $script:PSYT_WebSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    }

    return $script:PSYT_WebSession
}

function Get-PSYTHeaders {
    [CmdletBinding()]
    param()

    # Keep this lightweight but "browser-like" enough for YouTube to return the expected payloads.
    return @{
        'Accept-Language' = 'en-US,en;q=0.9'
        'Accept'          = 'application/xml,text/xml,text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8'
        'User-Agent'      = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    }
}

function Set-PSYTConsentCookie {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,

        [Parameter(Mandatory)]
        [string]$ConsentValue
    )

    try {
        $cookie = New-Object System.Net.Cookie
        $cookie.Name = 'CONSENT'
        $cookie.Value = "YES+$ConsentValue"
        $cookie.Path = '/'
        $cookie.Domain = '.youtube.com'
        $WebSession.Cookies.Add($cookie)
    } catch {
        # Best-effort; if this fails, the subsequent request will still indicate consent is required.
        Write-Debug "Failed to set CONSENT cookie: $($_.Exception.Message)"
    }
}

function Get-PSYTInnertubeApiKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Html
    )

    $match = [regex]::Match($Html, '"INNERTUBE_API_KEY":\s*"([a-zA-Z0-9_-]+)"')
    if ($match.Success -and $match.Groups.Count -ge 2) {
        return $match.Groups[1].Value
    }

    return $null
}

function Get-PSYTInnertubeData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$VideoId,

        [Parameter(Mandatory)]
        [string]$ApiKey,

        [Parameter(Mandatory)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,

        [Parameter(Mandatory)]
        [hashtable]$Headers
    )

    $uri = "https://www.youtube.com/youtubei/v1/player?key=$ApiKey"
    $body = @{
        context = @{
            client = @{
                clientName    = 'ANDROID'
                clientVersion = '20.10.38'
            }
        }
        videoId = $VideoId
    } | ConvertTo-Json -Compress

    try {
        return Invoke-RestMethod -Method Post -Uri $uri -WebSession $WebSession -Headers $Headers -ContentType 'application/json' -Body $body -SkipHttpErrorCheck
    } catch {
        throw "Failed to fetch Innertube player data: $($_.Exception.Message)"
    }
}

function Get-VideoPageHtml {
    param (
        [string]$videoId
    )

    try {
        $session = Get-PSYTWebSession
        $headers = Get-PSYTHeaders

        $response = Invoke-WebRequest -Uri "https://www.youtube.com/watch?v=$videoId" -WebSession $session -Headers $headers -SkipHttpErrorCheck
        $html = $response.Content

        # If YouTube serves a consent page, set the CONSENT cookie and retry once (mirrors youtube-transcript-api behavior).
        if ($html -match 'action="https://consent\.youtube\.com/s"') {
            $consentMatch = [regex]::Match($html, 'name="v"\s+value="(.*?)"')
            if ($consentMatch.Success -and $consentMatch.Groups.Count -ge 2) {
                Set-PSYTConsentCookie -WebSession $session -ConsentValue $consentMatch.Groups[1].Value
                $response = Invoke-WebRequest -Uri "https://www.youtube.com/watch?v=$videoId" -WebSession $session -Headers $headers -SkipHttpErrorCheck
                $html = $response.Content
            } else {
                Write-Host "Failed to auto-consent to cookies for video ID: $videoId"
                return $null
            }

            if ($html -match 'action="https://consent\.youtube\.com/s"') {
                Write-Host "Failed to auto-consent to cookies for video ID: $videoId"
                return $null
            }
        }
        # Check if the HTML content contains the video URL: <meta property="og:url" content="https://www.youtube.com/watch?v=GikIJpUv6oo">
        if ($html -match 'og:url') {
            # Check if the HTML content contains 'class="g-recaptcha"'
            if ($html -match 'class="g-recaptcha"') {
                Write-Host "Failed to get the HTML content Too Many Requests for video ID: $videoId"
                return $null
            }
            # Check if the HTML content contains '"playabilityStatus":'
            if ($html -notmatch '"playabilityStatus":') {
                Write-Host "Failed to get the HTML content Video Unavailable for video ID: $videoId"
                return $null
            }
            return $html
        } else {
            Write-Host "Failed to get the HTML content for video ID: $videoId"
            return $null
        }      
    } catch {
        Write-Host "Failed to get the HTML content for video ID: $videoId"
        return $null
    }
}

# Function to get language options with links
function Get-LangOptionsWithLink {
    param (
        [string]$videoId
    )

    $videoPageHtml = Get-VideoPageHtml -videoId $videoId
    if (-not $videoPageHtml) {
        Write-Host 'Failed to get video page HTML'
        return @()
    }

    # Match youtube-transcript-api: extract INNERTUBE_API_KEY from HTML then call Innertube player API
    # to get fresh caption tracks (avoids links which may require PO tokens / return empty bodies).
    $session = Get-PSYTWebSession
    $headers = Get-PSYTHeaders

    $apiKey = Get-PSYTInnertubeApiKey -Html $videoPageHtml
    if (-not $apiKey) {
        Write-Host 'Error parsing INNERTUBE API key'
        return @()
    }

    try {
        $innertubeData = Get-PSYTInnertubeData -VideoId $videoId -ApiKey $apiKey -WebSession $session -Headers $headers
        $captions = $innertubeData.captions.playerCaptionsTracklistRenderer
        if (-not $captions -or -not $captions.captionTracks) {
            Write-Host 'No Caption Available'
            return @()
        }

        $videoDetailsJson = $innertubeData.videoDetails
        # Extract the caption tracks: baseUrl=/api/timedtext?... this url does expire after some time
        $captionTracks = $captions.captionTracks
        # This will give the language options
        # if $_.name.runs.text else $_.name.simpleText

        $languageOptions = $captionTracks | ForEach-Object { 
            if ($_.name.runs.text) {
                $_.name.runs.text 
            } else {
                $_.name.simpleText 
            } }

        # Looks like most will be 'English (auto-generated)' and 'English' azurming this is manuly created, so the one we want over auto-generated
        $languageOptions = $languageOptions | Sort-Object {
            if ($_ -eq 'English') {
                return -1 
            } elseif ($_ -match 'English') {
                return 0 
            } else {
                return 1 
            }
        }

        $languageOptionsWithLink = $languageOptions | ForEach-Object {
            $langName = $_
            # $link = ($captionTracks | Where-Object { $_.name.runs[0].text -or $_.name.simpleText -eq $langName }).baseUrl
            $link = $captionTracks | ForEach-Object {
                $name = if ($_.name.runs) { $_.name.runs[0].text } else { $_.name.simpleText }
                if ($name -eq $langName) {
                    # Mirror youtube-transcript-api behavior: remove fmt=srv3, which can trigger PO-token requirements / odd responses.
                    ($_.baseUrl -replace '&fmt=srv3', '')
                }
            } | Select-Object -First 1
            [PSCustomObject]@{
                title       = $videoDetailsJson.title
                description = $videoDetailsJson.shortDescription
                language    = $langName
                link        = $link
            }
        }

        return $languageOptionsWithLink
    } catch {
        Write-Host 'Error parsing captions JSON'
        return @()
    }
}
function Get-RawTranscript {
    param (
        [string]$link
    )

    if (-not $link.StartsWith('https://www.youtube.com')) {
        $uri = ('https://www.youtube.com{0}' -f $link)
    } else {
        $uri = $link
    }

    # Align request behavior with youtube-transcript-api: keep cookies + headers consistent, and validate response before parsing XML.
    $session = Get-PSYTWebSession
    $headers = Get-PSYTHeaders

    $transcriptPageResponse = Invoke-WebRequest -Uri $uri -WebSession $session -Headers $headers -SkipHttpErrorCheck

    if ($transcriptPageResponse.StatusCode -eq 429) {
        throw "YouTube is rate-limiting or blocking requests (HTTP 429) when fetching timedtext. Try again later or from a different network/IP."
    }

    $content = $transcriptPageResponse.Content
    if ([string]::IsNullOrWhiteSpace($content)) {
        throw "Timedtext returned an empty response body. This usually means the request was blocked, the caption URL expired, or captions are unavailable."
    }

    $trimmed = $content.TrimStart()
    if ($trimmed.StartsWith('<!DOCTYPE html', [System.StringComparison]::OrdinalIgnoreCase) -or
        $trimmed.StartsWith('<html', [System.StringComparison]::OrdinalIgnoreCase)) {
        $snippet = ($trimmed.Substring(0, [Math]::Min(250, $trimmed.Length))).Replace("`r", ' ').Replace("`n", ' ')
        throw "Expected transcript XML but received HTML instead (likely consent/blocked page). First bytes: $snippet"
    }

    if ($trimmed -match 'class="g-recaptcha"' -or $trimmed -match "Sign in to confirm you.?re not a bot") {
        throw "YouTube is blocking this request with a bot/recaptcha page. Try again later or from a different network/IP."
    }

    $xmlDoc = New-Object System.Xml.XmlDocument
    try {
        $xmlDoc.LoadXml($content)
    } catch {
        $snippet = ($trimmed.Substring(0, [Math]::Min(250, $trimmed.Length))).Replace("`r", ' ').Replace("`n", ' ')
        throw "Failed to parse transcript XML: $($_.Exception.Message). First bytes: $snippet"
    }

    $textNodes = $xmlDoc.documentElement.ChildNodes

    $transcriptParts = @()
    foreach ($node in $textNodes) {
        $transcriptParts += [PSCustomObject]@{
            start    = $node.GetAttribute('start')
            duration = $node.GetAttribute('dur')
            text     = [System.Web.HttpUtility]::HtmlDecode($node.InnerText)
        }
    }

    return $transcriptParts
}

# Helper function to convert transcript data to TOON format
function ConvertTo-TOON {
    param (
        [PSCustomObject]$VideoInfo
    )

    # Helper function to escape and quote a value for TOON format
    function ConvertTo-TOONValue {
        param (
            [string]$Value
        )
        
        # Check if quoting is needed BEFORE escaping
        $needsQuoting = $Value -match '[,"\n\r\t]' -or $Value -match '^\s' -or $Value -match '\s$'
        
        # Apply escaping
        $escapedValue = $Value -replace '\\', '\\\\' -replace '"', '\\"' -replace "`n", '\\n' -replace "`r", '\\r' -replace "`t", '\\t'
        
        # Return quoted or unquoted value
        if ($needsQuoting) {
            return "`"$escapedValue`""
        } else {
            return $escapedValue
        }
    }

    $toon = ""
    
    # Add title if present
    if ($VideoInfo.PSObject.Properties['title']) {
        $titleValue = ConvertTo-TOONValue -Value $VideoInfo.title
        $toon += "title: $titleValue`n"
    }
    
    # Add description if present
    if ($VideoInfo.PSObject.Properties['description']) {
        $descValue = ConvertTo-TOONValue -Value $VideoInfo.description
        $toon += "description: $descValue`n"
    }
    
    # Add language (with proper escaping)
    $langValue = ConvertTo-TOONValue -Value $VideoInfo.language
    $toon += "language: $langValue`n"
    
    # Add transcript in tabular TOON format
    $transcriptCount = $VideoInfo.transcript.Count
    $toon += "transcript[$transcriptCount]{start,duration,text}:`n"
    
    foreach ($part in $VideoInfo.transcript) {
        $textValue = ConvertTo-TOONValue -Value $part.text
        $toon += "  $($part.start),$($part.duration),$textValue`n"
    }
    
    return $toon
}

# Function to get the transcript
function Get-Transcript {
    param (
        [Parameter(Mandatory)]
        [string]$videoId,
        [switch]$IncludeTitle,
        [switch]$IncludeDescription,
        [ValidateSet('PSObject', 'Markdown', 'TOON')]
        [string]$OutputFormat = 'Markdown'
    )
    $vidId = Test-YouTubeVideoId -InputString $videoId
    $langOptLinks = Get-LangOptionsWithLink -videoId $vidId
    if ($langOptLinks.Count -eq 0) {
        Write-Host 'No transcripts available for this video.'
        return @()
    }
    
    $link = $langOptLinks[0].link
    if ($null -ne $link) {

        # retrun the video info
        # title, description, transcript
        $markdown = "# Video Transcript`n"
        $videoinfo = [PSCustomObject][ordered]@{
        }
        if ($IncludeTitle) {
            $videoinfo | Add-Member -NotePropertyName 'title' -NotePropertyValue $langOptLinks[0].title
            $markdown += "## Title`n$($langOptLinks[0].title)`n"
        }
        if ($IncludeDescription) {
            $videoinfo | Add-Member -NotePropertyName 'description' -NotePropertyValue $langOptLinks[0].description
            $markdown += "## Description`n$($langOptLinks[0].description)`n"
        }
        $videoinfo | Add-Member -NotePropertyName 'language' -NotePropertyValue $langOptLinks[0].language
        $markdown += "## Language`n$($langOptLinks[0].language)`n"
        $videoinfo | Add-Member -NotePropertyName 'transcript' -NotePropertyValue (Get-RawTranscript -link $link)
        $markdown += @"
## Transcript
| Start    | Duration | Text |
| :------- | :------ | :------ |`n
"@
        foreach ($part in $videoinfo.transcript) {
            $markdown += "| $($part.start) | $($part.duration) | $($part.text) |`n"
        }
        if ($OutputFormat -eq 'Markdown') {
            return $markdown
        } elseif ($OutputFormat -eq 'TOON') {
            return ConvertTo-TOON -VideoInfo $videoinfo
        } else {
            return $videoinfo
        }
        
    } else {
        Write-Host 'No valid link found for the transcript.'
        return @()
    }
}
