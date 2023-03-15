# PowerShell Open AI Completion API Module
This PowerShell code provides a simple interface to the OpenAI "Chat Completion" API for the GPT model "gpt-3.5-turbo", allowing users to initiate and continue conversations with the GPT model using PowerShell. This module is made by the community and not OpenAI.

Endpoint used: https://api.openai.com/v1/chat/completions


## How to use the "Completion API" module
To use the "Completion API" module and its functions, you need to install the module from PowerShell Gallery first, by using `Install-Modul`.
1. Open PowerShell and run `Install-Module`:
```powershell
Install-Module CompletionAPI
```
2. To check if it was installed successfully you can run `Get-Help`:
```powershell
Get-Help CompletionAPI
```

The Output should list all available cmldets/functions:
```
Name                              Category  Module                    Synopsis
----                              --------  ------                    --------
Set-CompletionAPICharacter        Function  CompletionAPI             This function generates a "Character" (a prompt that represents a character) to use. These five characters are hardcoded into that function.
New-CompletionAPIPrompt           Function  CompletionAPI             Creates a prompt (System.Object) for the function "Invoke-CompletionAPI" to be consumed.
New-CompletionAPIConversation     Function  CompletionAPI             This is a wrapper function that creates the prompt and calls the Open AI API using "New-     CompletionAPIPrompt" and "Invoke-CompletionAPI".
Invoke-CompletionAPI              Function  CompletionAPI             Sends a prompt (System.Object) to the OpenAI Completion API (api.openai.com/v1/chat/completions) using "gpt-3.5-turbo" model, gets a response, and appends it to the prompt.
Add-CompletionAPIMessageToConver… Function  CompletionAPI             This is a wrapper function that creates the prompt and calls the Open AI API using "New-CompletionAPIPrompt" and "Invoke-CompletionAPI".
```
## How to start the interactive ChatBot for PowerShell
First we need to define the `$APIKey`, `$temperature` and `$max_token` parameters:
```powershell
$APIKey = "YOUR_API_KEY"
$temperature = 0.6
$max_tokens = 3500
```
Then we can use `Start-ChatGPTforPowerShel` and pass along `$APIKey`, `$temperature` and `$max_token` we defined above:
```powershell
Start-ChatGPTforPowerShell -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens
```

# Function Documentation
See FUNCTIONS.md

