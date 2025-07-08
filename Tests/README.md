# PSYT Module Tests

This directory contains comprehensive Pester tests for the PSYT (PowerShell YouTube Transcripts) module to support refactoring efforts.

## Test Coverage

The test suite includes **97 tests** covering:

### Module-Level Tests (`PSYT.Module.Tests.ps1`)
- Module manifest validation
- Module structure verification
- Exported function validation
- PowerShell version compatibility

### Function-Specific Tests

#### `Test-YouTubeVideoId.Tests.ps1` (18 tests)
- Valid YouTube URL patterns (standard, shortened, embed, shorts)
- Invalid input handling
- Edge cases with special characters
- Parameter validation

#### `Get-VideoPageHtml.Tests.ps1` (11 tests)
- Successful HTTP requests with mocked responses
- Error condition handling (404, timeouts, reCAPTCHA)
- Response validation
- Input validation

#### `Get-LangOptionsWithLink.Tests.ps1` (15 tests)
- JSON parsing from YouTube page HTML
- Language option extraction
- Caption link generation
- Error handling for malformed data
- Multiple language support

#### `Get-RawTranscript.Tests.ps1` (18 tests)
- XML transcript parsing
- HTML entity decoding
- URL construction (relative vs absolute)
- Error handling for network issues
- Empty/malformed transcript handling

#### `Get-Transcript.Tests.ps1` (28 tests)
- End-to-end integration testing
- Markdown and PSObject output formats
- Optional parameter handling (IncludeTitle, IncludeDescription)
- Parameter validation
- Error scenarios

## Running Tests

### Run All Tests
```powershell
.\Run-Tests.ps1
```

### Run Specific Test File
```powershell
.\Run-Tests.ps1 -TestName "Get-Transcript"
```

### Run with Detailed Output
```powershell
.\Run-Tests.ps1 -OutputFormat Detailed
```

## Test Strategy

The tests use extensive mocking to:
- Avoid making actual HTTP calls to YouTube
- Test error conditions reliably
- Ensure consistent test results
- Enable fast test execution

### Mocking Approach
- `Invoke-WebRequest` calls are mocked with realistic YouTube HTML responses
- Function dependencies are mocked to isolate units under test
- Error conditions are simulated to test resilience

## Refactoring Support

These tests provide confidence for refactoring by:
- **Comprehensive coverage** of all public and private functions
- **Edge case validation** for robust error handling
- **Integration testing** to ensure components work together
- **Parameter validation** to maintain API contracts
- **Output format verification** to preserve functionality

## Test Results

All tests pass successfully:
- **97 tests total**
- **0 failures**
- **Fast execution** (~3-4 seconds for full suite)

The test suite ensures that any refactoring maintains the existing functionality and behavior of the PSYT module.