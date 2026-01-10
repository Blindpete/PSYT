BeforeAll {
    $ModuleRoot = Split-Path -Parent $PSScriptRoot
    $ModuleName = 'PSYT'
    $ManifestPath = Join-Path $ModuleRoot "$ModuleName.psd1"
    
    # Import the module for testing
    Import-Module $ManifestPath -Force
}

Describe "Get-VideoPageHtml" {
    Context "Successful requests" {
        It "Should return HTML content for valid video ID" {
            # Mock successful response
            Mock Invoke-WebRequest -ModuleName PSYT {
                return [PSCustomObject]@{
                    Content = '<html><head><meta property="og:url" content="https://www.youtube.com/watch?v=dQw4w9WgXcQ"></head><body>"playabilityStatus":{"status":"OK"}</body></html>'
                }
            }
            
            $Result = Get-VideoPageHtml -videoId "dQw4w9WgXcQ"
            $Result | Should -Not -BeNullOrEmpty
            $Result | Should -Match 'og:url'
            $Result | Should -Match 'playabilityStatus'
        }
        
        It "Should call Invoke-WebRequest with correct URL" {
            Mock Invoke-WebRequest -ModuleName PSYT {
                return [PSCustomObject]@{
                    Content = '<html><head><meta property="og:url" content="https://www.youtube.com/watch?v=dQw4w9WgXcQ"></head><body>"playabilityStatus":{"status":"OK"}</body></html>'
                }
            }
            
            Get-VideoPageHtml -videoId "dQw4w9WgXcQ"
            
            Should -Invoke Invoke-WebRequest -ModuleName PSYT -ParameterFilter { 
                $Uri -eq "https://www.youtube.com/watch?v=dQw4w9WgXcQ" 
            } -Exactly 1
        }
    }
    
    Context "Error conditions" {
        It "Should return null when og:url is missing" {
            Mock Invoke-WebRequest -ModuleName PSYT {
                return [PSCustomObject]@{
                    Content = '<html><body>No og:url meta tag</body></html>'
                }
            }
            
            $Result = Get-VideoPageHtml -videoId "dQw4w9WgXcQ"
            $Result | Should -BeNull
        }
        
        It "Should return null when reCAPTCHA is detected" {
            Mock Invoke-WebRequest -ModuleName PSYT {
                return [PSCustomObject]@{
                    Content = '<html><head><meta property="og:url" content="https://www.youtube.com/watch?v=dQw4w9WgXcQ"></head><body><div class="g-recaptcha"></div></body></html>'
                }
            }
            
            $Result = Get-VideoPageHtml -videoId "dQw4w9WgXcQ"
            $Result | Should -BeNull
        }
        
        It "Should return null when playabilityStatus is missing" {
            Mock Invoke-WebRequest -ModuleName PSYT {
                return [PSCustomObject]@{
                    Content = '<html><head><meta property="og:url" content="https://www.youtube.com/watch?v=dQw4w9WgXcQ"></head><body>No playability status</body></html>'
                }
            }
            
            $Result = Get-VideoPageHtml -videoId "dQw4w9WgXcQ"
            $Result | Should -BeNull
        }
        
        It "Should return null when Invoke-WebRequest throws exception" {
            Mock Invoke-WebRequest -ModuleName PSYT {
                throw "Network error"
            }
            
            $Result = Get-VideoPageHtml -videoId "dQw4w9WgXcQ"
            $Result | Should -BeNull
        }
        
        It "Should handle 404 errors gracefully" {
            Mock Invoke-WebRequest -ModuleName PSYT {
                throw [System.Net.WebException]::new("The remote server returned an error: (404) Not Found.")
            }
            
            $Result = Get-VideoPageHtml -videoId "invalidid"
            $Result | Should -BeNull
        }
        
        It "Should handle network timeout gracefully" {
            Mock Invoke-WebRequest -ModuleName PSYT {
                throw [System.TimeoutException]::new("Request timeout")
            }
            
            $Result = Get-VideoPageHtml -videoId "dQw4w9WgXcQ"
            $Result | Should -BeNull
        }
    }
    
    Context "Input validation" {
        It "Should handle empty video ID" {
            Mock Invoke-WebRequest -ModuleName PSYT {
                throw "Invalid URL"
            }
            
            $Result = Get-VideoPageHtml -videoId ""
            $Result | Should -BeNull
        }
        
        It "Should handle null video ID" {
            Mock Invoke-WebRequest -ModuleName PSYT {
                throw "Invalid URL"
            }
            
            $Result = Get-VideoPageHtml -videoId $null
            $Result | Should -BeNull
        }
    }
    
    Context "Response validation" {
        It "Should validate that response contains expected YouTube elements" {
            Mock Invoke-WebRequest -ModuleName PSYT {
                return [PSCustomObject]@{
                    Content = @'
<html>
<head>
    <meta property="og:url" content="https://www.youtube.com/watch?v=dQw4w9WgXcQ">
    <title>Test Video</title>
</head>
<body>
    <script>
        var ytInitialData = {"contents":{"playabilityStatus":{"status":"OK"}}};
    </script>
</body>
</html>
'@
                }
            }
            
            $Result = Get-VideoPageHtml -videoId "dQw4w9WgXcQ"
            $Result | Should -Not -BeNullOrEmpty
            $Result | Should -Match 'og:url'
            $Result | Should -Match 'playabilityStatus'
        }
    }
}