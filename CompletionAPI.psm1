function Invoke-CompletionAPI {
    <#
        .SYNOPSIS
        Sends a prompt (System.Object) to the OpenAI Completion API (api.openai.com/v1/chat/completions) using "gpt-3.5-turbo" model, gets a response, and appends it to the prompt.

        .DESCRIPTION
        Sends a prompt (System.Object) to the OpenAI Completion API (api.openai.com/v1/chat/completions), gets a response, and appends it to the prompt.
        Preferably generate a prompt (System.Object) with "New-CompletionAPIPrompt" and use that as the input for the parameter "-prompt"
        
        .PARAMETER prompt
        The prompt (System.Object) to send to the API to act upon. Preferably generate a prompt (System.Object) with "New-CompletionAPIPrompt" and use that as the input for the parameter "-prompt"

        .PARAMETER APIKey
        The API key for the OpenAI API to authenticate the request. This parameter is mandatory and accepts a string data type. This parameter is mandatory.

        .PARAMETER temperature
        The temperature value to use for sampling. This parameter is mandatory and accepts a double data type. This parameter is mandatory.

        .PARAMETER max_tokens
        The maximum number of tokens to generate in the response. This parameter is mandatory and accepts an integer data type. This parameter is mandatory.

        .INPUTS
        None. You cannot pipe objects to Invoke-CompletionAPI.

        .OUTPUTS
        System.Object. Invoke-CompletionAPI returns the prompt, enriched with the repsonse from the API.

        .EXAMPLE
        PS> $APIKey = "YOUR_API_KEY"
        PS> $temperature = 0.6
        PS> $max_tokens = 3500
        PS> $prompt = New-CompletionAPIPrompt -query "What is the Capitol of Switzerland?" -role "user" -instructor "You are a helpful AI." -assistantReply "How can I help you today?"
        PS> $response = Invoke-CompletionAPI -prompt $prompt -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens
        ChatGPT: The capital of Switzerland is Bern.
        PS> $response
        Name                           Value
        ----                           -----
        content                        You are a helpful AI.
        role                           system
        content                        How can I help you today?
        role                           assistant
        content                        What is the Capitol of Bern?
        role                           user
        content                        The capital of Bern is Bern itself.
        role                           assistant

        .LINK
        GitHub Repo: https://github.com/yamautomate/PowerShell-OpenAI-API-Wrapper
    #>

    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.Object]$prompt,  # The prompt to send to the API to act upon.
        [Parameter(Mandatory=$true)]
        [string]$APIKey,        # The API key to authenticate the request.
        [Parameter(Mandatory=$true)]
        [double]$temperature,   # The temperature value to use for sampling.
        [Parameter(Mandatory=$true)]
        [int]$max_tokens       # The maximum number of tokens to generate in the response.
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

function New-CompletionAPIPrompt {
    <#
        .SYNOPSIS
        Creates a prompt (System.Object) for the function "Invoke-CompletionAPI" to be consumed. 

        .DESCRIPTION
        Creates a prompt (System.Object) for the function "Invoke-CompletionAPI" to be consumed. 
        The "New-CompletionAPIPrompt" function is used by the "Invoke-CompletionAPI" function to create a prompt that includes the user's query, the role in the conversation, an instruction string, and if provided, previous messages in the conversation.
        
        .PARAMETER query
        The query to be used for the input in the prompt. This parameter is mandatory and expects a string.

        .PARAMETER  role
        The role to add to the prompt for the specified query. The role can be one of three values: "system", "assistant", or "user". This parameter is mandatory.

        .PARAMETER  instructor
        The instruction (system) message to add to the prompt. This tells the model what it is ("A Helpful AI", "A Pirate, that answers every request with Arrrr!") This parameter is optional and expects a string.

        .PARAMETER assistantReply
        The first, unseen reply by the model. This parameter can be used to help train the model and get expected output. This parameter is optional.

        .PARAMETER previousMessages
        An array of previous messages (System.Object) in the conversation (which was generated by "New-CompletionAPI" or "Set-CompletionAPICharacter"). This parameter is optional.

        .INPUTS
        None. You cannot pipe objects to Invoke-CompletionAPI.

        .OUTPUTS
        System.Object. New-CompletionAPIPrompt returns the prompt (a list of messages going back and forth between different parties), ready to be consumed by other functions.

        .EXAMPLE
        PS> New-CompletionAPIPrompt -query "What is the Capitol of Switzerland?" -role "user" -instructor "You are a helpful AI." -assistantReply "How can I help you today?"
        Name                           Value
        ----                           -----
        content                        You are a helpful AI.
        role                           system
        content                        How can I help you today?
        role                           assistant
        content                        What is the Capitol of Switzerland?
        role                           user

        .LINK
        GitHub Repo: https://github.com/yamautomate/PowerShell-OpenAI-API-Wrapper
    #>

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
    <#
        .SYNOPSIS
        This function generates a "Character" (a prompt that represents a character) to use. These five characters are hardcoded into that function. 

        .DESCRIPTION
        Creates a prompt (System.Object) for the function "Invoke-CompletionAPI" or by "New-CompletionAPIConversation" to create a Conversation based on a character. 
        
        These five characters are hardcoded into this function:
            - Chat: Instructed to be a helpful AI assistant
            - SentimentAnalysis: Analyzes the sentiment of a text and responds in a defined .JSON format
            - SentimentAndTickerAnalysis: Analyzes the sentiment of a text and extracts the ticker of an asset that mentioned within and responds in a defined .JSON format
            - IntentAnalysis: Analyzes the intent of a text and responds in a defined .JSON format
            - IntentAndSubjectAnalysis Analyzes the intent and subject of a text and responds in a defined .JSON format
        
        .PARAMETER mode
        The Character/Mode that is used to generate the prompt. This parameter is mandatory and expects a string

        .INPUTS
        None. You cannot pipe objects to Set-CompletionAPICharacter.

        .OUTPUTS
        System.Object. Set-CompletionAPICharacter returns the prompt (a list of messages going back and forth between different parties), ready to be consumed by other functions.

        .EXAMPLE
        PS> $character = Set-CompletionAPICharacter -mode SentimentAnalysis
        PS> $character
        Name                           Value
        ----                           -----
        content                        You are an API that analyzes text sentiment. You provide your answer in a .JSON format in the following structure: { "sentiment": 0.9 } You only answer with the .JSON object. You do not provide any reasoning why you did it that way.  The sentiment is a value between 0 - 1. Where 1 is th... 
        role                           system
        content                        {sentiment}
        role                           assistant

        .LINK
        GitHub Repo: https://github.com/yamautomate/PowerShell-OpenAI-API-Wrapper
    #>

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

function New-CompletionAPIConversation {
    <#
        .SYNOPSIS
        This is a wrapper function that creates the prompt and calls the Open AI API using "New-CompletionAPIPrompt" and "Invoke-CompletionAPI".

        .DESCRIPTION
        This is a wrapper function that creates the prompt and calls the Open AI API using "New-CompletionAPIPrompt" and "Invoke-CompletionAPI".
        If Character is null, it creates a prompt with the user's query, instruction string, and assistant reply (if provided) and calls Invoke-CompletionAPI to generate a response. 
        If Character is not null, it creates a prompt with the user's query and the character's previous messages and calls Invoke-CompletionAPI to generate a response.
        
        .PARAMETER character
        A string that determines the type of conversation to have. 
        Valid options are 
        - "Chat"
        - "SentimentAndTickerAnalysis"
        - "SentimentAnalysis"
        - "IntentAnalysis"
        - "IntentAndSubjectAnalysis". 
        
        If specified, do not add instructor and assistantReply. This parameter is optional.

        .PARAMETER query
        The query to be used for the input in the prompt. This parameter is mandatory and expects a string.

        .PARAMETER  instructor
        The instruction (system) message to add to the prompt. This tells the model what it is ("A Helpful AI", "A Pirate, that answers every request with Arrrr!") This parameter is optional and expects a string.

        .PARAMETER assistantReply
        The first, unseen reply by the model. This parameter can be used to help train the model and get expected output. This parameter is optional amd expects a string.

        .PARAMETER APIKey
        The API key for the OpenAI API to authenticate the request. This parameter is mandatory and accepts a string data type. This parameter is mandatory.

        .PARAMETER temperature
        The temperature value to use for sampling. This parameter is mandatory and accepts a double data type. This parameter is mandatory.

        .PARAMETER max_tokens
        The maximum number of tokens to generate in the response. This parameter is mandatory and accepts an integer data type. This parameter is mandatory.

        .INPUTS
        None. You cannot pipe objects to Invoke-CompletionAPI.

        .OUTPUTS
        System.Object. New-CompletionAPIConversation returns the prompt (a list of messages going back and forth between different parties), ready to be consumed by other functions.

        .EXAMPLE
        PS> $APIKey = "YOUR_API_KEY"
        PS> $temperature = 0.6
        PS> $max_tokens = 3500
        PS> $conversation = New-CompletionAPIConversation -Character SentimentAnalysis -query "Twitter is amazing" -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens
        ChatGPT: { "sentiment": 0.875 }
        PS> $conversation
        Name                           Value
        ----                           -----
        content                        You are an API that analyzes text sentiment. You provide your answer in a .JSON format in the following structure: { "sentiment": 0.9 } You only answer with the .JSON object. You do not provide any reasoning why you did it that way.  The sentiment is a value between 0 - 1. Where 1 is th... 
        role                           system
        content                        {sentiment}
        role                           assistant
        content                        Twitter is amazing
        role                           user
        content                        { "sentiment": 0.875 }
        role                           assistant

        .LINK
        GitHub Repo: https://github.com/yamautomate/PowerShell-OpenAI-API-Wrapper
    #>

    param (
        [Parameter(Mandatory=$false)]      
        [ValidateSet("Chat", "SentimentAndTickerAnalysis","SentimentAnalysis","IntentAnalysis","IntentAndSubjectAnalysis")]
        [System.Object]$Character,     # The character to use. If specified, do not add instructor and assistantReply
        [Parameter(Mandatory=$true)]  
        [string]$query,                # The user's query to add to the prompt.
        [Parameter(Mandatory=$false)]  
        [string]$instructor,           # The instruction string to add to the prompt. Only use when you dont use a Character.
        [Parameter(Mandatory=$false)]  
        [string]$assistantReply,       # The first, unseen reply by the model. Can be used to help train it and get expected output. Only use when you dont use a Character.
        [Parameter(Mandatory=$true)]  
        [string]$APIKey,               # API key for ChatGPT.
        [Parameter(Mandatory=$true)]  
        [double]$temperature,          # The temperature value to use for sampling.
        [Parameter(Mandatory=$true)]  
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

function Add-CompletionAPIMessageToConversation {
    <#
        .SYNOPSIS
        This is a wrapper function that creates the prompt and calls the Open AI API using "New-CompletionAPIPrompt" and "Invoke-CompletionAPI".

        .DESCRIPTION
        The function is used by Start-ChatGPTforPowerShell. 
        It creates a new prompt using "New-CompletionAPIPrompt" with the given query and previous messages, and passes it to the "Invoke-CompletionAPI" function to get a response from the API. 
        The function then returns the response from the API and the updated previous messages.

        .PARAMETER query
        The query to be used for the input in the prompt. This parameter is mandatory and expects a string.

        .PARAMETER previousMessages
        An array of previous messages (System.Object) in the conversation (which was generated by "New-CompletionAPI" or "Set-CompletionAPICharacter"). This parameter is optional.

        .PARAMETER  instructor
        The instruction (system) message to add to the prompt. This tells the model what it is ("A Helpful AI", "A Pirate, that answers every request with Arrrr!") This parameter is optional and expects a string.

        .PARAMETER APIKey
        The API key for the OpenAI API to authenticate the request. This parameter is mandatory and accepts a string data type. This parameter is mandatory.

        .PARAMETER temperature
        The temperature value to use for sampling. This parameter is mandatory and accepts a double data type. This parameter is mandatory.

        .PARAMETER max_tokens
        The maximum number of tokens to generate in the response. This parameter is mandatory and accepts an integer data type. This parameter is mandatory.

        .INPUTS
        None. You cannot pipe objects to Add-CompletionAPIMessageToConversation.

        .OUTPUTS
        System.Object. Add-CompletionAPIMessageToConversation returns the prompt (a list of messages going back and forth between different parties), ready to be consumed by other functions.

        .EXAMPLE
        PS> $APIKey = "YOUR_API_KEY"
        PS> $temperature = 0.6
        PS> $max_tokens = 3500
        PS> $previousMessages = New-CompletionAPIConversation -Character SentimentAnalysis -query "Twitter is amazing" -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens
        PS> $conversation = Add-CompletionAPIMessageToConversation -query "I dont like Twitter" -previousMessages $conversation -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens 
        ChatGPT: { "sentiment": 0.875 }
        PS> $conversation
        Name                           Value
        ----                           -----
        content                        You are an API that analyzes text sentiment. You provide your answer in a .JSON format in the following structure: { "sentiment": 0.9 } You only answer with the .JSON object. You do not provide any reasoning why you did it that way.  The sentiment is a value between 0 - 1. Where 1 is th... 
        role                           system
        content                        {sentiment}
        role                           assistant
        content                        Twitter is amazing
        role                           user
        content                        { "sentiment": 0.875 }
        role                           assistant
        content                        I dont like Twitter
        role                           user
        content                        { "sentiment": 0.0 }
        role                           assistant

        .LINK
        GitHub Repo: https://github.com/yamautomate/PowerShell-OpenAI-API-Wrapper
    #>

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
        [int]$max_tokens         # The maximum number of tokens to generate in the response.
    )

    $prompt = New-CompletionAPIPrompt -query $query -role "user" -previousMessages $previousMessages

    # Call the Invoke-ChatGPT function to get the response from the API.
    $returnPromptFromAPI = Invoke-CompletionAPI -prompt $prompt -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens 
    
    # Return the response from the API and the updated previous messages.
    return $returnPromptFromAPI
    
}
function Import-PromptFromJson {
    <#
        .SYNOPSIS
        This function takes in a file path to a JSON file that contains a prompt for a ChatGPT conversation and converts the JSON data into a PowerShell object.

        .DESCRIPTION
        This function takes in a file path to a JSON file that contains a prompt for a ChatGPT conversation and converts the JSON data into a PowerShell object.

        .PARAMETER Path
        Required. The file path to the JSON file containing the prompt. This parameter is mandatory.

        .INPUTS
        None. You cannot pipe objects to Import-PromptFromJson.

        .OUTPUTS
        System.Object. Import-PromptFromJson returns the prompt (a list of messages going back and forth between different parties), ready to be consumed by other functions.

        .EXAMPLE
        PS> prompt = Import-PromptFromJson -Path bern.json
        PS> $prompt
        content
        -------
        You are a helpful AI. You answer as concisely as possible.
        Hello! I'm a ChatGPT-3.5 Model. How can I help you?
        Hello there! What is the capitol of Switzerland?
        The capital of Switzerland is Bern.
        How many inhabitants does it have?
        As of 2021, the estimated population of Bern is around 133,000 inhabitants.
        Who governs it?
        The government of Bern is composed of a city council, which is made up of five members, and a mayor, who serves as the head of the council. The council is responsible for the administration of the city, including public services, infrastructure, and social programs. The city council members are elected by the people ... 

        .LINK
        GitHub Repo: https://github.com/yamautomate/PowerShell-OpenAI-API-Wrapper
    #>

    param (
        [Parameter(Mandatory=$true)]    
        [string]$Path                   #Required. The file path to the JSON file containing the prompt. This parameter is mandatory.
    )

    $promptJson = Get-Content -Path $Path -Raw
    $prompt = $promptJson | ConvertFrom-Json

    return $prompt
}

function Export-PromptToJson {
    <#
        .SYNOPSIS
        This function takes in a file path to a JSON file that contains a prompt for a ChatGPT conversation and converts the JSON data into a PowerShell object.

        .DESCRIPTION
        This function takes in a file path to a JSON file that contains a prompt for a ChatGPT conversation and converts the JSON data into a PowerShell object.

        .PARAMETER Path
        Required. The file path to the JSON file containing the prompt. This parameter is mandatory.

        .PARAMETER prompt
        Required. The prompt (System.Object) to export to a .JSON file.

        .INPUTS
        None. You cannot pipe objects to Export-PromptToJson

        .OUTPUTS
        System.Object. Import-PromptFromJson returns the prompt (a list of messages going back and forth between different parties), ready to be consumed by other functions.

        .EXAMPLE
        PS> Export-PromptToJson -Path bern.json -prompt $prompt 

        .LINK
        GitHub Repo: https://github.com/yamautomate/PowerShell-OpenAI-API-Wrapper
    #>

    param (
        [Parameter(Mandatory=$true)]    
        [string]$Path,                 #The file path to the JSON file containing the prompt. This parameter is mandatory.
        [Parameter(Mandatory=$true)]    
        [System.Object]$prompt         #The prompt (System.Object) to export to a .JSON file.
    )

    $prompt | ConvertTo-Json | Out-File -Encoding utf8 -FilePath $path

    return $prompt
}

function Start-ChatGPTforPowerShell {
    <#
        .SYNOPSIS
        This PowerShell function starts a conversation with the ChatGPT API, allowing users to interact with the model.

        .DESCRIPTION
        The function prompts the user to either start a new conversation or restore an existing one. 
        If the user chooses to restore an existing conversation, they must provide the full path to the prompt*.json file.
        If the user chooses to start a new conversation, the function prompts the user to select the character that the model should assume.
        The available options are:

            - Chat: Instructed to be a helpful AI assistant
            - SentimentAnalysis: Analyzes the sentiment of a text and responds in a defined .JSON format
            - SentimentAndTickerAnalysis: Analyzes the sentiment of a text and extracts the ticker of an asset that mentioned within and responds in a defined .JSON format
            - IntentAnalysis: Analyzes the intent of a text and responds in a defined .JSON format
            - IntentAndSubjectAnalysis Analyzes the intent and subject of a text and responds in a defined .JSON format

        The user must then enter their query for ChatGPT. The function adds the query to the conversation and retrieves the response from ChatGPT. 
        The conversation continues until the user enters 'q' or 'quit'. 
        At that point, the function prompts the user to export the current prompt for future use and/or start a new conversation. 
        If the user chooses to export the prompt, they must provide the full path to the prompt*.json file.
        If the user chooses to start a new conversation, the function calls itself recursively. If the user chooses to exit the conversation, the function ends.

        .PARAMETER APIKey
        The API key for the OpenAI API to authenticate the request. This parameter is mandatory and accepts a string data type. This parameter is mandatory.

        .PARAMETER temperature
        The temperature value to use for sampling. This parameter is mandatory and accepts a double data type. This parameter is mandatory.

        .PARAMETER max_tokens
        The maximum number of tokens to generate in the response. This parameter is mandatory and accepts an integer data type. This parameter is mandatory.

        .INPUTS
        None. You cannot pipe objects to Add-CompletionAPIMessageToConversation.

        .OUTPUTS
        Does not have any return values. Print the conversation on the console. 

        .EXAMPLE
        PS> $APIKey = "YOUR_API_KEY"
        PS> $temperature = 0.6
        PS> $max_tokens = 3500
        PS> Start-ChatGPTforPowerShell -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens
        Do you want to restore an existing conversation? (enter 'y' or 'yes'): n

        Starting a new one...

        To stop the current conversation enter 'q' or 'quit' in the query

        Select the Character the Model should assume:
        1: Chat
        2: Ticker and Sentiment Analysis
        3: Sentiment Analysis
        4: Intent Analysis
        5: Intent & Topic Analysis: 1

        Your query for ChatGPT: Hello there! What is the capitol of Switzerland?
        ChatGPT: The capital of Switzerland is Bern.

        Your query for ChatGPT: How many inhabitants does it have?
        ChatGPT: As of 2021, the estimated population of Bern is around 133,000 inhabitants.

        Your query for ChatGPT: Who governs it?
        ChatGPT: The government of Bern is composed of a city council, which is made up of five members, and a mayor, who serves as the head of the council. The council is responsible for the administration of the city, including public services, infrastructure, and social programs. The city council members are elected by the people of Bern for a term of four years.

        Your query for ChatGPT: q
        Do you want to export the current prompt for future use? (enter 'y' or 'yes'): y

        Initializing export..
        Provide the full path to the prompt*.json file that you want to export now and later continue the conversation on: bern.json
        Do you want to start a new conversation (enter 'y' or 'yes'): n

        .LINK
        GitHub Repo: https://github.com/yamautomate/PowerShell-OpenAI-API-Wrapper
    #>

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

        $conversationPrompt = New-CompletionAPIConversation -Character $Character -query (Read-Host "Your query for ChatGPT") -instructor $instructor -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens

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
               Export-PromptToJson -Path $exportPath -prompt $previousMessages

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
            $conversationPrompt = Add-CompletionAPIMessageToConversation -query $userQuery -previousMessages $previousMessages -instructor $instructor -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens
            $previousMessages = $conversationPrompt
        }
    }
}


$apikey = "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"
