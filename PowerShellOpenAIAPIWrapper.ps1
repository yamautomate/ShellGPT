function Invoke-CompletionAPI {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.Object]$prompt,  # The prompt to send to the API to act upon.
        [Parameter(Mandatory=$true)]
        [string]$APIKey,        # The API key to authenticate the request.
        [Parameter(Mandatory=$true)]
        [double]$temperature,   # The temperature value to use for sampling.
        [Parameter(Mandatory=$true)]
        [int]$max_tokens,       # The maximum number of tokens to generate in the response.
        [Parameter(Mandatory=$false)]
        $character              # The character to use. Is needed when we use a character and want to make sure we append the Ouput of the API correctly to our prompt.

    )

    $model = "gpt-3.5-turbo" 
    $stop = "\n"

    #Building Request for API
    $headers = @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $APIKey"
    }

    $RequestBody = @{
        messages = $prompt
        model = $model
        temperature= $temperature
        max_tokens = $max_tokens
        stop=$stop
    } 

    #Convert the whole Body to be JSON, so that API can interpret it
    $RequestBody = $RequestBody | ConvertTo-Json

    $RestMethodParameter=@{
        Method='Post'
        Uri ='https://api.openai.com/v1/chat/completions'
        body=$RequestBody
        Headers=$Headers
    }

    try {
        #Call the OpenAI completions API
        $APIresponse = Invoke-RestMethod @RestMethodParameter

        #Extract Textresponse from API response
        $convertedResponseForOutput = $APIresponse.choices.message.content

        $outputColor = "Green"
       
        #Append text output to prompt for returning it
        $prompt = New-CompletionAPIPrompt -query $convertedResponseForOutput -role "assistant" -previousMessages $prompt

        $promptToReturn = $prompt
    }
    catch {
        # If there was an error, define an error message to the written.
        $convertedResponseForOutput = "Unable to handle Error: "+$_.Exception.Message+" Retry query. If the error persists, consider exporting your current prompt and to continue later."
        $outputColor = "Red"

        #return prompt used as input, as we could not add the answer from the API.
        $promptToReturn = $prompt

    }

    #Output the text response.
    write-host "ChatGPT:"$convertedResponseForOutput -ForegroundColor $outputColor

    #return the new full prompt with the added text response from the API
    return $promptToReturn
}

# This function constructs a new prompt for sending to the API, either as a new conversation or as a continuation of an existing conversation.

function New-CompletionAPIPrompt {
    param (   
        [Parameter(Mandatory=$true)]        
        [string]$query,             # The user's query to add to the prompt.
        [Parameter(Mandatory=$true)]    
        [ValidateSet("system", "assistant", "user")] 
        [string]$role,              # The role to add to the prompt. 
        [Parameter(Mandatory=$false)]    
        [string]$instructor,        # The instruction string to add to the prompt.
        [Parameter(Mandatory=$false)]    
        [string]$assistantReply,    # The first, unseen reply by the model. Can be used to help train it and get expected output.
        [Parameter(Mandatory=$false)]    
        [System.Object]$previousMessages   # An array of previous messages in the conversation.    
    )

    if ($previousMessages)
    {
        
        $previousMessages += @{
            role = $role
            content = $query
        }

        $promptToReturn = $previousMessages
    }

    else 
    {
        if ($assistantReply -eq $null)
            {
                $assistantReply = "Hello! I'm ChatGPT, a GPT Model. How can I assist you today?"
            }

        $promptToReturn = @(
            @{
                role = "system"
                content = $instructor
            },
            @{
                role = "assistant"
                content = $assistantReply
            },
            @{
                role = $role
                content = $query
            }
        )

    }

    return $promptToReturn
}

function Set-CompletionAPICharacter {
    param (
        [Parameter(Mandatory=$true)]  
        [ValidateSet("Chat", "SentimentAndTickerAnalysis", "SentimentAnalysis", "IntentAnalysis","IntentAndSubjectAnalysis")]
        $mode
    )

    switch ($mode)
    {
        "Chat" {
            $instructor = "You are a helpful AI. You answer as concisely as possible."
            $assistantReply = "Hello! I'm a ChatGPT-3.5 Model. How can I help you?"
        }

        "SentimentAndTickerAnalysis" {
            $assistantReply = @{ 
                ticker = "BTC"
                asset_type = "Cryptocurrency"
                sentiment = 0.9
            }
            $instructor = "You are part of a trading bot API that analyzes tweets. When presented with a text message, you extract either the Cryptocurrency or Stockmarket abbrev for that ticker and you also analyze the text for sentiment. You provide your answer in a .JSON format in the following structure: { 'ticker': 'USDT', 'asset_type': 'Cryptocurrency', 'sentiment': 0.8 } You only answer with the .JSON object. You do not provide any reasoning why you did it that way.  The sentiment is a value between 0 - 1. Where 1 is the most positive sentiment and 0 is the most negative. If you can not extract the Ticker, you specify it with 'unknown' in your response. Same for sentiment."
        }

        "SentimentAnalysis" {
            $assistantReply = @{ 
                sentiment = 0.9
            }
            $instructor = 'You are an API that analyzes text sentiment. You provide your answer in a .JSON format in the following structure: { "sentiment": 0.9 } You only answer with the .JSON object. You do not provide any reasoning why you did it that way.  The sentiment is a value between 0 - 1. Where 1 is the most positive sentiment and 0 is the most negative. If you can not extract the sentiment, you specify it with "unknown" in your response.'
        }

        "IntentAnalysis" {
            $assistantReply = @{ 
                intent = "purchase"
            }
            $instructor = 'You are an API that analyzes the core intent of the text. You provide your answer in a .JSON format in the following structure: { "intent": descriptive verb for intent } You only answer with the .JSON object. You do not provide any reasoning why you did it that way. The intent represents the one intent you extracted during your analysis. If you can not extract the intent with a probability of 70% or more, you specify it with "unknown" in your response.'
        }

        "IntentAndSubjectAnalysis" {
            $assistantReply = @{ 
                intent = "purchase"
                topic = "bananas"
            }
            $instructor = 'You are an API that analyzes the core intent of the text and the subject the the intent wants to act upon. You provide your answer in a .JSON format in the following structure: { "intent": "descriptive verb for intent", "subject": "bananas" } You only answer with the .JSON object. You do not provide any reasoning why you did it that way. The intent represents the one intent you extracted during your analysis. The subject is the thing the intent wants to act upon (what does some want to buy? want information do they want?). If you can not extract the intent and or subject with a probability of 70% or more, you specify it with "unknown" in your response.'
        }

        default {
            throw "Invalid mode parameter. Allowed values are 'Chat', 'SentimentAndTickerAnalysis', and 'SentimentAnalysis'."
        }
    }

    $promptToReturn = @(
        @{
            role = "system"
            content = $instructor
        },
        @{
            role = "assistant"
            content = $assistantReply
        }
    )
    
    return $promptToReturn
}

# A wrapper function that creates the prompt and calls the Open AI API using "New-ChatGPTPrompt" and "Invoke-OpenAIAPI"
function New-CompletionAPIConversation {
    param (
        [ValidateSet("Chat", "SentimentAndTickerAnalysis","SentimentAnalysis","IntentAnalysis","IntentAndSubjectAnalysis")]
        [System.Object]$Character,     # The character to use. If specified, do not add instructor and assistantReply
        [string]$query,                # The user's query to add to the prompt.
        [string]$instructor,           # The instruction string to add to the prompt. Only use when you dont use a Character.
        [string]$assistantReply,       # The first, unseen reply by the model. Can be used to help train it and get expected output. Only use when you dont use a Character.
        [string]$APIKey,               # API key for ChatGPT.
        [double]$temperature,          # The temperature value to use for sampling.
        [int]$max_tokens               # The maximum number of tokens to generate in the response.
    )
    
    if ($Character -eq $null)
    {
        $promptForAPI = New-CompletionAPIPrompt -query $query -instructor $instructor -role "user" -assistantReply $assistantReply
        $promptToReturn = Invoke-CompletionAPI -Prompt $promptForAPI -APIKey $APIKey -Model $model -temperature $temperature -stop $stop -max_tokens $max_tokens
    }
    else 
    {
        $characterPrompt= Set-CompletionAPICharacter -mode $Character
        $promptForAPI = New-CompletionAPIPrompt -query $query -role "user" -previousMessages $characterPrompt

        $promptToReturn = Invoke-CompletionAPI -Prompt $promptForAPI -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens  
    }

    return $promptToReturn
}

# This function acts as a wrappe and adds a new message to an existing ChatGPT conversation using the given parameters.
function Add-CompletionAPIMessageToConversation {
    param (
        [Parameter(Mandatory=$true)]  
        [string]$query,             # The user's query to be added to the conversation.
        [Parameter(Mandatory=$true)]  
        [System.Object]$previousMessages,  # An array of previous messages in the conversation.
        [Parameter(Mandatory=$false)]    
        [string]$instructor,        # The instruction string to add to the prompt..
        [Parameter(Mandatory=$true)]    
        [string]$APIKey,            # API key for ChatGPT.
        [Parameter(Mandatory=$true)]    
        [double]$temperature,       # The temperature value to use for sampling.
        [Parameter(Mandatory=$true)]    
        [int]$max_tokens,         # The maximum number of tokens to generate in the response.
        $character
    )

    $prompt = New-CompletionAPIPrompt -query $query -role "user" -previousMessages $previousMessages

    # Call the Invoke-ChatGPT function to get the response from the API.
    $returnPromptFromAPI = Invoke-CompletionAPI -prompt $prompt -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens 
    
    # Return the response from the API and the updated previous messages.
    return $returnPromptFromAPI
    
}
function Import-PromptFromJson {
    param (
        [Parameter(Mandatory=$true)]    
        [string]$Path
    )

    $promptJson = Get-Content -Path $Path -Raw
    $prompt = $promptJson | ConvertFrom-Json

    return $prompt
}

# This function starts a new ChatGPT conversation.
function Start-ChatGPTforPowerShell {
    param (
        [Parameter(Mandatory=$true)]    
        [string]$APIKey,          # API key for ChatGPT
        [Parameter(Mandatory=$true)]    
        [double]$temperature,     # Temperature parameter for ChatGPT
        [Parameter(Mandatory=$true)]    
        [int]$max_tokens       # Max_tokens parameter for ChatGPT
    )

    $contiueConversation = $(Write-Host "Do you want to restore an existing conversation? (enter 'y' or 'yes'): " -ForegroundColor yellow -NoNewLine; Read-Host) 

    if ($contiueConversation  -eq "y" -or $contiueConversation -eq "yes")
    {
        Write-Host "Initializing Import..." 
        # Display a welcome message and instructions for stopping the conversation.
        Write-Host "To stop the current conversation enter 'q' or 'quit' in the query" -ForegroundColor yellow

        $importPath = $(Write-Host "Provide the full path to the prompt*.json file you want to continue the conversation on: " -ForegroundColor yellow -NoNewLine; Read-Host) 
        $importedPrompt = Import-PromptFromJson -Path $importPath
        $previousMessages = $importedPrompt
    }
    else 
    {
        Write-Host "Starting a new one..." 
        # Display a welcome message and instructions for stopping the conversation.
        Write-Host "To stop the current conversation enter 'q' or 'quit' in the query" -ForegroundColor yellow

        # Initialize the previous messages array.
        $previousMessages = @()

        #select the character
        $option = Read-Host "Select the Character the Model should assume:`n1: Chat`n2: Ticker and Sentiment Analysis`n3: Sentiment Analysis`n4: Intent Analysis`n5: Intent & Topic Analysis"

        switch ($option) {
            "1" {
                $Character = "Chat"
            }
            "2" {
                $Character = "SentimentAndTickerAnalysis"
            }
            "3" {
                $Character = "SentimentAnalysis"
            }
            "4" {
                $Character = "IntentAnalysis"
            }
            "5" {
                $Character = "IntentAndSubjectAnalysis"
            }

            default {
                Write-Host "Invalid option selected."
            }
        }

        $conversationPrompt = New-CompletionAPIConversation -Character $Character -query (Read-Host "Your query for ChatGPT") -instructor $instructor -APIKey $APIKey -model $model -temperature $temperature -stop $stop -max_tokens $max_tokens

        $previousMessages += $conversationPrompt
    }


    # Initialize the continue variable.
    $continue = $true

    # Loop until the user stops the conversation.
    while ($continue) {

        # Prompt the user to enter their query for ChatGPT.
        $userQuery = Read-Host "Your query for ChatGPT"
        
        # If the user enters 'q' or 'quit', stop the conversation and ask if they want to start a new conversation.
        if ($userQuery -eq 'q' -or $userQuery -eq 'quit') {
            $continue = $false

            $exportPrompt = $(Write-Host "Do you want to export the current prompt for future use? (enter 'y' or 'yes'): " -ForegroundColor yellow -NoNewLine; Read-Host) 
            if ($exportPrompt -eq "y" -or $exportPrompt -eq "yes")
            {
               Write-Host "Initializing export.." 
               $exportPath = $(Write-Host "Provide the full path to the prompt*.json file that you want to export now and later continue the conversation on: " -ForegroundColor yellow -NoNewLine; Read-Host) 
               $previousMessages | ConvertTo-Json | Out-File -Encoding utf8 -FilePath $exportPath
            }

            $newConvo = $(Write-Host "Do you want to start a new conversation (enter 'y' or 'yes'): " -ForegroundColor yellow -NoNewLine; Read-Host) 
            if ($newConvo -eq "y" -or $newConvo -eq "yes")
            {
                # If the user wants to start a new conversation, call the New-ChatGPTConversation function recursively.
                Start-ChatGPTforPowerShell -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens
            }
        }
        else
        {
            # Call the Add-ChatGPTMessageToConversation function to add the user's query to the conversation and get the response from ChatGPT.
            $conversationPrompt = Add-CompletionAPIMessageToConversation -query $userQuery -previousMessages $previousMessages -instructor $instructor -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens -character $Character
            $previousMessages = $conversationPrompt
        }
    }
}

$APIKey = "YOUR_API_KEY"
$temperature = 0.6
$max_tokens = 3500

Start-ChatGPTforPowerShell -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens
