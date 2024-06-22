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

function Get-VideoPageHtml {
    param (
        [string]$videoId
    )

    try {
        $response = Invoke-WebRequest -Uri "https://www.youtube.com/watch?v=$videoId"
        $html = $response.Content
        # Check if the HTML content contains the video URL: <meta property="og:url" content="https://www.youtube.com/watch?v=GikIJpUv6oo">
        if ($html -match 'og:url') {
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

    $splittedHtml = $videoPageHtml -split '"captions":'

    if ($splittedHtml.Length -lt 2) {
        Write-Host 'No Caption Available'
        return @() # No Caption Available
    }

    try {
        $JsonregexPattern = '{(?:[^{}]|(?<Open>{)|(?<-Open>}))*(?(Open)(?!))}'
        $captionsJson = $splittedHtml[1] -split ',"videoDetails' | Select-Object -First 1
        $videoDetailsJson = ([regex]::Match(($splittedHtml[1] -split ',"videoDetails')[1], $JsonregexPattern).Value | ConvertFrom-Json)
        $captions = ConvertFrom-Json $captionsJson
        # Extract the caption tracks: baseUrl=/api/timedtext?...... this url does expire after some time
        $captionTracks = $captions.playerCaptionsTracklistRenderer.captionTracks
        # This will give the language options
        $languageOptions = $captionTracks | ForEach-Object { $_.name.runs.text }

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
            $link = ($captionTracks | Where-Object { $_.name.runs.text -eq $langName }).baseUrl
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

    $uri = ('https://www.youtube.com{0}' -f $link)
    $transcriptPageResponse = Invoke-WebRequest -Uri $uri
    [xml]$xmlDoc = [xml](New-Object System.Xml.XmlDocument)
    $xmlDoc.LoadXml($transcriptPageResponse.Content)

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

# Function to get the transcript
function Get-Transcript {
    param (
        [Parameter(Mandatory)]
        [string]$videoId,
        [switch]$IncludeTitle,
        [switch]$IncludeDescription
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
        $videoinfo = [PSCustomObject][ordered]@{
        }
        if ($IncludeTitle) {
            $videoinfo | Add-Member -NotePropertyName 'title' -NotePropertyValue $langOptLinks[0].title
        }
        if ($IncludeDescription) {
            $videoinfo | Add-Member -NotePropertyName 'description' -NotePropertyValue $langOptLinks[0].description
        }
        $videoinfo | Add-Member -NotePropertyName 'language' -NotePropertyValue $langOptLinks[0].language
        $videoinfo | Add-Member -NotePropertyName 'transcript' -NotePropertyValue (Get-RawTranscript -link $link)
        return $videoinfo
        
    } else {
        Write-Host 'No valid link found for the transcript.'
        return @()
    }
}