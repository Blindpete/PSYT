@{
    RootModule        = 'PSYT.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '7b22e037-e42c-4321-926d-8f97cacd7079'
    Author            = 'Peter Cook'
    CompanyName       = 'Peter Cook'
    Copyright         = '(c) All rights reserved.'

    PowerShellVersion = '7.4'
    FunctionsToExport = @(
        'Get-VideoPageHtml'
        'Get-LangOptionsWithLink'
        'Get-RawTranscript'
        'Get-Transcript'
    )
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Category   = "PowerShell YouTube Transcripts Module"
            Tags       = @("PowerShell", "YouTube", "Transcripts")
            ProjectUri = "https://github.com/Blindpete/PSYT/"
            LicenseUri = "https://github.com/Blindpete/PSYT/blob/main/LICENSE"
        }
    }
}

