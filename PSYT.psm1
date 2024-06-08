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
        $captionsJson = $splittedHtml[1] -split ',"videoDetails' | Select-Object -First 1
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
                language = $langName
                link     = $link
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
        [string]$videoId
    )

    $langOptLinks = Get-LangOptionsWithLink -videoId $videoId
    if ($langOptLinks.Count -eq 0) {
        Write-Host 'No transcripts available for this video.'
        return @()
    }
    
    $link = $langOptLinks[0].link
    if ($null -ne $link) {
        return Get-RawTranscript -link $link
    } else {
        Write-Host 'No valid link found for the transcript.'
        return @()
    }
}