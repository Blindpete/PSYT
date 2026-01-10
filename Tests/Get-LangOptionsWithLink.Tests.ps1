BeforeAll {
    $ModuleRoot = Split-Path -Parent $PSScriptRoot
    $ModuleName = 'PSYT'
    $ManifestPath = Join-Path $ModuleRoot "$ModuleName.psd1"
    
    # Import the module for testing
    Import-Module $ManifestPath -Force
}

Describe "Get-LangOptionsWithLink" {
    BeforeEach {
        # Mock the Get-VideoPageHtml function to return a valid HTML response
        Mock Get-VideoPageHtml -ModuleName PSYT {
            return @'
<html>
<head><title>Test Video</title></head>
<body>
<script>
var ytInitialData = {"captions":{"playerCaptionsTracklistRenderer":{"captionTracks":[{"baseUrl":"/api/timedtext?v=dQw4w9WgXcQ&ei=test&caps=asr&opi=test&xoaf=4&hl=en&ip=0.0.0.0&ipbits=0&expire=1234567890&sparams=ip%2Cipbits%2Cexpire%2Cv%2Cei%2Ccaps%2Copi%2Cxoaf&signature=test&key=test&kind=asr&lang=en","name":{"simpleText":"English (auto-generated)"},"vssId":".en","languageCode":"en","kind":"asr"},{"baseUrl":"/api/timedtext?v=dQw4w9WgXcQ&ei=test&opi=test&xoaf=4&hl=en&ip=0.0.0.0&ipbits=0&expire=1234567890&sparams=ip%2Cipbits%2Cexpire%2Cv%2Cei%2Copi%2Cxoaf&signature=test&key=test&lang=en","name":{"simpleText":"English"},"vssId":".en","languageCode":"en"}]}},"videoDetails":{"videoId":"dQw4w9WgXcQ","title":"Rick Astley - Never Gonna Give You Up","shortDescription":"The official video for Rick Astley's 1987 hit."}};
</script>
</body>
</html>
'@
        }
    }
    
    Context "Successful parsing" {
        It "Should return language options with metadata" {
            $Result = Get-LangOptionsWithLink -videoId "dQw4w9WgXcQ"
            
            $Result | Should -Not -BeNullOrEmpty
            $Result | Should -BeOfType [PSCustomObject]
            $Result.Count | Should -BeGreaterThan 0
        }
        
        It "Should include video title in results" {
            $Result = Get-LangOptionsWithLink -videoId "dQw4w9WgXcQ"
            
            $Result[0].title | Should -Be "Rick Astley - Never Gonna Give You Up"
        }
        
        It "Should include video description in results" {
            $Result = Get-LangOptionsWithLink -videoId "dQw4w9WgXcQ"
            
            $Result[0].description | Should -Be "The official video for Rick Astley's 1987 hit."
        }
        
        It "Should include language information" {
            $Result = Get-LangOptionsWithLink -videoId "dQw4w9WgXcQ"
            
            $Result[0].language | Should -Not -BeNullOrEmpty
            $Result[0].language | Should -BeIn @("English", "English (auto-generated)")
        }
        
        It "Should include caption link" {
            $Result = Get-LangOptionsWithLink -videoId "dQw4w9WgXcQ"
            
            $Result[0].link | Should -Not -BeNullOrEmpty
            $Result[0].link | Should -Match "/api/timedtext"
        }
        
        It "Should prioritize manual captions over auto-generated" {
            $Result = Get-LangOptionsWithLink -videoId "dQw4w9WgXcQ"
            
            # English should come before English (auto-generated)
            $Result[0].language | Should -Be "English"
        }
        
        It "Should call Get-VideoPageHtml with correct video ID" {
            Get-LangOptionsWithLink -videoId "dQw4w9WgXcQ"
            
            Should -Invoke Get-VideoPageHtml -ModuleName PSYT -ParameterFilter { 
                $videoId -eq "dQw4w9WgXcQ" 
            } -Exactly 1
        }
    }
    
    Context "Error conditions" {
        It "Should return empty array when Get-VideoPageHtml fails" {
            Mock Get-VideoPageHtml -ModuleName PSYT { return $null }
            
            $Result = Get-LangOptionsWithLink -videoId "dQw4w9WgXcQ"
            $Result | Should -Be @()
        }
        
        It "Should return empty array when no captions section exists" {
            Mock Get-VideoPageHtml -ModuleName PSYT {
                return '<html><body>No captions data</body></html>'
            }
            
            $Result = Get-LangOptionsWithLink -videoId "dQw4w9WgXcQ"
            $Result | Should -Be @()
        }
        
        It "Should return empty array when captions JSON is malformed" {
            Mock Get-VideoPageHtml -ModuleName PSYT {
                return @'
<html><body>
<script>
var ytInitialData = {"captions":{"malformed":"json"}};
</script>
</body></html>
'@
            }
            
            $Result = Get-LangOptionsWithLink -videoId "dQw4w9WgXcQ"
            $Result | Should -Be @()
        }
        
        It "Should handle videos with no caption tracks" {
            Mock Get-VideoPageHtml -ModuleName PSYT {
                return @'
<html><body>
<script>
var ytInitialData = {"captions":{"playerCaptionsTracklistRenderer":{"captionTracks":[]}},"videoDetails":{"videoId":"dQw4w9WgXcQ","title":"Test Video","shortDescription":"Test Description"}};
</script>
</body></html>
'@
            }
            
            $Result = Get-LangOptionsWithLink -videoId "dQw4w9WgXcQ"
            $Result | Should -Be @()
        }
    }
    
    Context "Language processing" {
        It "Should handle captions with runs.text format" {
            Mock Get-VideoPageHtml -ModuleName PSYT {
                return @'
<html><body>
<script>
var ytInitialData = {"captions":{"playerCaptionsTracklistRenderer":{"captionTracks":[{"baseUrl":"/api/timedtext?test=true","name":{"runs":[{"text":"Spanish"}]},"vssId":".es","languageCode":"es"}]}},"videoDetails":{"videoId":"dQw4w9WgXcQ","title":"Test Video","shortDescription":"Test Description"}};
</script>
</body></html>
'@
            }
            
            $Result = Get-LangOptionsWithLink -videoId "dQw4w9WgXcQ"
            $Result[0].language | Should -Be "Spanish"
        }
        
        It "Should handle multiple language options" {
            Mock Get-VideoPageHtml -ModuleName PSYT {
                return @'
<html><body>
<script>
var ytInitialData = {"captions":{"playerCaptionsTracklistRenderer":{"captionTracks":[{"baseUrl":"/api/timedtext?lang=en","name":{"simpleText":"English"},"languageCode":"en"},{"baseUrl":"/api/timedtext?lang=es","name":{"simpleText":"Spanish"},"languageCode":"es"},{"baseUrl":"/api/timedtext?lang=fr","name":{"simpleText":"French"},"languageCode":"fr"}]}},"videoDetails":{"videoId":"dQw4w9WgXcQ","title":"Test Video","shortDescription":"Test Description"}};
</script>
</body></html>
'@
            }
            
            $Result = Get-LangOptionsWithLink -videoId "dQw4w9WgXcQ"
            $Result.Count | Should -Be 3
            $Result.language | Should -Contain "English"
            $Result.language | Should -Contain "Spanish"
            $Result.language | Should -Contain "French"
        }
    }
    
    Context "Input validation" {
        It "Should handle empty video ID" {
            Mock Get-VideoPageHtml -ModuleName PSYT { return $null }
            
            $Result = Get-LangOptionsWithLink -videoId ""
            $Result | Should -Be @()
        }
        
        It "Should handle null video ID" {
            Mock Get-VideoPageHtml -ModuleName PSYT { return $null }
            
            $Result = Get-LangOptionsWithLink -videoId $null
            $Result | Should -Be @()
        }
    }
}