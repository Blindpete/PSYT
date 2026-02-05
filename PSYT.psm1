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
    - Optional parameters: IncludeTitle, IncludeDescription.


.PARAMETER videoId
The YouTube video ID or YouTube Url.

.PARAMETER IncludeTitle
Specifies whether to include the video title in the transcript object. Default is false.

.PARAMETER IncludeDescription
Specifies whether to include the video description in the transcript object. Default is false.

.EXAMPLE
PS C:\> Test-YouTubeVideoId -InputString "https://www.youtube.com/watch?v=vc79sJ9VOqk"
Returns: "vc79sJ9VOqk"

.EXAMPLE
PS C:\> Get-Transcript -videoId "GikIJpUv6oo" -IncludeTitle -IncludeDescription
Returns: Object containing the video title, description, language, and transcript parts.

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

        # Build language options with links directly from caption tracks
        # Mirror youtube-transcript-api behavior: remove fmt=srv3, which can trigger PO-token requirements
        $languageOptionsWithLink = $captionTracks | ForEach-Object {
            $langName = if ($_.name.runs.text) { $_.name.runs.text } else { $_.name.simpleText }
            [PSCustomObject]@{
                title       = $videoDetailsJson.title
                description = $videoDetailsJson.shortDescription
                language    = $langName
                link        = $_.baseUrl -replace '&fmt=srv3', ''
            }
        }

        # Sort to prioritize 'English' (manually created) over 'English (auto-generated)' over other languages
        $languageOptionsWithLink = $languageOptionsWithLink | Sort-Object {
            switch -Regex ($_.language) {
                '^English$' { -1 }
                'English'   { 0 }
                default     { 1 }
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

    # Use pipeline output instead of += for better performance
    $transcriptParts = foreach ($node in $textNodes) {
        [PSCustomObject]@{
            start    = $node.GetAttribute('start')
            duration = $node.GetAttribute('dur')
            text     = [System.Web.HttpUtility]::HtmlDecode($node.InnerText)
        }
    }

    return $transcriptParts
}

# Function to get the transcript
function Get-Transcript {
    param (
        [Parameter(Mandatory)]
        [string]$videoId,
        [switch]$IncludeTitle,
        [switch]$IncludeDescription,
        [ValidateSet('PSObject', 'Markdown')]
        [string]$OutputFormat = 'Markdown'
    )
    $vidId = Test-YouTubeVideoId -InputString $videoId
    $langOptLinks = Get-LangOptionsWithLink -videoId $vidId
    if ($langOptLinks.Count -eq 0) {
        Write-Host 'No transcripts available for this video.'
        return @()
    }
    
    $link = $langOptLinks[0].link
    if ($null -eq $link) {
        Write-Host 'No valid link found for the transcript.'
        return @()
    }

    # Build video info object
    $langOption = $langOptLinks[0]
    $transcript = Get-RawTranscript -link $link

    $videoinfoProps = [ordered]@{}
    if ($IncludeTitle) { $videoinfoProps['title'] = $langOption.title }
    if ($IncludeDescription) { $videoinfoProps['description'] = $langOption.description }
    $videoinfoProps['language'] = $langOption.language
    $videoinfoProps['transcript'] = $transcript

    if ($OutputFormat -eq 'PSObject') {
        return [PSCustomObject]$videoinfoProps
    }

    # Build markdown using array and -join for efficiency
    $mdParts = @(
        '# Video Transcript'
        if ($IncludeTitle) { "## Title", $langOption.title }
        if ($IncludeDescription) { "## Description", $langOption.description }
        "## Language", $langOption.language
        '## Transcript'
        '| Start    | Duration | Text |'
        '| :------- | :------ | :------ |'
    )
    $mdParts += foreach ($part in $transcript) {
        "| $($part.start) | $($part.duration) | $($part.text) |"
    }

    return $mdParts -join "`n"
}
