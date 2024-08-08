# PSYT

![drawing](Media/PSYT.png)

## PowerShell Module for Retrieving YouTube Transcripts

### Using the Module

```powershell
Install-Module -Name PSYT
```

### Example

Reqirements:

- [PSAI Module](https://github.com/dfinke/psai)
- [OpenAI API Key](https://help.openai.com/en/articles/4936850-where-do-i-find-my-openai-api-key)

In this example, we will retrieve the transcript of a YouTube video and then generate a summary of the main points and key takeaways from the transcript using the GPT-4o-mini model.

```powershell
# Source: https://youtu.be/OHQFObW6PXA
$transcriptParams = @{
    videoId            = 'OHQFObW6PXA'
    IncludeTitle       = $true
    IncludeDescription = $true
}

$transcript = Get-Transcript @transcriptParams

$summaryInput = @"
# Title:
$($transcript.title)

# Description:
$($transcript.description)

# Transcript:
$($transcript.transcript | Out-String)
"@

$summaryParams = @{
    Instructions = 'Write a concise summary of the with 3-5 bullet points that highlight the key points or takeaways from the video transcript, include the title and details from the description.'
    model        = 'gpt-4o-mini'
    UserInput    = $summaryInput
}

$summary = ai @summaryParams
$summary | glow
```

### Output

### Summary of "AI Development for a Non-Developer"

- **Introduction to Generative AI**: The video guides non-developers on utilizing GPT models and explains the basics of AI application development using Python.

- **Setting Up the Environment**: Instructions on installing Python, necessary libraries (like Azure Identity and OpenAI API), and the Azure CLI to set up the development environment.

- **Creating and Deploying Models**: The video details the process of creating an OpenAI resource in Azure, deploying a GPT model, and using Azure AI Studio for model management.

- **Building a Simple GPT Application**: Steps to create a text-based application for interacting with the GPT model, including managing user input, tracking memory of interactions, and handling tokens effectively.

- **Final Thoughts**: Emphasis on the simplicity of the coding process, encouragement to explore AI tools like Copilot and GPT for coding assistance, and the importance of using orchestration tools for more complex development in the future.

---

### TODO

- [ ] Add more examples
- [x] Fix encode issue
- [x] Add getting video description
- [x] Add getting video title
- [ ] Add getting video chapters
