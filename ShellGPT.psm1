function Invoke-OpenAICompletion {
    <#
    .SYNOPSIS
    This function sends a prompt to the OpenAI Completion API or Azure OpenAI API to generate a text completion based on the specified settings.

    .DESCRIPTION
    The Invoke-OpenAICompletion function sends a prompt to the OpenAI Completion API or Azure OpenAI API to generate a text completion. It takes a prompt as input, which is a list of strings containing the context of the completion. The function requires an API key to access the API and accepts various optional parameters to customize the generated text completion. The response from the API is used to update the prompt, and the updated prompt is returned as output.

    .PARAMETER prompt
    The prompt parameter is a mandatory parameter that accepts a list of strings containing the context of the completion. This parameter is used as input for generating the text completion.

    .PARAMETER APIKey
    The APIKey parameter is a mandatory parameter that accepts an API key to authenticate the request to the OpenAI Completion API.

    .PARAMETER model
    The model parameter is an optional parameter that specifies the model to use for generating the text completion.

    .PARAMETER stop
    The stop parameter is an optional parameter that specifies a stop token that the API should use to stop generating the text completion.

    .PARAMETER temperature
    The temperature parameter is an optional parameter that controls the randomness of the generated text completion.

    .PARAMETER max_tokens
    The max_tokens parameter is an optional parameter that specifies the maximum number of tokens that the API can generate in the text completion.

    .PARAMETER ShowOutput
    The ShowOutput parameter is an optional boolean parameter that specifies whether to display the generated output from the API.

    .PARAMETER ShowTokenUsage
    The ShowTokenUsage parameter is an optional boolean parameter that specifies whether to display the token usage details.

    .PARAMETER UseAzure
    The UseAzure parameter is an optional boolean parameter that specifies whether to use the Azure OpenAI API endpoint instead of the OpenAI API.

    .EXAMPLE
    # Example of how to use the function to generate a text completion
    #>

    param(
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] [System.Collections.ArrayList]$prompt, 
        [Parameter(Mandatory=$true)] [string]$APIKey,                        
        [Parameter(Mandatory=$false)][string]$model = "gpt-3.5-turbo",      
        [Parameter(Mandatory=$false)][string]$stop = "\n",                 
        [Parameter(Mandatory=$false)][double]$temperature = 0.4,            
        [Parameter(Mandatory=$false)][int]$max_tokens = 900,               
        [Parameter(Mandatory=$false)][bool]$ShowOutput = $false,            
        [Parameter(Mandatory=$false)][bool]$ShowTokenUsage = $false,         
        [Parameter(Mandatory=$false)][string]$UseAzure,
        [Parameter(Mandatory=$false)][string]$DeploymentName
    )

    Write-Verbose ("ShellGPT-Invoke-OpenAICompletion @ "+(Get-Date)+" | Building request...") 

    # Select the appropriate URI and headers based on whether Azure API is used
    if ($UseAzure -and $DeploymentName) {
        $uri = "https://$UseAzure.openai.azure.com/openai/deployments/$DeploymentName/chat/completions?api-version=2024-02-01"
        $headers = @{
            "Content-Type" = "application/json"
            "api-key" = $APIKey
        }
        $RequestBody = @{
            model = $model
            messages = $prompt
            temperature = $temperature
            max_tokens = $max_tokens
            top_p = 0.95
            frequency_penalty = 0
            presence_penalty = 0
            stop = $stop
        } 
    } 
    
    else {
        $uri = 'https://api.openai.com/v1/chat/completions'
        $headers = @{
            "Content-Type" = "application/json"
            "Authorization" = "Bearer $APIKey"
        }
        $RequestBody = @{
            messages = $prompt
            model = $model
            temperature = $temperature
            max_tokens = $max_tokens
            stop = $stop
        }
    }

    $RequestBody = $RequestBody | ConvertTo-Json -depth 3 
    $Requestbody = [System.Text.Encoding]::UTF8.GetBytes($RequestBody)

    $RestMethodParameter=@{
        Method='Post'
        Uri = $uri
        Body = $RequestBody
        Headers = $Headers
    }

    Write-Verbose ("ShellGPT-Invoke-OpenAICompletion @ "+(Get-Date)+" | Sending request to URI: "+($uri)) 

    try {
        #Call the OpenAI completions API
        Write-Verbose ("ShellGPT-Invoke-OpenAICompletion @ "+(Get-Date)+" | Sending off API Call using 'Invoke-RestMethod' to this URI: "+($uri)) 
        $APIresponse = Invoke-RestMethod @RestMethodParameter

        Write-Verbose ("ShellGPT-Invoke-OpenAICompletion @ "+(Get-Date)+" | Received response from API: "+($APIresponse | Out-String)) 

        #Extract Textresponse from API response
        $convertedResponseForOutput = $APIresponse.choices.message.content
        $tokenUsage = $APIresponse.usage
        
        Write-Verbose ("ShellGPT-Invoke-OpenAICompletion @ "+(Get-Date)+" | Extracted Output: "+($convertedResponseForOutput)) 
        Write-Verbose ("ShellGPT-Invoke-OpenAICompletion @ "+(Get-Date)+" | TokenUsage for this prompt: "+($TokenUsage.prompt_tokens)+" for completion: "+($TokenUsage.completion_tokens)+" Total tokens used: "+($TokenUsage.total_tokens)) 

        #Append text output to prompt for returning it
        Write-Verbose ("ShellGPT-Invoke-OpenAICompletion @ "+(Get-Date)+" | Creating new prompt with API response...") 
        [System.Collections.ArrayList]$prompt = New-OpenAICompletionPrompt -query $convertedResponseForOutput -role "assistant" -previousMessages $prompt -model $model

        Write-Verbose ("ShellGPT-Invoke-OpenAICompletion @ "+(Get-Date)+" | New Prompt is: "+($prompt | Out-String)) 

        If ($ShowTokenUsage -eq $true)
        {
            Write-Host ("ShellGPT-Invoke-OpenAICompletion @ "+(Get-Date)+" | TokenUsage for this prompt: "+($TokenUsage.prompt_tokens)+" for completion: "+($TokenUsage.completion_tokens)+" Total tokens used: "+($TokenUsage.total_tokens)) -ForegroundColor Yellow
        }

        if ($ShowOutput)
        {
            Write-Host ("ShellGPT @ "+(Get-Date)+" | "+($convertedResponseForOutput)) -ForegroundColor Green
        }

        [System.Collections.ArrayList]$promptToReturn = $prompt
    }
    catch {
        $errorDetails = $_.ErrorDetails.Message

        Write-Host ("ShellGPT-Invoke-OpenAICompletion @ "+(Get-Date)+" | Unable to handle Error "+($_.Exception.Message)+"See Error details below. Retry query. If the error persists, consider exporting your current prompt and to continue later.") -ForegroundColor "Red"
        Write-Host ("ShellGPT-Invoke-OpenAICompletion @ "+(Get-Date)+" | Error Details: "+($errorDetails)) -ForegroundColor "Red"

        if ($errorDetails.contains("invalid JSON: 'utf-8'")) {
            Write-Host ("ShellGPT-Invoke-OpenAICompletion @ "+(Get-Date)+" | Your prompt seems to contain characters that can be misinterpreted in utf-8 encoding. Remove those characters and try again."+($promptToReturn |Out-String)) -ForegroundColor "Yellow"
            }

        [System.Collections.ArrayList]$prompt.RemoveAt($prompt.count-1) 
        [System.Collections.ArrayList]$promptToReturn = [System.Collections.ArrayList]$prompt

        Write-Verbose ("ShellGPT-Invoke-OpenAICompletion @ "+(Get-Date)+" | Returning Input prompt, without the last query due to error and to prevent the prompt from becoming unusable: "+($promptToReturn | Out-String)) 

        }

    return [System.Collections.ArrayList]$promptToReturn
}

function New-OpenAICompletionPrompt {
    <#
    .SYNOPSIS
    Creates a prompt for an OpenAI completion API.
    .DESCRIPTION
    This PowerShell function generates a prompt to be sent to an OpenAI completion API using the user's query and additional input if applicable.
    .PARAMETER query
    Specifies the user's query to be used in the prompt.
    .PARAMETER role
    Specifies the role to be added to the prompt. This parameter is optional, and the default value is "user".
    .PARAMETER instructor
    Specifies the instruction string to be added to the prompt. This parameter is optional, and the default value is "You are ChatGPT, a helpful AI Assistant."
    .PARAMETER assistantReply
    Specifies the first, unseen reply by the model. This parameter is optional, and the default value is "Hello! I'm ChatGPT, a GPT Model. How can I assist you today?"
    .PARAMETER previousMessages
    Specifies an array of previous messages in the conversation. This parameter is optional.
    .PARAMETER filePath
    Specifies the file path for a file containing additional input. This parameter is optional.
    .PARAMETER model
    Specifies the name of the OpenAI model to use for completion. This parameter is optional.
    .INPUTS
    This function does not accept input by pipeline.
    .OUTPUTS
    The function returns a [System.Collections.ArrayList] prompt as output.
    #>

    param (   
        [Parameter(Mandatory=$true)]        
        [string]$query,                                                                             
        [Parameter(Mandatory=$false)]    
        [ValidateSet("system", "assistant", "user")] 
        [string]$role = "user",                                                                      
        [Parameter(Mandatory=$false)]    
        [string]$instructor = "You are ChatGPT, a helpful AI Assistant.",                            
        [Parameter(Mandatory=$false)]    
        [string]$assistantReply = "Hello! I'm ChatGPT, a GPT Model. How can I assist you today?",    
        [Parameter(Mandatory=$false)]    
        [System.Collections.ArrayList]$previousMessages,                                                            
        [Parameter(Mandatory=$false)]    
        [string]$filePath,                                                                               
        [Parameter(Mandatory=$false)]    
        [string]$model      
        )

    if ($filePath)
    {
        Write-Verbose ("ShellGPT-New-OpenAICompletionPrompt @ "+(Get-Date)+" | File path was provided: "+($filepath)) 


        if ($filePath.EndsWith(".pdf"))
        {
            Write-Verbose ("ShellGPT-New-OpenAICompletionPrompt @ "+(Get-Date)+" | File is PDF. Trying to read content and generate .txt...") 
            Write-Verbose ("ShellGPT-New-OpenAICompletionPrompt @ "+(Get-Date)+" | File is PDF. Reworking filepath to only have forward slashes...") 
            $filePath = $filePath.Replace("\","/")

            try {            
                $filePath = Convert-PDFtoText -filePath $filePath -TypeToExport txt
                Write-Verbose ("ShellGPT-New-OpenAICompletionPrompt @ "+(Get-Date)+" | PDF Content was read, and .txt created at this path: "+($filepath)) 

            }
            catch {
                Write-Verbose ("ShellGPT-New-OpenAICompletionPrompt @ "+(Get-Date)+" | We ran into trouble reading the PDF content and writing it to a .txt file "+($filepath)) 
                $errorToReport = $_.Exception.Message
                $errorDetails = $_.ErrorDetails.Message
        
                Write-Host ("ShellGPT-New-OpenAICompletionPrompt @ "+(Get-Date)+" | We ran into trouble reading the PDF content and writing it to a .txt file "+($errorToReport)) 
            
                if ($errorDetails)
                    {
                        Write-Host ("ShellGPT-New-OpenAICompletionPrompt @ "+(Get-Date)+" | Details: "+($errorDetails)) 
                    }        
                }
        }

        try {
            Write-Verbose ("ShellGPT-New-OpenAICompletionPrompt @ "+(Get-Date)+" | Trying to read content of file using UTF-8 encoding...") 
            $filecontent = Get-Content -Path $filePath -Raw -Encoding utf8
            Write-Verbose ("ShellGPT-New-OpenAICompletionPrompt @ "+(Get-Date)+" | File content extracted...") 
            $query = "$query $filecontent" 
        }
        catch {
            $errorToReport = $_.Exception.Message
            $errorDetails = $_.ErrorDetails.Message
            $message = "Unable to handle Error: "+$errorToReport+" See Error details below."
        
            write-host "Error:"$message -ForegroundColor red
        
            if ($errorDetails)
            {
                write-host "ErrorDetails:"$errorDetails -ForegroundColor "Red"
            }    
        }
    }
   
    if ($previousMessages)
    {
        Write-Verbose ("ShellGPT-New-OpenAICompletionPrompt @ "+(Get-Date)+" | Previous Messages are present: "+($previousMessages | Out-String))
        Write-Verbose ("ShellGPT-New-OpenAICompletionPrompt @ "+(Get-Date)+" | Adding new query: "+($query)+" for role: "+($role)+" to previous Messages")

        $previousMessages.Add(@{
            role = $role
            content = $query
        }) | Out-Null

        Write-Verbose ("ShellGPT-New-OpenAICompletionPrompt @ "+(Get-Date)+" | Added new query to previousmessages")

        [System.Collections.ArrayList]$promptToReturn = [System.Collections.ArrayList]$previousMessages 
    }

    else 
    {
        [System.Collections.ArrayList]$promptToReturn = @(
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

function Set-OpenAICompletionCharacter {
    <#
    .SYNOPSIS
    This function, Set-OpenAICompletionCharacter, sets the response mode and prompts for a ChatGPT-3.5 model.
    .DESCRIPTION
    This function allows the user to set the mode for the response and prompts for a ChatGPT-3.5 model. 
    The response mode can be one of the following: Chat, SentimentAndTickerAnalysis, SentimentAnalysis, IntentAnalysis, or IntentAndSubjectAnalysis. 
    Depending on the selected mode, the function will generate pre-defined (hardcoded) prompts for the user to use.
    .PARAMETER mode
    This parameter specifies the mode for the response. It is a required parameter and must be one of the following values: Chat, SentimentAndTickerAnalysis, SentimentAnalysis, IntentAnalysis, or IntentAndSubjectAnalysis.
    .PARAMETER instructor
    This parameter specifies the text prompt for the ChatGPT-3.5 model. It is an optional parameter and defaults to "You are a helpful AI. You answer as concisely as possible." if not specified.
    .PARAMETER assistantReply
    This parameter specifies the response of the ChatGPT-3.5 model. It is an optional parameter and defaults to "Hello! I'm a ChatGPT-3.5 Model. How can I help you?" if not specified.
    .INPUTS
    This function does not take any input.
    .OUTPUTS
    This function returns a list of text prompts and responses in a .JSON format. The structure of the .JSON object varies depending on the selected mode.
    .EXAMPLE
    PS C:> Set-OpenAICompletionCharacter -mode Chat -instructor "How can I assist you today?" -assistantReply "I can help you with a variety of tasks such as answering questions or providing information on a specific topic."
    This example sets the response mode to "Chat" and generates a prompt for the ChatGPT-3.5 model with the instructor text "How can I assist you today?" and the assistant reply "I can help you with a variety of tasks such as answering questions or providing information on a specific topic."
    .LINK
    #>
    param (
        [Parameter(Mandatory=$true)]  
        [ValidateSet("Chat", "SentimentAndTickerAnalysis", "SentimentAnalysis", "IntentAnalysis","IntentAndSubjectAnalysis")]
        $mode,
        [Parameter(Mandatory=$false)] 
        $instructor = "You are a helpful AI. You answer as concisely as possible.",
        [Parameter(Mandatory=$false)] 
        $assistantReply = "Hello! I'm a ChatGPT-3.5 Model. How can I help you?"
    )

    switch ($mode)
    {
        "Chat" {
            $instructor = $instructor
            $assistantReply = $assistantReply
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

    [System.Collections.ArrayList]$promptToReturn = @(
        @{
            role = "system"
            content = $instructor
        },
        @{
            role = "assistant"
            content = $assistantReply
        }
    )
    
    return [System.Collections.ArrayList]$promptToReturn
}

function New-OpenAICompletionConversation {
    <#
    .SYNOPSIS
    This function creates a new conversation with the OpenAI Completion API to generate AI-assisted responses to user queries.
    .DESCRIPTION
    The New-OpenAICompletionConversation function allows users to initiate a new conversation with the OpenAI Completion API. The function takes in user queries, an API key, and various optional parameters that modify the behavior of the API.
    .PARAMETER Character
    This parameter is optional and allows users to specify a pre-defined character model for generating responses. Valid options are "Chat", "SentimentAndTickerAnalysis", "SentimentAnalysis", "IntentAnalysis", and "IntentAndSubjectAnalysis".
    .PARAMETER query
    This parameter is mandatory and specifies the user query for which the OpenAI Completion API will generate responses.
    .PARAMETER APIKey
    This parameter is mandatory and specifies the API key that the function will use to authenticate with the OpenAI Completion API.
    .PARAMETER instructor
    This parameter is optional and specifies the role of the AI. By default, it is set to "You are a helpful AI. You answer as concisely as possible."
    .PARAMETER assistantReply
    This parameter is optional and specifies the initial message that the AI will send to the user. By default, it is set to "Hello! I'm a ChatGPT-3.5 Model. How can I help you?"
    .PARAMETER model
    This parameter is optional and allows users to specify a different GPT-3.5 model to use for generating responses. By default, it is set to "gpt-3.5-turbo".
    .PARAMETER stop
    This parameter is optional and specifies a string that the OpenAI Completion API will use to indicate the end of a response. By default, it is set to "\n".
    .PARAMETER temperature
    This parameter is optional and specifies the "creativity" of the AI-generated responses. Valid values are between 0 and 1, with higher values indicating more creative responses. By default, it is set to 0.4.
    .PARAMETER max_tokens
    This parameter is optional and specifies the maximum number of tokens (words) that the OpenAI Completion API will use to generate a response. By default, it is set to 900.
    .PARAMETER filePath
    This parameter is optional and specifies the path to a file that contains previous conversation messages. If provided, the function will use these messages to generate more context-aware responses.
    .PARAMETER ShowOutput
    This parameter is optional and specifies whether or not to display the output of the OpenAI Completion API.
    .PARAMETER ShowTokenUsage
    This parameter is optional and specifies whether or not to display the number of tokens used by the OpenAI Completion API to generate a response.
    .INPUTS
    None.
    .OUTPUTS
    The function returns an updated prompt with the user query and the response from the CompletionAPI.
    .EXAMPLE
    PS C:> New-OpenAICompletionConversation -query "What is the weather like today?" -APIKey "YOUR_API_KEY"
    This example initiates a new conversation with the OpenAI Completion API and generates AI-generated responses to the query "What is the weather like today?".
    
    #>
    param (
        [Parameter(Mandatory=$false)][ValidateSet("Chat", "SentimentAndTickerAnalysis","SentimentAnalysis","IntentAnalysis","IntentAndSubjectAnalysis")][System.Object]$Character,              
        [Parameter(Mandatory=$true)]  [string]$query,                         
        [Parameter(Mandatory=$true)]  [string]$APIKey,                        
        [Parameter(Mandatory=$false)] $instructor = "You are a helpful AI. You answer as concisely as possible.",
        [Parameter(Mandatory=$false)] $assistantReply = "Hello! I'm a ChatGPT-3.5 Model. How can I help you?",
        [Parameter(Mandatory=$false)] [string]$model = "gpt-3.5-turbo",       
        [Parameter(Mandatory=$false)] [string]$stop = "\n",                   
        [Parameter(Mandatory=$false)] [double]$temperature = 0.4,             
        [Parameter(Mandatory=$false)] [int]$max_tokens = 900,                 
        [Parameter(Mandatory=$false)] [string]$filePath,                     
        [Parameter(Mandatory=$false)] [bool]$ShowOutput = $false,           
        [Parameter(Mandatory=$false)] [bool]$ShowTokenUsage = $false,        
        [Parameter(Mandatory=$false)] [string]$UseAzure,
        [Parameter(Mandatory=$false)] [string]$DeploymentName
    )

    Write-Verbose ("ShellGPT-New-OpenAICompletionConversation @ "+(Get-Date)+" | Initializing new conversation...")

    if ($Character -eq $null)
    {
        Write-Verbose ("ShellGPT-New-OpenAICompletionConversation @ "+(Get-Date)+" | Character is not provided.") 
        
        if ($filePath)
        {   
            Write-Verbose ("ShellGPT-New-OpenAICompletionConversation @ "+(Get-Date)+" | FilePath is provided: "+($filePath)) 

            [System.Collections.ArrayList]$promptForAPI = New-OpenAICompletionPrompt -query $query -instructor $instructor -role "user" -assistantReply $assistantReply -filePath $filePath -model $model
            Write-Verbose ("ShellGPT-New-OpenAICompletionConversation @ "+(Get-Date)+" | Prompt is: "+($promptForAPI | Out-String))  
        }
        else {
            Write-Verbose ("ShellGPT-New-OpenAICompletionConversation @ "+(Get-Date)+" | FilePath is not provided") 

            [System.Collections.ArrayList]$promptForAPI = New-OpenAICompletionPrompt -query $query -instructor $instructor -role "user" -assistantReply $assistantReply -model $model
            Write-Verbose ("ShellGPT-New-OpenAICompletionConversation @ "+(Get-Date)+" | Prompt is: "+($promptForAPI | Out-String))   
        }
    }
    else 
    {
        Write-Verbose ("ShellGPT-New-OpenAICompletionConversation @ "+(Get-Date)+" | Character is provided: "+$Character) 

        [System.Collections.ArrayList]$characterPrompt= Set-OpenAICompletionCharacter -mode $Character -instructor $instructor -assistantReply $assistantReply
        Write-Verbose ("ShellGPT-New-OpenAICompletionConversation @ "+(Get-Date)+" | Character prompt is: ") 
        If ($filePath)
        {
            Write-Verbose ("ShellGPT-New-OpenAICompletionConversation @ "+(Get-Date)+" | FilePath is provided: "+($filePath)) 

            [System.Collections.ArrayList]$promptForAPI = New-OpenAICompletionPrompt -query $query -role "user" -previousMessages $characterPrompt -filePath $filePath -model $model
            Write-Verbose ("ShellGPT-New-OpenAICompletionConversation @ "+(Get-Date)+" | Prompt is: "+($promptForAPI | Out-String))  
        }

        else {
            Write-Verbose ("ShellGPT-New-OpenAICompletionConversation @ "+(Get-Date)+" | FilePath is not provided") 

            [System.Collections.ArrayList]$promptForAPI = New-OpenAICompletionPrompt -query $query -role "user" -previousMessages $characterPrompt -model $model
            Write-Verbose ("ShellGPT-New-OpenAICompletionConversation @ "+(Get-Date)+" | Prompt is: "+($promptForAPI | Out-String))   
        }
        
    }
    
    Write-Verbose ("ShellGPT-New-OpenAICompletionConversation @ "+(Get-Date)+" | Calling OpenAI Completion API with prompt...") 
    if ($UseAzure)
    {
        [System.Collections.ArrayList]$promptToReturn = Invoke-OpenAICompletion -Prompt $promptForAPI -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens -model $model -stop $stop -ShowTokenUsage $ShowTokenUsage -ShowOutput $ShowOutput -UseAzure $UseAzure -DeploymentName $DeploymentName
    }
    else {
        [System.Collections.ArrayList]$promptToReturn = Invoke-OpenAICompletion -Prompt $promptForAPI -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens -model $model -stop $stop -ShowTokenUsage $ShowTokenUsage -ShowOutput $ShowOutput
    }

        
    return [System.Collections.ArrayList]$promptToReturn
}

function Add-OpenAICompletionMessageToConversation {
    <#
    .SYNOPSIS
    This function adds a user query to a conversation with previous messages and obtains a response using the OpenAI Completion API.
    .DESCRIPTION
    The Add-OpenAICompletionMessageToConversation function takes in a user query, an array of previous messages in the conversation, an API key for the OpenAI Completion API, and various optional parameters to generate a response from the API. 
    The function then returns the response from the API along with the updated previous messages.
    .PARAMETER query
    The user's query to be added to the conversation.
    .PARAMETER previousMessages
    An array of previous messages in the conversation.
    .PARAMETER APIKey
    API key for the OpenAI Completion API.
    .PARAMETER model
    The model to use from the endpoint. Default value is "gpt-3.5-turbo".
    .PARAMETER stop
    The stop instructor for the model. Default value is "\n".
    .PARAMETER temperature
    The temperature value to use for sampling. Default value is 0.4.
    .PARAMETER max_tokens
    The maximum number of tokens to generate in the response. Default value is 900.
    .PARAMETER filePath
    The path to the file containing the previous messages in the conversation.
    .PARAMETER ShowOutput
    A switch parameter to determine if the output of the OpenAI Completion API should be displayed. Default value is $false.
    .PARAMETER ShowTokenUsage
    A switch parameter to determine if the number of tokens used in the response should be displayed. Default value is $false.
    .INPUTS
    None. The function does not accept pipeline input.
    .OUTPUTS
    The function returns a System.Collections.ArrayList object containing the response from the OpenAI Completion API and the updated previous messages in the conversation.
    .EXAMPLE
    $previousMessages = New-OpenAICompletionConversation -query "Hello, how are you?" -previousMessages $previousMessages -APIKey "YOUR_API_KEY"
    Add-OpenAICompletionMessageToConversation -query "Alright. Whats the capitol of Switzerland?" -previousMessages $previousMessages -APIKey "YOUR_API_KEY"
    This example adds a user query "Alright. Whats the capitol of Switzerland?" to a conversation with previous messages "Hello, how are you?" The function then obtains a response using the OpenAI Completion API and displays the output.
    #>

    param (
        [Parameter(Mandatory=$true)][string]$query,                         
        [Parameter(Mandatory=$true)][System.Collections.ArrayList]$previousMessages,       
        [Parameter(Mandatory=$true)][string]$APIKey,    
        [Parameter(Mandatory=$true)][string]$UseAzure,     
        [Parameter(Mandatory=$true)][string]$DeploymentName,                             
        [Parameter(Mandatory=$false)][string]$model = "gpt-3.5-turbo",      
        [Parameter(Mandatory=$false)][string]$stop = "\n",                   
        [Parameter(Mandatory=$false)][double]$temperature = 0.4,             
        [Parameter(Mandatory=$false)][int]$max_tokens = 900,                  
        [Parameter(Mandatory=$false)][string]$filePath,                       
        [Parameter(Mandatory=$false)][bool]$ShowOutput = $false,                   
        [Parameter(Mandatory=$false)][bool]$ShowTokenUsage = $false             
    )

    if ($filePath)
    {
        Write-Verbose ("ShellGPT-Add-OpenAICompletionMessageToConversation @ "+(Get-Date)+" | FilePath is provided: "+($filePath | Out-String))  
        [System.Collections.ArrayList]$prompt = New-OpenAICompletionPrompt -query $query -role "user" -previousMessages $previousMessages -filePath $filePath -model $model
    }
    else {
        Write-Verbose ("ShellGPT-Add-OpenAICompletionMessageToConversation @ "+(Get-Date)+" | FilePath is not provided")
        [System.Collections.ArrayList]$prompt = New-OpenAICompletionPrompt -query $query -role "user" -previousMessages $previousMessages -model $model
    }

    # Call the Invoke-ChatGPT function to get the response from the API.
    try {
        if ($useAzure){
            [System.Collections.ArrayList]$returnPromptFromAPI = Invoke-OpenAICompletion -prompt $prompt -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens -model $model -stop $stop -ShowTokenUsage $ShowTokenUsage -ShowOutput $ShowOutput -UseAzure $useAzure -DeploymentName $DeploymentName

        }
        else {
            [System.Collections.ArrayList]$returnPromptFromAPI = Invoke-OpenAICompletion -prompt $prompt -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens -model $model -stop $stop -ShowTokenUsage $ShowTokenUsage -ShowOutput $ShowOutput
        }
    }
    catch {
        [System.Collections.ArrayList]$returnPromptFromAPI = $prompt }

    
    # Return the response from the API and the updated previous messages.
    return [System.Collections.ArrayList]$returnPromptFromAPI
    
}

function New-OpenAIEdit {
    <#
    .SYNOPSIS
    This PowerShell function connects to the OpenAI Edit API to execute a given instruction on a specified model using a given prompt, with the option to specify temperature for sampling.
    .DESCRIPTION
    The New-OpenAIEdit function allows users to interact with the OpenAI Edit API, which takes a prompt as input and applies an instruction to it, generating a new output. This function handles the API request by constructing the necessary HTTP request headers and body and parsing the API response. The user must provide a prompt, an API key for authentication, an instruction for the model, and can optionally specify a model and temperature value for sampling.
    .PARAMETER query
    The prompt to send to the API to act upon.
    .PARAMETER APIKey
    The API key to authenticate the request.
    .PARAMETER instruction
    The instruction for the model like "Fix the grammar".
    .PARAMETER model
    The model to use from the endpoint. This parameter is optional and has a default value of "text-davinci-edit-001" if not specified. Valid options for this parameter are "text-davinci-edit-001" and "code-davinci-edit-001".
    .PARAMETER temperature
    The temperature value to use for sampling. This parameter is optional and has a default value of 0.4 if not specified.
    .INPUTS
    This function does not take any input from the pipeline.
    .OUTPUTS
    The function outputs the response text generated by the API in response to the prompt provided by the user.
    .EXAMPLE
    Example usage:
    $APIKey = "myAPIKey1234"
    $prompt = "The quick brown fox jumps over the lazy dog."
    $instruction = "Fix the grammar."
    New-OpenAIEdit -query $prompt -APIKey $APIKey -instruction $instruction
    This command sends a prompt to the OpenAI Edit API with the instruction to fix the grammar. The function returns the edited text response generated by the API.
    #>

    param (
        [Parameter(Mandatory=$true)]
        [string]$query,                                    # The prompt to send to the API to act upon.
        [Parameter(Mandatory=$true)]
        [string]$APIKey,                                   # The API key to authenticate the request.
        [Parameter(Mandatory=$true)]
        [string]$instruction,                              # The instruction for the model like "Fix the grammar"
        [Parameter(Mandatory=$false)]
        [ValidateSet("text-davinci-edit-001", "code-davinci-edit-001")]
        [string]$model = "text-davinci-edit-001",         # The model to use from the endpoint.
        [Parameter(Mandatory=$false)]
        [double]$temperature = 0.4                        # The temperature value to use for sampling.
    )

    #Building Request for API
    $headers = @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $APIKey"
    }

    $RequestBody = @{
        model = $model
        input = $query
        instruction = $instruction
        temperature= $temperature
    } 

    #Convert the whole Body to be JSON, so that API can interpret it
    $RequestBody = $RequestBody | ConvertTo-Json

    $RestMethodParameter=@{
        Method='Post'
        Uri ='https://api.openai.com/v1/edits'
        body=$RequestBody
        Headers=$Headers
    }

    try {
        #Call the OpenAI Edit API
        $APIresponse = Invoke-RestMethod @RestMethodParameter

        #Extract Textresponse from API response
        $convertedResponseForOutput = $APIresponse.choices.text

        $outputColor = "Green"
    }
    catch {
        # If there was an error, define an error message to the written.
        $errorToReport = $_.Exception.Message
        $errorDetails = $_.ErrorDetails.Message
        $convertedResponseForOutput = "Unable to handle Error: "+$errorToReport+" See Error details below. Retry query. If the error persists, consider exporting your current prompt and to continue later."

        $outputColor = "Red"
    }

    #Output the text response.
    write-host "EditAPI:"$convertedResponseForOutput -ForegroundColor $outputColor

    if ($errorDetails)
        {
            write-host "ErrorDetails:"$errorDetails -ForegroundColor "Red"
            $convertedResponseForOutput = "Error. See above for details."
        }

    return $convertedResponseForOutput
}

function New-OpenAIImage {
    param (
        [Parameter(Mandatory=$true)]
        [string]$query,                     # The prompt to send to the API to act upon.
        [Parameter(Mandatory=$true)]
        [string]$APIKey,                    # The API key to authenticate the request.
        [Parameter(Mandatory=$false)]
        [int]$n = 1,                        # The temperature value to use for sampling.
        [Parameter(Mandatory=$false)]
        [ValidateSet("256x256", "512x512", "1024x1024")]
        [string]$size = "256x256"           # The model to use from the endpoint.
    )

    #Building Request for API
    $headers = @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $APIKey"
    }

    $RequestBody = @{
        prompt = $query
        n = $n
        size = $size
    } 

    #Convert the whole Body to be JSON, so that API can interpret it
    $RequestBody = $RequestBody | ConvertTo-Json

    $RestMethodParameter=@{
        Method='Post'
        Uri ='https://api.openai.com/v1/images/generations'
        body=$RequestBody
        Headers=$Headers
    }

    try {
        #Call the OpenAI Edit API
        $APIresponse = Invoke-RestMethod @RestMethodParameter

        #Extract Textresponse from API response
        $convertedResponseForOutput = $APIresponse.data.url

        $outputColor = "Green"
    }
    catch {
        # If there was an error, define an error message to the written.
        $errorToReport = $_.Exception.Message
        $errorDetails = $_.ErrorDetails.Message
        $convertedResponseForOutput = "Unable to handle Error: "+$errorToReport+" See Error details below. Retry query. If the error persists, consider exporting your current prompt and to continue later."

        $outputColor = "Red"
    }

    if ($errorDetails)
        {
            write-host "ErrorDetails:"$errorDetails -ForegroundColor "Red"
            $convertedResponseForOutput = "Error. See above for details."
        }

    return $convertedResponseForOutput
}

function Get-OpenAIModels {
    param (
        [Parameter(Mandatory=$true)]
        [string]$APIKey        # The API key to authenticate the request.
    )

    $uri = 'https://api.openai.com/v1/models'

    #Building Request for API
    $headers = @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $APIKey"
    }

    $RestMethodParameter=@{
        Method='Get'
        Uri = $uri
        Headers=$Headers
    }

    try {
        #Call the OpenAI Edit API
        $APIresponse = Invoke-RestMethod @RestMethodParameter

        $convertedResponseForOutput = $APIresponse.data | Select-Object id, owned_by 
        
    }
    catch {
        # If there was an error, define an error message to the written.
        $errorToReport = $_.Exception.Message
        $errorDetails = $_.ErrorDetails.Message
        $convertedResponseForOutput = "Unable to handle Error: "+$errorToReport+" See Error details below. Retry query. If the error persists, consider exporting your current prompt and to continue later."
    }

    if ($errorDetails)
        {
            write-host "ErrorDetails:"$errorDetails -ForegroundColor "Red"
            $convertedResponseForOutput = "Error. See above for details."
        } 

    return $convertedResponseForOutput
}

function Get-OpenAIModelById {
    param (
        [Parameter(Mandatory=$true, ParameterSetName='Retrieve')]
        [string]$ModelId,
        [Parameter(Mandatory=$true)]
        [string]$APIKey        # The API key to authenticate the request.
    )


    $uri = 'https://api.openai.com/v1/models/'+$ModelId
    
    #Building Request for API
    $headers = @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $APIKey"
    }

    $RestMethodParameter=@{
        Method='Get'
        Uri = $uri
        Headers=$Headers
    }

    try {
        #Call the OpenAI Edit API
        $APIresponse = Invoke-RestMethod @RestMethodParameter

        $convertedResponseForOutput = $APIresponse
        
    }
    catch {
        # If there was an error, define an error message to the written.
        $errorToReport = $_.Exception.Message
        $errorDetails = $_.ErrorDetails.Message
        $convertedResponseForOutput = "Unable to handle Error: "+$errorToReport+" See Error details below. Retry query. If the error persists, consider exporting your current prompt and to continue later."
    }

    if ($errorDetails)
        {
            write-host "ErrorDetails:"$errorDetails -ForegroundColor "Red"
            $convertedResponseForOutput = "Error. See above for details."
        } 

    return $convertedResponseForOutput
}

function Get-OpenAIFiles {
    param (
        [Parameter(Mandatory=$true)]
        [string]$APIKey        # The API key to authenticate the request.
    )

    #Building Request for API
    $ContentType = "application/json"
    $uri = 'https://api.openai.com/v1/files'
    $method = 'Get'
 
    $headers = @{
        "Content-Type" = $ContentType
        "Authorization" = "Bearer $APIKey"
    }
    $RestMethodParameter=@{
        Method=$method
        Uri =$uri
        body=$body
        Headers=$Headers
    }

    try {
        #Call the OpenAI Edit API
        $APIresponse = Invoke-RestMethod @RestMethodParameter
        $convertedResponseForOutput = $APIresponse.data | select-object id, purpose, filename, status, bytes
        #Extract Textresponse from API response
        
    }
    catch {
        # If there was an error, define an error message to the written.
        $errorToReport = $_.Exception.Message
        $errorDetails = $_.ErrorDetails.Message
        $convertedResponseForOutput = "Unable to handle Error: "+$errorToReport+" See Error details below. Retry query. If the error persists, consider exporting your current prompt and to continue later."
    }

    if ($errorDetails)
        {
            write-host "ErrorDetails:"$errorDetails -ForegroundColor "Red"
            $convertedResponseForOutput = "Error. See above for details."
        } 

    return $convertedResponseForOutput 
}

function Get-OpenAIFileById {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FileIdToRetrieve,
        [Parameter(Mandatory=$true)]
        [string]$APIKey        # The API key to authenticate the request.
    )

    #Building Request for API
    $ContentType = "application/json"
    $uri = 'https://api.openai.com/v1/files/'+$FileIdToRetrieve
    $method = 'Get'

    $headers = @{
        "Content-Type" = $ContentType
        "Authorization" = "Bearer $APIKey"
    }

    $RestMethodParameter=@{
        Method=$method
        Uri =$uri
        body=$body
        Headers=$Headers
    }

    try {
        #Call the OpenAI Edit API
        $APIresponse = Invoke-RestMethod @RestMethodParameter
        $convertedResponseForOutput = $APIresponse
        #Extract Textresponse from API response
        
    }
    catch {
        # If there was an error, define an error message to the written.
        $errorToReport = $_.Exception.Message
        $errorDetails = $_.ErrorDetails.Message
        $convertedResponseForOutput = "Unable to handle Error: "+$errorToReport+" See Error details below. Retry query. If the error persists, consider exporting your current prompt and to continue later."
    }

    if ($errorDetails)
        {
            write-host "ErrorDetails:"$errorDetails -ForegroundColor "Red"
            $convertedResponseForOutput = "Error. See above for details."
        } 

    return $convertedResponseForOutput
    
}

function Get-OpenAIFileContent {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FileIdToRetrieveContent,
        [Parameter(Mandatory=$true)]
        [string]$APIKey        # The API key to authenticate the request.
    )

    #Building Request for API
    $ContentType = "application/json"
    $uri = 'https://api.openai.com/v1/files/'+$FileIdToRetrieveContent+'/content'
    $method = 'Get'

    $headers = @{
        "Content-Type" = $ContentType
        "Authorization" = "Bearer $APIKey"
    }

    $RestMethodParameter=@{
        Method=$method
        Uri =$uri
        body=$body
        Headers=$Headers
    }

    try {
        #Call the OpenAI Edit API
        $APIresponse = Invoke-RestMethod @RestMethodParameter
        $convertedResponseForOutput = $APIresponse
        
    }
    catch {
        # If there was an error, define an error message to the written.
        $errorToReport = $_.Exception.Message
        $errorDetails = $_.ErrorDetails.Message
        $convertedResponseForOutput = "Unable to handle Error: "+$errorToReport+" See Error details below. Retry query. If the error persists, consider exporting your current prompt and to continue later."
    }

    if ($errorDetails)
        {
            write-host "ErrorDetails:"$errorDetails -ForegroundColor "Red"
            $convertedResponseForOutput = "Error. See above for details."
        } 

    return $convertedResponseForOutput
    
}

function New-OpenAIFile {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FileToUpload,                                          # The trainings file to upload. Provide the full path to it.
        [Parameter(Mandatory=$true)]            
        [string]$APIKey,                                                # The API key to authenticate the request.
        [Parameter(Mandatory=$false)]
        [string]$Purpose = "fine-tune"                                  # The purpose label for the file. The API currently expects the value "fine-tune" only.

    )
    
    # Read the file into a byte array
    $fileBytes = [System.IO.File]::ReadAllBytes($FileToUpload)

    # Create the multipart/form-data request body
    $body = [System.Net.Http.MultipartFormDataContent]::new()
    $fileContent = [System.Net.Http.ByteArrayContent]::new($fileBytes)
    $body.Add($fileContent, "file", [System.IO.Path]::GetFileName($FileToUpload))
    $body.Add([System.Net.Http.StringContent]::new($purpose), "purpose")

    $ContentType = "multipart/form-data"
    $uri = 'https://api.openai.com/v1/files'
    $method = 'Post'
    

    $headers = @{
        "Content-Type" = $ContentType
        "Authorization" = "Bearer $APIKey"
    }

    $RestMethodParameter=@{
        Method=$method
        Uri =$uri
        body=$body
        Headers=$Headers
    }

    try {
        #Call the OpenAI Edit API
        $APIresponse = Invoke-RestMethod @RestMethodParameter
        $convertedResponseForOutput = $APIresponse
        
    }
    catch {
        # If there was an error, define an error message to the written.
        $errorToReport = $_.Exception.Message
        $errorDetails = $_.ErrorDetails.Message
        $convertedResponseForOutput = "Unable to handle Error: "+$errorToReport+" See Error details below. Retry query. If the error persists, consider exporting your current prompt and to continue later."
    }

    if ($errorDetails)
        {
            write-host "ErrorDetails:"$errorDetails -ForegroundColor "Red"
            $convertedResponseForOutput = "Error. See above for details."
        } 

    return $convertedResponseForOutput 
}

function Remove-OpenAIFile {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FileIdToDelete,            # The Id of the File to delete
        [Parameter(Mandatory=$true)]
        [string]$APIKey                     # The API key to authenticate the request.
    )

    #Building Request for API
    $ContentType = "application/json"
    $uri = 'https://api.openai.com/v1/files/'+$FileIdToDelete
    $method = 'Delete'
    
    $headers = @{
        "Content-Type" = $ContentType
        "Authorization" = "Bearer $APIKey"
    }

    $RestMethodParameter=@{
        Method=$method
        Uri =$uri
        body=$body
        Headers=$Headers
    }

    try {
        #Call the OpenAI Edit API
        $APIresponse = Invoke-RestMethod @RestMethodParameter
        $convertedResponseForOutput = $APIresponse
        #Extract Textresponse from API response
        
    }
    catch {
        # If there was an error, define an error message to the written.
        $errorToReport = $_.Exception.Message
        $errorDetails = $_.ErrorDetails.Message
        $convertedResponseForOutput = "Unable to handle Error: "+$errorToReport+" See Error details below. Retry query. If the error persists, consider exporting your current prompt and to continue later."
    }

    if ($errorDetails)
        {
            write-host "ErrorDetails:"$errorDetails -ForegroundColor "Red"
            $convertedResponseForOutput = "Error. See above for details."
        } 

    return $convertedResponseForOutput
}

function Get-OpenAIFineTuneJobs {
    param (
        [Parameter(Mandatory=$true)]
        [string]$APIKey        # The API key to authenticate the request.
    )

     #Building Request for API
    $uri = 'https://api.openai.com/v1/fine-tunes'
    $method = 'Get'
     
    $headers = @{
         "Content-Type" = "application/json"
         "Authorization" = "Bearer $APIKey"
     }

     $RestMethodParameter=@{
         Method=$method
         Uri =$uri
         body=$RequestBody
         Headers=$Headers
     }
 
     try {
        #Call the OpenAI Edit API
        $APIresponse = Invoke-RestMethod @RestMethodParameter
        $convertedResponseForOutput = $APIresponse.data 
        
        #Extract Textresponse from API response
         
     }
     catch {
         # If there was an error, define an error message to the written.
         $errorToReport = $_.Exception.Message
         $errorDetails = $_.ErrorDetails.Message
         $convertedResponseForOutput = "Unable to handle Error: "+$errorToReport+" See Error details below. Retry query. If the error persists, consider exporting your current prompt and to continue later."
     }
 
     if ($errorDetails)
         {
             write-host "ErrorDetails:"$errorDetails -ForegroundColor "Red"
             $convertedResponseForOutput = "Error. See above for details."
         } 
 
     return $convertedResponseForOutput 
}

function Get-OpenAIFineTuneJobById {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FineTuneId,                # The Id of the FineTuneJob you want to get details on.
        [Parameter(Mandatory=$true)]
        [string]$APIKey                     # The API key to authenticate the request.
    )

    #Building Request for API
    $uri = 'https://api.openai.com/v1/fine-tunes/'+$FineTuneId
    $method = 'Get'
    $headers = @{
         "Content-Type" = "application/json"
         "Authorization" = "Bearer $APIKey"
    }
    
     $RestMethodParameter=@{
         Method=$method
         Uri =$uri
         body=$RequestBody
         Headers=$Headers
     }
 
     try {
         #Call the OpenAI Edit API
         $APIresponse = Invoke-RestMethod @RestMethodParameter
         $convertedResponseForOutput = $APIresponse
     
         #Extract Textresponse from API response
         
     }
     catch {
         # If there was an error, define an error message to the written.
         $errorToReport = $_.Exception.Message
         $errorDetails = $_.ErrorDetails.Message
         $convertedResponseForOutput = "Unable to handle Error: "+$errorToReport+" See Error details below. Retry query. If the error persists, consider exporting your current prompt and to continue later."
     }
 
     if ($errorDetails)
         {
             write-host "ErrorDetails:"$errorDetails -ForegroundColor "Red"
             $convertedResponseForOutput = "Error. See above for details."
         } 
 
     return $convertedResponseForOutput
    
}

function Get-OpenAIFineTuneEvents {
    param (
        [Parameter(Mandatory=$true)]            
        [string]$FineTuneIdToListEvents,                # The Id of the FineTuneJob you want to get the events for.
        [Parameter(Mandatory=$true)]
        [string]$APIKey                                 # The API key to authenticate the request.
    )

    #Building Request for API
    
    $uri = 'https://api.openai.com/v1/fine-tunes/'+$FineTuneIdToListEvents+'/events'
    $method = 'Get'
 
    $headers = @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $APIKey"
    }

    $RestMethodParameter=@{
        Method=$method
        Uri =$uri
        body=$RequestBody
        Headers=$Headers
    }
 
     try {
        #Call the OpenAI Edit API
        $APIresponse = Invoke-RestMethod @RestMethodParameter
        $convertedResponseForOutput = $APIresponse
         
     }
     catch {
         # If there was an error, define an error message to the written.
         $errorToReport = $_.Exception.Message
         $errorDetails = $_.ErrorDetails.Message
         $convertedResponseForOutput = "Unable to handle Error: "+$errorToReport+" See Error details below. Retry query. If the error persists, consider exporting your current prompt and to continue later."
     }
 
     if ($errorDetails)
         {
             write-host "ErrorDetails:"$errorDetails -ForegroundColor "Red"
             $convertedResponseForOutput = "Error. See above for details."
         } 
 
     return $convertedResponseForOutput
}

function Remove-OpenAIFineTuneModel {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ModelToDelete,                 # The Name of the Model you want to delete.
        [Parameter(Mandatory=$true)]
        [string]$APIKey                         # The API key to authenticate the request.
    )

    $uri = 'https://api.openai.com/v1/models/'+$ModelToDelete
    $method = 'Delete'
     
    $headers = @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $APIKey"
    }

    $RestMethodParameter=@{
        Method=$method
        Uri =$uri
        body=$RequestBody
        Headers=$Headers
     }
 
     try {
        #Call the OpenAI Edit API
        $APIresponse = Invoke-RestMethod @RestMethodParameter
        $convertedResponseForOutput = $APIresponse
         
     }
     catch {
        # If there was an error, define an error message to the written.
        $errorToReport = $_.Exception.Message
        $errorDetails = $_.ErrorDetails.Message
        $convertedResponseForOutput = "Unable to handle Error: "+$errorToReport+" See Error details below. Retry query. If the error persists, consider exporting your current prompt and to continue later."
    }
 
    if ($errorDetails)
        {
            write-host "ErrorDetails:"$errorDetails -ForegroundColor "Red"
            $convertedResponseForOutput = "Error. See above for details."
        } 
 
     return $convertedResponseForOutput
}

function Stop-OpenAIFineTuneJob {
    param (
        [Parameter(Mandatory=$true, ParameterSetName='Cancel')]
        [string]$FineTuneIdToCancel,            # The Id of the FineTuneJob you want to cancel.
        [Parameter(Mandatory=$true)]
        [string]$APIKey                         # The API key to authenticate the request.
    )

    #Building Request for API
     
    $uri = 'https://api.openai.com/v1/fine-tunes/'+$FineTuneIdToCancel+'/cancel'
    $method = 'Post'
    
    $headers = @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $APIKey"
    }

    $RestMethodParameter=@{
        Method=$method
        Uri =$uri
        body=$RequestBody
        Headers=$Headers
    }
 
    try {
        #Call the OpenAI Edit API
        $APIresponse = Invoke-RestMethod @RestMethodParameter
        $convertedResponseForOutput = $APIresponse
         
     }
     catch {
        # If there was an error, define an error message to the written.
        $errorToReport = $_.Exception.Message
        $errorDetails = $_.ErrorDetails.Message
        $convertedResponseForOutput = "Unable to handle Error: "+$errorToReport+" See Error details below. Retry query. If the error persists, consider exporting your current prompt and to continue later."
     }
 
     if ($errorDetails)
         {
             write-host "ErrorDetails:"$errorDetails -ForegroundColor "Red"
             $convertedResponseForOutput = "Error. See above for details."
         } 
 
     return $convertedResponseForOutput
    
}

function New-OpenAIFineTuneJob {
    param (
        [Parameter(Mandatory=$true)]
        [string]$trainingFileId,                # The Id of the trainings file (.jsonl) you want to create a fine tuned model for.
        [Parameter(Mandatory=$true)]
        [string]$APIKey,                        # The API key to authenticate the request.
        [Parameter(Mandatory=$false)]
        [string]$model,                         # The name of the model you want to create a fine-tuned version of.
        [Parameter(Mandatory=$false)]
        [integer]$n_epochs,                      # The number of epochs to train the model for. An epoch refers to one full cycle through the training dataset.
        [Parameter(Mandatory=$false)]
        [string]$suffix,                        # A string of up to 40 characters that will be added to your fine-tuned model name
        [Parameter(Mandatory=$false)]
        [string]$validation_fileId,             # The ID of an uploaded file that contains validation data.
        [Parameter(Mandatory=$false)]
        [int]$batch_size,                       # The batch size to use for training. The batch size is the number of training examples used to train a single forward and backward pass.
        [Parameter(Mandatory=$false)]
        [double]$learning_rate_multiplier,      # The learning rate multiplier to use for training. The fine-tuning learning rate is the original learning rate used for pretraining multiplied by this value.
        [Parameter(Mandatory=$false)]
        [double]$prompt_loss_weight,            # The weight to use for loss on the prompt tokens. This controls how much the model tries to learn to generate the prompt (as compared to the completion which always has a weight of 1.0), and can add a stabilizing effect to training when completions are short.
        [Parameter(Mandatory=$false)]
        [bool]$compute_classification_metrics,  # If set, we calculate classification-specific metrics such as accuracy and F-1 score using the validation set at the end of every epoch
        [Parameter(Mandatory=$false)]
        [integer]$classification_n_classes,     # The number of classes in a classification task.
        [Parameter(Mandatory=$false)]
        [string]$classification_positive_class, # The positive class in binary classification.
        [Parameter(Mandatory=$false)]
        [array]$classification_betas           # If this is provided, we calculate F-beta scores at the specified beta values. The F-beta score is a generalization of F-1 score. This is only used for binary classification.
    )

    #Building Request for API
    $uri = 'https://api.openai.com/v1/fine-tunes'
    $method = 'Post'

    $RequestBody = @{
        training_file = $trainingFileId
    } 

    if ($model)
    {
        $RequestBody.Add("model", $model)
    }

    if ($epochs)
    {
        $RequestBody.Add("n_epochs", $n_epochs)
    }

    if ($suffix)
    {
        $RequestBody.Add("suffix", $suffix)
    }

    if ($validation_fileId)
    {
        $RequestBody.Add("validation_file", $validation_fileId)
    }

    if ($batch_size)
    {
        $RequestBody.Add("batch_size", $batch_size)
    }

    if ($learning_rate_multiplier)
    {
        $RequestBody.Add("learning_rate_multiplier", $learning_rate_multiplier)
    }

    if ($prompt_loss_weight)
    {
        $RequestBody.Add("prompt_loss_weight", $prompt_loss_weight)
    }

    if ($compute_classification_metrics)
    {
        $RequestBody.Add("compute_classification_metrics", $compute_classification_metrics)
    }

    if ($classification_n_classes)
    {
        $RequestBody.Add("classification_n_classes", $classification_n_classess)
    }

    if ($classification_positive_classes)
    {
        $RequestBody.Add("classification_positive_classes", $classification_positive_classes)
    }

    if ($classification_betas)
    {
        $RequestBody.Add("classification_betas", $classification_betass)
    }
    
    $RequestBody = $RequestBody | ConvertTo-Json
    
    $headers = @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $APIKey"
    }
    $RestMethodParameter=@{
        Method=$method
        Uri =$uri
        body=$RequestBody
        Headers=$Headers
     }
 
     try {
        #Call the OpenAI Edit API
        $APIresponse = Invoke-RestMethod @RestMethodParameter
        $convertedResponseForOutput = $APIresponse
         
     }
     catch {
        # If there was an error, define an error message to the written.
        $errorToReport = $_.Exception.Message
        $errorDetails = $_.ErrorDetails.Message
        $convertedResponseForOutput = "Unable to handle Error: "+$errorToReport+" See Error details below. Retry query. If the error persists, consider exporting your current prompt and to continue later."
     }
 
     if ($errorDetails)
        {
            write-host "ErrorDetails:"$errorDetails -ForegroundColor "Red"
            $convertedResponseForOutput = "Error. See above for details."
        } 
 
     return $convertedResponseForOutput 
}

function New-OpenAIFineTuneTrainingFile {
    param (
        [Parameter(Mandatory=$true)]
        [string]$prompt,                # The prompt to create a training file with. This will be the first prompt.
        [Parameter(Mandatory=$true)]
        [string]$completion,            # The completion for the first prompt.
        [Parameter(Mandatory=$true)]
        [string]$Path                   # the full path to the .JSONL file to be created and stored. 
    )

    $objects = @(
        @{ prompt = $prompt ; completion = $completion }
    )
    $jsonStrings = $objects | ForEach-Object { $_ | ConvertTo-Json -Compress }

    if ($Path.EndsWith(".jsonl"))
    {
        $NewName = $Path
    }
    else {
        $NewName = ($path+".jsonl")
    }
    
    try {
        New-Item -Name $NewName -ItemType File -Force
        $jsonStrings | Out-File -FilePath $NewName -Encoding utf8 -Append -Force
    }
    catch {
        $errorToReport = $_.Exception.Message
        $errorDetails = $_.ErrorDetails.Message
        $message = "Unable to handle Error: "+$errorToReport+" See Error details below."

        write-host "Error:"$message -ForegroundColor $outputColor

        if ($errorDetails)
            {
                write-host "ErrorDetails:"$errorDetails -ForegroundColor "Red"
            }        
    }

}

function Import-OpenAIPromptFromJson {
    param (
        [Parameter(Mandatory=$true)]    
        [string]$Path                   #Required. The file path to the JSON file containing the prompt. This parameter is mandatory.
    )

    $promptJson = Get-Content -Path $Path -Raw
    $prompt = $promptJson | ConvertFrom-Json

    return $prompt
}

function Export-OpenAIPromptToJson {
    param (
        [Parameter(Mandatory=$true)]    
        [string]$Path,                 #The file path to the JSON file containing the prompt. This parameter is mandatory.
        [Parameter(Mandatory=$true)]    
        [System.Object]$prompt         #The prompt (System.Object) to export to a .JSON file.
    )

    $prompt | ConvertTo-Json | Out-File -Encoding utf8 -FilePath $path
    

    return $prompt
}

function New-OpenAIEmbedding {
    param (
        [Parameter(Mandatory=$true)]
        [string]$APIKey,                                 # The API key to authenticate the request.
        [Parameter(Mandatory=$false)]            
        [string]$text,                                   # The Id of the FineTuneJob you want to get the events for.
        [Parameter(Mandatory=$false)]            
        [string]$Model = "text-embedding-ada-002"        # The Id of the FineTuneJob you want to get the events for.
    )

    #Building Request for API
    $uri = 'https://api.openai.com/v1/embeddings'
    $method = 'Post'
 
    $headers = @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $APIKey"
    }

    $RequestBody = @{
        input = $text
        model = $Model
    } 

    #Convert the whole Body to be JSON, so that API can interpret it
    $RequestBody = $RequestBody | ConvertTo-Json

    $RestMethodParameter=@{
        Method=$method
        Uri =$uri
        body=$RequestBody
        Headers=$Headers
    }
 
     try {
        #Call the OpenAI Edit API
        $APIresponse = Invoke-RestMethod @RestMethodParameter
        $convertedResponseForOutput = $APIresponse
         
     }
     catch {
         # If there was an error, define an error message to the written.
         $errorToReport = $_.Exception.Message
         $errorDetails = $_.ErrorDetails.Message
         $convertedResponseForOutput = "Unable to handle Error: "+$errorToReport+" See Error details below. Retry query. If the error persists, consider exporting your current prompt and to continue later."
     }
 
     if ($errorDetails)
         {
             write-host "ErrorDetails:"$errorDetails -ForegroundColor "Red"
             $convertedResponseForOutput = "Error. See above for details."
         } 
 
     return $convertedResponseForOutput
    
}

function Convert-PDFtoText {
    <#
    .SYNOPSIS
    Converts a PDF file to a text, CSV, or JSON file.
    .DESCRIPTION
    The Convert-PDFtoText function takes a PDF file and converts it to a text file. You can also choose to export the data in CSV or JSON format. 
    If the PDF file is empty, the function returns a message indicating that it either has no text or consists only of pictures or a scan.
    .PARAMETER filePath
    The path to the PDF file you want to convert. This is a mandatory parameter.
    .PARAMETER TypeToExport
    Specifies the file format to export the data to. Valid options are "txt", "csv", or "json". This is a mandatory parameter.
    .INPUTS
    This function does not accept input from the pipeline.
    .OUTPUTS
    The function outputs the converted text file in the specified format.
    .EXAMPLE
    Convert-PDFtoText -filePath "C:\Documents\example.pdf" -TypeToExport "txt"
    This command converts the example.pdf file located in the C:\Documents folder to a text file.
    #>

	param(
		[Parameter(Mandatory=$true)]
        [string]$filePath,
        [Parameter(Mandatory=$true)]
        [ValidateSet("txt", "csv", "json")]
        [string]$TypeToExport
	)

    Write-Verbose ("ShellGPT-Convert-PDFtoText @ "+(Get-Date)+" | Convertig PDF to Text: "+($filepath)) 
    
    try 
    {
        Add-Type -Path "C:\Program Files\PackageManagement\NuGet\Packages\BouncyCastle.1.8.9\lib\BouncyCastle.Crypto.dll"
        Add-Type -Path "C:\Program Files\PackageManagement\NuGet\Packages\iTextSharp.5.5.13.3\lib\itextsharp.dll"
	    Write-Verbose ("ShellGPT-Convert-PDFtoText @ "+(Get-Date)+" | Loaded itextsharp.dll") 
    }
    
    catch
    {
        
    	Write-Host ("ShellGPT-Convert-PDFtoText @ "+(Get-Date)+" | itextsharp.dll not present. Make sure you installed it and it is in expected folder: C:\Program Files\PackageManagement\NuGet\Packages\iTextSharp.5.5.13.3\lib") -ForegroundColor Red
        Write-Host ("ShellGPT-Convert-PDFtoText @ "+(Get-Date)+" | Unable to handle Error "+($_.Exception.Message)) -ForegroundColor "Red"
    }

    try {
        $pdf = New-Object iTextSharp.text.pdf.pdfreader -ArgumentList $filePath
	    Write-Verbose ("ShellGPT-Convert-PDFtoText @ "+(Get-Date)+" | PDF was found.") 

        $text = ""
        for ($page = 1; $page -le $pdf.NumberOfPages; $page++){
            Write-Verbose ("ShellGPT-Convert-PDFtoText @ "+(Get-Date)+" | Parsing text...") 
            $text+=([iTextSharp.text.pdf.parser.PdfTextExtractor]::GetTextFromPage($pdf,$page))
        }	
        $pdf.Close()
    
    
        if ($text -eq "" -or $text -eq " " -or $text -eq $null)
        {
            Write-Host ("ShellGPT-Convert-PDFtoText @ "+(Get-Date)+" | PDF was found, but it looks like its empty. Either it really has no text or it consist only of pictures or a Scan. ShellGPT does not have OCR. The prompt will not have any additional content in it.") -ForegroundColor Red
        }
    
        Write-Verbose ("ShellGPT-Convert-PDFtoText @ "+(Get-Date)+" | Done parsing PDF. Preparing export to .txt") 

        if ($filePath.Contains("\"))
        {
            Write-Verbose ("ShellGPT-Convert-PDFtoText @ "+(Get-Date)+" | Filepath is the whole path. Splitting it up...") 
            $filename = $filepath.split("\")[($filepath.split("\")).count-1]
            $basenamefile = ($filename.Split(".pdf"))[0]
            $Outputfolder = ($filepath.split($basenamefile))[0]
        }
        else {
            Write-Verbose ("ShellGPT-Convert-PDFtoText @ "+(Get-Date)+" | Filepath is only filename. Indicates run in the dir where the script was launched") 
            $filename = $filePath
            $basenamefile = ($filename.Split(".pdf"))[0]
            $Outputfolder = ""
        }
    
        switch ($TypeToExport) {
            "txt" {
                $exportEnding = ".txt"
            }
            "csv" {
                $exportEnding = ".csv"
    
            }
            "json" {
                $exportEnding = ".json"
    
            }
            "jsonl" {
                $exportEnding = ".jsonl"
            }
            default {
                Write-Host ("ShellGPT-Convert-PDFtoText @ "+(Get-Date)+" | Invalid option for Switch.")
            }
        }
    
        Write-Verbose ("ShellGPT-Convert-PDFtoText @ "+(Get-Date)+" | Export type is: "+($exportEnding)) 
    
        $OutputPath = $Outputfolder+$basenamefile+$exportEnding
    
        Write-Verbose ("ShellGPT-Convert-PDFtoText @ "+(Get-Date)+" | Outputpath is: "+($OutputPath)) 
    
        $text | Out-File $OutputPath -Force

    }
    catch {
        Write-Host ("ShellGPT-Convert-PDFtoText @ "+(Get-Date)+" | PDF could not be loaded. Is itextsharp.dll present? Does the PDF exist? Is the Path valid?") -ForegroundColor Red
        Write-Host ("ShellGPT-Convert-PDFtoText @ "+(Get-Date)+" | Unable to handle Error "+($_.Exception.Message)) -ForegroundColor "Red"
    }
    
    return $OutputPath
}

function Get-ShellGPTHelpMessage {
    Write-Host ("ShellGPT @ "+(Get-Date)+" | To include a file for the model to reference in the prompt, use the following notation 'file | pathtofile | instruction' in the query.") -ForegroundColor DarkMagenta
    Write-Host ("ShellGPT @ "+(Get-Date)+" | Supported file types are: .txt, .pdf, .csv, .json") -ForegroundColor DarkMagenta
    Write-Host ("-------------------------------------------------------------------------------------------------------------------------") -ForegroundColor DarkGray
    Write-Host ("ShellGPT @ "+(Get-Date)+" | Example: file | C:\Users\Yanik\test.txt | Summarize this:") -ForegroundColor DarkGray
    Write-Host ("-------------------------------------------------------------------------------------------------------------------------") -ForegroundColor DarkGray
    Write-Host ("ShellGPT @ "+(Get-Date)+" | This will summarize the content in the file 'test.txt'") -ForegroundColor DarkGray
    Write-Host ("ShellGPT @ "+(Get-Date)+" | Example: file | C:\Users\Yanik\test.pdf | Summarize this:") -ForegroundColor DarkGray
    Write-Host ("ShellGPT @ "+(Get-Date)+" | This will create a .txt file with the content of the .PDF, read it and summarize the content in the file 'test.txt'") -ForegroundColor DarkGray
    Write-Host ("-------------------------------------------------------------------------------------------------------------------------") -ForegroundColor DarkGray
    Write-Host ("ShellGPT @ "+(Get-Date)+" | There are a few other commands available. ") -ForegroundColor DarkMagenta
    Write-Host ("-------------------------------------------------------------------------------------------------------------------------") -ForegroundColor DarkGray
    Write-Host ("ShellGPT @ "+(Get-Date)+" | Start a new conversation:  ") -ForegroundColor DarkGray
    Write-Host ("ShellGPT @ "+(Get-Date)+" | newconvo | ") -ForegroundColor DarkGray
    Write-Host ("-------------------------------------------------------------------------------------------------------------------------") -ForegroundColor DarkGray
    Write-Host ("ShellGPT @ "+(Get-Date)+" | Export the current prompt: ") -ForegroundColor DarkGray
    Write-Host ("ShellGPT @ "+(Get-Date)+" | export | ") -ForegroundColor DarkGray
    Write-Host ("-------------------------------------------------------------------------------------------------------------------------") -ForegroundColor DarkGray

    Write-Host ("ShellGPT @ "+(Get-Date)+" | Stop ShellGPT: ") -ForegroundColor DarkGray
    Write-Host ("ShellGPT @ "+(Get-Date)+" | quit | ") -ForegroundColor DarkGray
    Write-Host ("-------------------------------------------------------------------------------------------------------------------------") -ForegroundColor DarkGray

    Write-Host ("ShellGPT @ "+(Get-Date)+" | Stop ShellGPT and export the prompt: ") -ForegroundColor DarkGray
    Write-Host ("-------------------------------------------------------------------------------------------------------------------------") -ForegroundColor DarkGray
}

function Start-ShellGPT {
    <#
    .SYNOPSIS
    Start-ShellGPT is a PowerShell function that allows users to communicate with OpenAI's GPT-3.5 model. Users can select a character for the model to assume and provide queries or commands for the model to complete. 
    The function also allows users to continue a previous conversation by providing the path to a JSON file containing the previous conversation.
    .DESCRIPTION
    Start-ShellGPT is a PowerShell function that provides users with a shell interface to communicate with OpenAI's GPT-3.5 model. 
    Users can specify a character for the model to assume and provide queries or commands for the model to complete. 
    The function supports several parameters that allow users to configure the behavior of the model, including the temperature and maximum number of tokens. 
    Additionally, users can continue a previous conversation by providing the path to a JSON file containing the previous conversation.
    .PARAMETER APIKey
    The APIKey parameter is mandatory and specifies the API key to use when communicating with the OpenAI API.
    .PARAMETER model
    The model parameter is optional and specifies the name of the GPT-3.5 model to use. The default value is "gpt-3.5-turbo".
    .PARAMETER stop
    The stop parameter is optional and specifies the string used to stop the model from generating additional output. 
    The default value is "\n".
    .PARAMETER temperature
    The temperature parameter is optional and specifies the "temperature" to use when generating text. 
    The default value is 0.4.
    .PARAMETER max_tokens
    The max_tokens parameter is optional and specifies the maximum number of tokens to generate. 
    The default value is 900.
    .PARAMETER ShowOutput
    The ShowOutput parameter is optional and specifies whether to show the output of the model. 
    The default value is $false.
    .PARAMETER ShowTokenUsage
    The ShowTokenUsage parameter is optional and specifies whether to show the token usage of the model. 
    The default value is $false.
    .PARAMETER instructor
    The instructor parameter is optional and specifies the prompt that the model uses to generate text. 
    The default value is "You are a helpful AI. You answer as concisely as possible."
    .PARAMETER assistantReply
    The assistantReply parameter is optional and specifies the initial reply of the model when a new conversation is started. 
    The default value is "Hello! I'm a ChatGPT-3.5 Model. How can I help you?"
    .INPUTS
    Start-ShellGPT does not take any input by pipeline.
    .OUTPUTS
    Start-ShellGPT does not output anything to the pipeline.
    .EXAMPLE
    Start-ShellGPT -APIKey "my_api_key"
    This example starts a new conversation with the GPT-3.5 model using the specified API key.
    .EXAMPLE
    Start-ShellGPT -APIKey "my_api_key" -model "gpt-3.5"
    This example starts a new conversation with the GPT-3.5 model named "gpt-3.5" using the specified API key.
    .EXAMPLE
    Start-ShellGPT -APIKey "your_api_key"  -temperature 0.8 -max_tokens 1000
    This example starts a new conversation with the GPT-3.5 model "gpt-3.5-turbo" using the specified API key and sets the temperature to 0.8 and the maximum number of tokens to 1000.
    #>

    param (
        [Parameter(Mandatory=$true)][string]$APIKey,
        [Parameter(Mandatory=$false)][string]$UseAzure,
        [Parameter(Mandatory=$false)][string]$DeploymentName,  
        [Parameter(Mandatory=$false)][string]$model = "gpt-3.5-turbo",       
        [Parameter(Mandatory=$false)][string]$stop = "\n",                    
        [Parameter(Mandatory=$false)][double]$temperature = 0.4,             
        [Parameter(Mandatory=$false)][int]$max_tokens = 900,                 
        [Parameter(Mandatory=$false)][bool]$ShowOutput = $false,                    
        [Parameter(Mandatory=$false)][bool]$ShowTokenUsage = $false,                 
        [Parameter(Mandatory=$false)][string]$instructor = "You are a helpful AI. You answer as concisely as possible.",
        [Parameter(Mandatory=$false)] [string]$assistantReply = "Hello! I'm a ChatGPT-3.5 Model. How can I help you?"
    )

    Write-Verbose ("ShellGPT @ "+(Get-Date)+" | Initializing... ") 
    Write-Verbose ("ShellGPT @ "+(Get-Date)+" | Used Model is : "+($model)) 
    Write-Verbose ("ShellGPT @ "+(Get-Date)+" | Used stop instructor is : "+($stop))
    Write-Verbose ("ShellGPT @ "+(Get-Date)+" | Used temperature is: "+($temperature))  
    Write-Verbose ("ShellGPT @ "+(Get-Date)+" | Used max_tokens is: "+($max_tokens)) 

    $contiueConversation = $(Write-Host ("ShellGPT @ "+(Get-Date)+" | Do you want to restore an existing conversation? (enter 'y' or 'yes'): ") -ForegroundColor yellow -NoNewLine; Read-Host) 

    if ($contiueConversation  -eq "y" -or $contiueConversation -eq "yes")
    {
        Get-ShellGPTHelpMessage
        $importPath = $(Write-Host ("ShellGPT @ "+(Get-Date)+" | Provide the full path to the prompt*.json file you want to continue the conversation on: ") -ForegroundColor yellow -NoNewLine; Read-Host) 
        [System.Collections.ArrayList]$importedPrompt = Import-OpenAIPromptFromJson -Path $importPath
        [System.Collections.ArrayList]$previousMessages = $importedPrompt
    }
    else 
    {
        # Display a welcome message and instructions for stopping the conversation.
        Get-ShellGPTHelpMessage

        # Initialize the previous messages array.
        [System.Collections.ArrayList]$previousMessages = @()

        $option = Read-Host ("ShellGPT @ "+(Get-Date)+" | Select the Character the Model should assume:`n1: Chat`n2: Ticker and Sentiment Analysis`n3: Sentiment Analysis`n4: Intent Analysis`n5: Intent & Topic Analysis`nShellGPT @ "+(Get-Date)+" | Enter the according number of the character you'd like")

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
                $Character = "Chat"
                Write-Host ("ShellGPT @ "+(Get-Date)+" | Invalid option selected.") -ForegroundColor Yellow 
            }
        }
        
        Write-Host ("ShellGPT @ "+(Get-Date)+" | Selected Character is: "+($Character)) -ForegroundColor Yellow 
        $InitialQuery = Read-Host ("ShellGPT @ "+(Get-Date)+" | Your query for ChatGPT or commands for ShellGPT")

        Write-Verbose ("ShellGPT @ "+(Get-Date)+" | InitialQuery is: "+($InitialQuery)) 

        switch -Regex ($InitialQuery) {
            "^file \|.*" {
                Write-Verbose ("ShellGPT @ "+(Get-Date)+" | InitialQuery is File command")

                $filePath = (($InitialQuery.split("|"))[1]).TrimStart(" ")
                $filepath = $filePath.TrimEnd(" ")
                $filePath = $filePath.Replace('"','')
                $FileQuery = (($InitialQuery.split("|"))[2]).TrimStart(" ")

                Write-Verbose ("ShellGPT @ "+(Get-Date)+" | Extracted FilePath from Query is: "+($filePath)) 
                Write-Verbose ("ShellGPT @ "+(Get-Date)+" | Extracted Query is: "+($FileQuery))
                Write-Verbose ("ShellGPT @ "+(Get-Date)+" | Starting Conversation...") 

                if ($UseAzure)
                {
                    [System.Collections.ArrayList]$conversationPrompt = New-OpenAICompletionConversation -Character $Character -query $FileQuery -instructor $instructor -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens -model $model -stop $stop -filePath $filePath -ShowTokenUsage $ShowTokenUsage -ShowOutput $ShowOutput -assistantReply $assistantReply -UseAzure $UseAzure -DeploymentName $DeploymentName
                }
                else {
                    [System.Collections.ArrayList]$conversationPrompt = New-OpenAICompletionConversation -Character $Character -query $FileQuery -instructor $instructor -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens -model $model -stop $stop -filePath $filePath -ShowTokenUsage $ShowTokenUsage -ShowOutput $ShowOutput -assistantReply $assistantReply
                }

                Write-Host ("CompletionAPI @ "+(Get-Date)+" | "+($conversationPrompt[($conversationPrompt.count)-1].content)) -ForegroundColor Green

                if ($InitialQuery.Contains("| out |"))
                    {
                        $filePathOut = (($InitialQuery.split("|"))[4]).TrimStart(" ")
                        $filePathOut = $filePathOut.TrimEnd(" ")
                        Write-Host ("ShellGPT @ "+(Get-Date)+" | Writing output to file: "+($filePathOut)) -ForegroundColor Yellow

                        try {
                            ($conversationPrompt[($conversationPrompt.count)-1].content) | Out-File -Encoding utf8 -FilePath $filePathOut
                            Write-Host ("ShellGPT @ "+(Get-Date)+" | Successfully created file with output at: "+($filePathOut)) -ForegroundColor Green
    
                        }
                        catch {
                            Write-Host ("ShellGPT @ "+(Get-Date)+" | Could not write output to file: "+($filePathOut)) -ForegroundColor Red
                        }
                    }
            }
            "^quit \|.*" {
                Write-Host ("ShellGPT @ "+(Get-Date)+" | ShellGPT is exiting now...") -ForegroundColor Yellow
                Start-Sleep 5
                exit
            }
            "^export \|.*" {
                Write-Host ("ShellGPT @ "+(Get-Date)+" | ShellGPT has nothing to export :(") -ForegroundColor Yellow
            }
            "^\s*$" {
                Write-Host ("ShellGPT @ "+(Get-Date)+" | You have not provided any input. Will not send this query to the CompletionAPI") -ForegroundColor Yellow
                [System.Collections.ArrayList]$conversationPrompt = Set-OpenAICompletionCharacter $Character
            }
            default {

                if ($InitialQuery.contains("| out |"))
                {
                    $filePathOut = (($InitialQuery.split("|"))[2]).TrimStart(" ")
                    $filePathOut = $filePathOut.TrimEnd(" ")
                    $InitialQuery = (($InitialQuery.split("|"))[0]).TrimStart(" ")
                    $InitialQuery = $InitialQuery.TrimEnd(" ")

                    if ($UseAzure)
                    {
                        [System.Collections.ArrayList]$conversationPrompt = New-OpenAICompletionConversation -Character $Character -query $InitialQuery -instructor $instructor -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens -model $model -stop $stop -ShowTokenUsage $ShowTokenUsage -ShowOutput $ShowOutput -assistantReply $assistantReply -UseAzure $UseAzure -DeploymentName $DeploymentName
                    }
                    else 
                    {
                        [System.Collections.ArrayList]$conversationPrompt = New-OpenAICompletionConversation -Character $Character -query $InitialQuery -instructor $instructor -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens -model $model -stop $stop -ShowTokenUsage $ShowTokenUsage -ShowOutput $ShowOutput -assistantReply $assistantReply
                    }

                    Write-Host ("ShellGPT @ "+(Get-Date)+" | Writing output to file: "+($filePathOut)) -ForegroundColor Yellow
    
                    try {
                        ($conversationPrompt[($conversationPrompt.count)-1].content) | Out-File -Encoding utf8 -FilePath $filePathOut
                        Write-Host ("ShellGPT @ "+(Get-Date)+" | Successfully created file with output at: "+($filePathOut)) -ForegroundColor Green
    
                    }
                    catch {
                        Write-Host ("ShellGPT @ "+(Get-Date)+" | Could not write output to file: "+($filePathOut)) -ForegroundColor Red
                    }
                }
                else
                {
                    if ($UseAzure)
                    {
                        [System.Collections.ArrayList]$conversationPrompt = New-OpenAICompletionConversation -Character $Character -query $InitialQuery -instructor $instructor -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens -model $model -stop $stop -ShowTokenUsage $ShowTokenUsage -ShowOutput $ShowOutput -assistantReply $assistantReply -UseAzure $UseAzure -DeploymentName $DeploymentName
                    }
                    else {
                        [System.Collections.ArrayList]$conversationPrompt = New-OpenAICompletionConversation -Character $Character -query $InitialQuery -instructor $instructor -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens -model $model -stop $stop -ShowTokenUsage $ShowTokenUsage -ShowOutput $ShowOutput -assistantReply $assistantReply
                    }
                }    
                Write-Host ("CompletionAPI @ "+(Get-Date)+" | "+($conversationPrompt[($conversationPrompt.count)-1].content)) -ForegroundColor Green
            }
        }

        [System.Collections.ArrayList]$previousMessages = $conversationPrompt
    }

    # Initialize the continue variable.
    $continue = $true

    # Loop until the user stops the conversation.
    while ($continue) {

        # Prompt the user to enter their query for ChatGPT or commands for ShellGPT.
        $userQuery = Read-Host ("ShellGPT @ "+(Get-Date)+" | Your query for ChatGPT or commands for ShellGPT")

        switch -Regex ($userQuery) {
            "^file \|.*" {
                Write-Verbose ("ShellGPT @ "+(Get-Date)+" | InitialQuery is File command")

                $filePath = (($userQuery.split("|"))[1]).TrimStart(" ")
                $filepath = $filePath.TrimEnd(" ")
                $filePath = $filePath.Replace('"','')

                $FileQuery = (($userQuery.split("|"))[2]).TrimStart(" ")

                Write-Verbose ("ShellGPT @ "+(Get-Date)+" | Extracted FilePath from Query is: "+($filePath)) 
                Write-Verbose ("ShellGPT @ "+(Get-Date)+" | Extracted Query is: "+($FileQuery))


                if ($UseAzure)
                {
                    [System.Collections.ArrayList]$conversationPrompt = New-OpenAICompletionConversation -Character $Character -query $FileQuery -instructor $instructor -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens -model $model -stop $stop -filePath $filePath -ShowTokenUsage $ShowTokenUsage -ShowOutput $ShowOutput -UseAzure $UseAzure -DeploymentName $DeploymentName
                }
                else {
                    [System.Collections.ArrayList]$conversationPrompt = New-OpenAICompletionConversation -Character $Character -query $FileQuery -instructor $instructor -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens -model $model -stop $stop -filePath $filePath -ShowTokenUsage $ShowTokenUsage -ShowOutput $ShowOutput
                }
                Write-Host ("CompletionAPI @ "+(Get-Date)+" | "+($conversationPrompt[($conversationPrompt.count)-1].content)) -ForegroundColor Green

                if ($userQuery.Contains("| out |"))
                {

                    $filePathOut = (($UserQuery.split("|"))[4]).TrimStart(" ")
                    $filePathOut = $filePathOut.TrimEnd(" ")
                    Write-Host ("ShellGPT @ "+(Get-Date)+" | Writing output to file: "+($filePathOut)) -ForegroundColor Yellow

                    try {
                        ($conversationPrompt[($conversationPrompt.count)-1].content) | Out-File -Encoding utf8 -FilePath $filePathOut
                        Write-Host ("ShellGPT @ "+(Get-Date)+" | Successfully created file with output at: "+($filePathOut)) -ForegroundColor Green

                    }
                    catch {
                        Write-Host ("ShellGPT @ "+(Get-Date)+" | Could not write output to file: "+($filePathOut)) -ForegroundColor Red
                    }
                    
                }

            }
            "^newconvo \|.*" {
                Start-ShellGPT -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens -model $model -stop $stop
            }
            "^quit \|.*" {
                $exportBool = $(Write-Host ("ShellGPT @ "+(Get-Date)+" | Do you want to export the current prompt before exiting? Enter 'y' or 'yes': ") -ForegroundColor yellow -NoNewLine; Read-Host) 
                if ($exportBool -eq "y" -or $exportBool -eq "yes" -or $exportBool -eq "Y" -or $exportBool -eq "YES")
                {
                    $exportPath = $(Write-Host ("ShellGPT @ "+(Get-Date)+" | Provide the full path to the prompt*.json file that you want to export now and later continue the conversation on: ") -ForegroundColor yellow -NoNewLine; Read-Host)
                    Export-OpenAIPromptToJson -Path $exportPath -prompt $previousMessages 
                    Write-Host ("ShellGPT @ "+(Get-Date)+" | ShellGPT exported the prompt to: "+($exportPath)) -ForegroundColor yellow
                }
                Write-Host ("ShellGPT @ "+(Get-Date)+" | ShellGPT is exiting now...") -ForegroundColor yellow
                Start-Sleep 5
                exit
            }
            "^export \|.*" {

                $exportPath = $(Write-Host ("ShellGPT @ "+(Get-Date)+" | Provide the full path to the prompt*.json file that you want to export now and later continue the conversation on: ") -ForegroundColor yellow -NoNewLine; Read-Host) 

                Export-OpenAIPromptToJson -Path $exportPath -prompt $previousMessages
                Write-Host ("ShellGPT @ "+(Get-Date)+" | ShellGPT exported the prompt to: "+($exportPath)) -ForegroundColor yellow
            }
            "^\s*$" {
                Write-Host ("ShellGPT @ "+(Get-Date)+" | You have not provided any input. Will not send this query to the CompletionAPI") -ForegroundColor Yellow
                [System.Collections.ArrayList]$conversationPrompt = Set-OpenAICompletionCharacter $Character
            }
            default {            
                if ($userQuery.contains("| out |"))
                {
                    $filePathOut = (($InitialQuery.split("|"))[2]).TrimStart(" ")
                    $filePathOut = $filePathOut.TrimEnd(" ")
                    $UserQuery = (($UserQuery.split("|"))[0]).TrimStart(" ")
                    $UserQuery = $UserQuery.TrimEnd(" ")

                    if ($UseAzure){
                        [System.Collections.ArrayList]$conversationPrompt = Add-OpenAICompletionMessageToConversation -query $userQuery -previousMessages $previousMessages -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens -model $model -stop $stop -ShowTokenUsage $ShowTokenUsage -ShowOutput $ShowOutput -UseAzure $UseAzure -DeploymentName $DeploymentName
                    }
                    else {
                        [System.Collections.ArrayList]$conversationPrompt = Add-OpenAICompletionMessageToConversation -query $userQuery -previousMessages $previousMessages -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens -model $model -stop $stop -ShowTokenUsage $ShowTokenUsage -ShowOutput $ShowOutput
                    }

                    Write-Host ("ShellGPT @ "+(Get-Date)+" | Writing output to file: "+($filePathOut)) -ForegroundColor Yellow
    
                    try {
                        ($conversationPrompt[($conversationPrompt.count)-1].content) | Out-File -Encoding utf8 -FilePath $filePathOut
                        Write-Host ("ShellGPT @ "+(Get-Date)+" | Successfully created file with output at: "+($filePathOut)) -ForegroundColor Green
    
                    }
                    catch {
                        Write-Host ("ShellGPT @ "+(Get-Date)+" | Could not write output to file: "+($filePathOut)) -ForegroundColor Red
                    }

                }
                else
                {
                    if ($useAzure) {
                        [System.Collections.ArrayList]$conversationPrompt = Add-OpenAICompletionMessageToConversation -query $userQuery -previousMessages $previousMessages -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens -model $model -stop $stop -ShowTokenUsage $ShowTokenUsage -ShowOutput $ShowOutput -UseAzure $UseAzure -DeploymentName $DeploymentName
                    }
                    else {
                        [System.Collections.ArrayList]$conversationPrompt = Add-OpenAICompletionMessageToConversation -query $userQuery -previousMessages $previousMessages -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens -model $model -stop $stop -ShowTokenUsage $ShowTokenUsage -ShowOutput $ShowOutput
                    }
                }

                Write-Host ("CompletionAPI @ "+(Get-Date)+" | "+($conversationPrompt[($conversationPrompt.count)-1].content)) -ForegroundColor Green
            }
        }

        [System.Collections.ArrayList]$previousMessages = $conversationPrompt
    }
}
