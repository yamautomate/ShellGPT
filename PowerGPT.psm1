function Invoke-OpenAICompletion {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.Object]$prompt,                 # The prompt to send to the API to act upon
        [Parameter(Mandatory=$true)]
        [string]$APIKey,                        # The API key to authenticate the request.
        [Parameter(Mandatory=$false)]
        [string]$model = "gpt-3.5-turbo",       # The model to use from the endpoint.
        [Parameter(Mandatory=$false)]
        [string]$stop = "\n",                   # The stop instructor for the model. 
        [Parameter(Mandatory=$false)]
        [double]$temperature = 0.4,             # The temperature value to use for sampling.
        [Parameter(Mandatory=$false)]
        [int]$max_tokens = 900,                 # The maximum number of tokens to generate in the response.
        [Parameter(Mandatory=$false)]
        [bool]$ShowOutput = $false,                    # The maximum number of tokens to generate in the response.
        [Parameter(Mandatory=$false)]
        [bool]$ShowTokenUsage = $false                 # The maximum number of tokens to generate in the response.
    )

    Write-Verbose ("PowerGPT-Invoke-OpenAICompletion @ "+(Get-Date)+" | Building request for sending off towards CompletionAPI...") 

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

    Write-Verbose ("PowerGPT-Invoke-OpenAICompletion @ "+(Get-Date)+" | Built request. This is the RequestBody: "+($RequestBody)) 

    try {
        #Call the OpenAI completions API
        Write-Verbose ("PowerGPT-Invoke-OpenAICompletion @ "+(Get-Date)+" | Sending off API Call using 'Invoke-RestMethod' to this URI: "+($uri)) 
        $APIresponse = Invoke-RestMethod @RestMethodParameter

        Write-Verbose ("PowerGPT-Invoke-OpenAICompletion @ "+(Get-Date)+" | Received response from API: "+($APIresponse | Out-String)) 

        #Extract Textresponse from API response
        $convertedResponseForOutput = $APIresponse.choices.message.content
        $tokenUsage = $APIresponse.usage

        Write-Verbose ("PowerGPT-Invoke-OpenAICompletion @ "+(Get-Date)+" | Extracted Output: "+($convertedResponseForOutput)) 

        Write-Verbose ("PowerGPT-Invoke-OpenAICompletion @ "+(Get-Date)+" | TokenUsage for this prompt: "+($TokenUsage.prompt_tokens)+" for completion: "+($TokenUsage.completion_tokens)+" Total tokens used: "+($TokenUsage.total_tokens)) 

        If ($ShowTokenUsage -eq $true)
        {
            Write-Host ("PowerGPT-Invoke-OpenAICompletion @ "+(Get-Date)+" | TokenUsage for this prompt: "+($TokenUsage.prompt_tokens)+" for completion: "+($TokenUsage.completion_tokens)+" Total tokens used: "+($TokenUsage.total_tokens)) -ForegroundColor Yellow
        }
       
        #Append text output to prompt for returning it
        Write-Verbose ("PowerGPT-Invoke-OpenAICompletion @ "+(Get-Date)+" | Creating new prompt with API response...") 
        $prompt = New-OpenAICompletionPrompt -query $convertedResponseForOutput -role "assistant" -previousMessages $prompt

        Write-Verbose ("PowerGPT-Invoke-OpenAICompletion @ "+(Get-Date)+" | New Prompt is: "+($prompt | Out-String)) 

        $promptToReturn = $prompt
    }
    catch {
        Write-Verbose ("PowerGPT-Invoke-OpenAICompletion @ "+(Get-Date)+" | Error: "+($_.Exception.Message)) 
        $errorToReport = $_.Exception.Message
        $errorDetails = $_.ErrorDetails.Message
        $convertedResponseForOutput = "Unable to handle Error: "+$errorToReport+" See Error details below. Retry query. If the error persists, consider exporting your current prompt and to continue later."

        #return prompt used as input, as we could not add the answer from the API.
        Write-Verbose ("PowerGPT-Invoke-OpenAICompletion @ "+(Get-Date)+" | Returning Input prompt due to error: "+($prompt)) 
        $promptToReturn = $prompt
    }

    if ($errorDetails)
        {
            Write-Verbose ("PowerGPT-Invoke-OpenAICompletion @ "+(Get-Date)+" | Error Details are present: "+($errorDetails)) 
            write-Host "ErrorDetails:"$errorDetails -ForegroundColor "Red"
        }
    else {
        if ($ShowOutput)
        {
            Write-Host ("PowerGPT @ "+(Get-Date)+" | "+($convertedResponseForOutput)) -ForegroundColor Green
        }
    }

    #return the new full prompt with the added text response from the API
    return $promptToReturn
}

function New-OpenAICompletionPrompt {
    param (   
        [Parameter(Mandatory=$true)]        
        [string]$query,                                                                              # The user's query to add to the prompt.
        [Parameter(Mandatory=$false)]    
        [ValidateSet("system", "assistant", "user")] 
        [string]$role = "user",                                                                               # The role to add to the prompt. 
        [Parameter(Mandatory=$false)]    
        [string]$instructor = "You are ChatGPT, a helpful AI Assistant.",                            # The instruction string to add to the prompt.
        [Parameter(Mandatory=$false)]    
        [string]$assistantReply = "Hello! I'm ChatGPT, a GPT Model. How can I assist you today?",    # The first, unseen reply by the model. Can be used to help train it and get expected output.
        [Parameter(Mandatory=$false)]    
        [System.Object]$previousMessages,                                                             # An array of previous messages in the conversation.
        [Parameter(Mandatory=$false)]    
        [string]$filePath                                                                                # An array of previous messages in the conversation.
        )

    if ($filePath)
    {
        Write-Verbose ("PowerGPT-New-OpenAICompletionPrompt @ "+(Get-Date)+" | File path was provided: "+($filepath)) 


        if ($filePath.EndsWith(".pdf"))
        {
            Write-Verbose ("PowerGPT @ "+(Get-Date)+" | File is PDF. Trying to read content and generate .txt...") 
            Write-Verbose ("PowerGPT @ "+(Get-Date)+" | File is PDF. Reworking filepath to only have forward slashes...") 
            $filePath = $filePath.Replace("\","/")

            try {            
                $filePath = Convert-PDFtoText -filePath $filePath -TypeToExport txt
                Write-Verbose ("PowerGPT @ "+(Get-Date)+" | PDF Content was read, and .txt created at this path: "+($filepath)) 

            }
            catch {
                Write-Verbose ("PowerGPT @ "+(Get-Date)+" | We ran into trouble reading the PDF content and writing it to a .txt file "+($filepath)) 
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

        try {
            Write-Verbose ("PowerGPT-New-OpenAICompletionPrompt @ "+(Get-Date)+" | Trying to read content of file using UTF-8 encoding...") 
            $filecontent = Get-Content -Path $filePath -Raw -Encoding utf8
            Write-Verbose ("PowerGPT-New-OpenAICompletionPrompt @ "+(Get-Date)+" | File content extracted...") 

            #Remove characters the API can not interpret:
            #$filecontent = $filecontent -replace '\n',''
            $filecontent = $filecontent -replace '(?m)^\s+',''
            $filecontent = $filecontent -replace '\r',''
            $filecontent = $filecontent -replace '●',''
            $filecontent = $filecontent -replace '“',"'"
            $filecontent = $filecontent -replace '”',"'"
            $filecontent = $filecontent -replace 'ä',"ae"
            $filecontent = $filecontent -replace 'ö',"oe"
            $filecontent = $filecontent -replace 'ü',"ue"
            $filecontent = $filecontent -replace 'ß',"ss"
            $filecontent = $filecontent -replace '\u00A0', ' '

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
        
        $previousMessages += @{
            role = $role
            content = $query
        }

        $promptToReturn = $previousMessages
    }

    else 
    {
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

function Set-OpenAICompletionCharacter {
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

function New-OpenAICompletionConversation {
    param (
        [Parameter(Mandatory=$false)]      
        [ValidateSet("Chat", "SentimentAndTickerAnalysis","SentimentAnalysis","IntentAnalysis","IntentAndSubjectAnalysis")]
        [System.Object]$Character,              # The character to use. If specified, do not add instructor and assistantReply
        [Parameter(Mandatory=$true)]  
        [string]$query,                         # The user's query to add to the prompt.
        [Parameter(Mandatory=$true)]  
        [string]$APIKey,                        # API key for ChatGPT.
        [Parameter(Mandatory=$false)]  
        [string]$instructor,                    # The instruction string to add to the prompt. Only use when you dont use a Character.
        [Parameter(Mandatory=$false)]  
        [string]$assistantReply,                # The first, unseen reply by the model. Can be used to help train it and get expected output. Only use when you dont use a Character.
        [Parameter(Mandatory=$false)]
        [string]$model = "gpt-3.5-turbo",       # The model to use from the endpoint.
        [Parameter(Mandatory=$false)]
        [string]$stop = "\n",                   # The stop instructor for the model. 
        [Parameter(Mandatory=$false)]
        [double]$temperature = 0.4,             # The temperature value to use for sampling.
        [Parameter(Mandatory=$false)]
        [int]$max_tokens = 900,                 # The maximum number of tokens to generate in the response.
        [Parameter(Mandatory=$false)]
        [string]$filePath,                      # An array of previous messages in the conversation.
        [Parameter(Mandatory=$false)]
        [bool]$ShowOutput = $false,           # The maximum number of tokens to generate in the response.
        [Parameter(Mandatory=$false)]
        [bool]$ShowTokenUsage = $false        # The maximum number of tokens to generate in the response.
    )

    Write-Verbose ("PowerGPT-New-OpenAICompletionConversation @ "+(Get-Date)+" | Initializing new conversation...")
    if ($Character -eq $null)
    {
        Write-Verbose ("PowerGPT-New-OpenAICompletionConversation @ "+(Get-Date)+" | Character is not provided.") 
        
        if ($filePath)
        {   Write-Verbose ("PowerGPT-New-OpenAICompletionConversation @ "+(Get-Date)+" | FilePath is provided: "+($filePath)) 
            Write-Verbose ("PowerGPT-New-OpenAICompletionConversation @ "+(Get-Date)+" | Generating prompt... ") 
            $promptForAPI = New-OpenAICompletionPrompt -query $query -instructor $instructor -role "user" -assistantReply $assistantReply -filePath $filePath
        }
        else {
            Write-Verbose ("PowerGPT-New-OpenAICompletionConversation @ "+(Get-Date)+" | FilePath is not provided") 
            $promptForAPI = New-OpenAICompletionPrompt -query $query -instructor $instructor -role "user" -assistantReply $assistantReply
        }
        Write-Verbose ("PowerGPT-New-OpenAICompletionConversation @ "+(Get-Date)+" | Calling OpenAI Completion API with prompt...") 
        #$promptToReturn = Invoke-OpenAICompletion -Prompt $promptForAPI -APIKey $APIKey -Model $model -temperature $temperature -stop $stop -max_tokens $max_tokens -ShowTokenUsage $ShowTokenUsage -ShowOutput $ShowOutput
    }
    else 
    {
        $characterPrompt= Set-OpenAICompletionCharacter -mode $Character
        If ($filePath)
        {
            $promptForAPI = New-OpenAICompletionPrompt -query $query -role "user" -previousMessages $characterPrompt -filePath $filePath 
        }

        else {
            $promptForAPI = New-OpenAICompletionPrompt -query $query -role "user" -previousMessages $characterPrompt
        }
        
        #$promptToReturn = Invoke-OpenAICompletion -Prompt $promptForAPI -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens -model $model -stop $stop -ShowTokenUsage $ShowTokenUsage -ShowOutput $ShowOutput
    }
    $promptToReturn = Invoke-OpenAICompletion -Prompt $promptForAPI -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens -model $model -stop $stop -ShowTokenUsage $ShowTokenUsage -ShowOutput $ShowOutput

    return $promptToReturn
}

function Add-OpenAICompletionMessageToConversation {
    param (
        [Parameter(Mandatory=$true)]  
        [string]$query,                         # The user's query to be added to the conversation.
        [Parameter(Mandatory=$true)]  
        [System.Object]$previousMessages,       # An array of previous messages in the conversation.
        [Parameter(Mandatory=$true)]    
        [string]$APIKey,                        # API key for ChatGPT
        [Parameter(Mandatory=$false)]
        [string]$model = "gpt-3.5-turbo",       # The model to use from the endpoint.
        [Parameter(Mandatory=$false)]
        [string]$stop = "\n",                   # The stop instructor for the model. 
        [Parameter(Mandatory=$false)]
        [double]$temperature = 0.4,             # The temperature value to use for sampling.
        [Parameter(Mandatory=$false)]
        [int]$max_tokens = 900,                  # The maximum number of tokens to generate in the response.
        [Parameter(Mandatory=$false)]
        [string]$filePath,                       # An array of previous messages in the conversation.
        [Parameter(Mandatory=$false)]
        [bool]$ShowOutput = $false,                    # The maximum number of tokens to generate in the response.
        [Parameter(Mandatory=$false)]
        [bool]$ShowTokenUsage = $false                 # The maximum number of tokens to generate in the response.
    )

    if ($filePath)
    {
        $prompt = New-OpenAICompletionPrompt -query $query -role "user" -previousMessages $previousMessages -filePath $filePath
    }
    else {
        $prompt = New-OpenAICompletionPrompt -query $query -role "user" -previousMessages $previousMessages
    }

    # Call the Invoke-ChatGPT function to get the response from the API.
    $returnPromptFromAPI = Invoke-OpenAICompletion -prompt $prompt -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens -model $model -stop $stop -ShowTokenUsage $ShowTokenUsage -ShowOutput $ShowOutput
    
    # Return the response from the API and the updated previous messages.
    return $returnPromptFromAPI
    
}

function New-OpenAIEdit {
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
	param(
		[Parameter(Mandatory=$true)]
        [string]$filePath,
        [Parameter(Mandatory=$true)]
        [ValidateSet("txt", "csv", "json")]
        [string]$TypeToExport
	)

    Write-Verbose ("PowerGPT-Convert-PDFtoText @ "+(Get-Date)+" | Convertig PDF to Text: "+($filepath)) 
    
    #Need to generalize this. Make .dll part of module. 
    
    Add-Type -Path "C:\ps\itextsharp.dll"
    Write-Verbose ("PowerGPT-Convert-PDFtoText @ "+(Get-Date)+" | Loaded itextsharp.dll") 
    $pdf = New-Object iTextSharp.text.pdf.pdfreader -ArgumentList $filePath
    Write-Verbose ("PowerGPT-Convert-PDFtoText @ "+(Get-Date)+" | PDF was found.") 


    $text = ""
	for ($page = 1; $page -le $pdf.NumberOfPages; $page++){
        Write-Verbose ("PowerGPT-Convert-PDFtoText @ "+(Get-Date)+" | Parsing text...") 
		$text+=([iTextSharp.text.pdf.parser.PdfTextExtractor]::GetTextFromPage($pdf,$page))
	}	
	$pdf.Close()


    if ($text -eq "" -or $text -eq " " -or $text -eq $null)
    {
        Write-Host ("PowerGPT-Convert-PDFtoText @ "+(Get-Date)+" | PDF was found, but it looks like its empty. Either it really has no text or it consist only of pictures or a Scan. PowerGPT does not have OCR. The prompt will not have any additional content in it.") -ForegroundColor Red
    }

    Write-Verbose ("PowerGPT-Convert-PDFtoText @ "+(Get-Date)+" | Done parsing PDF. Preparing export to .txt") 

    if ($filePath.Contains("\"))
    {
        Write-Verbose ("PowerGPT-Convert-PDFtoText @ "+(Get-Date)+" | Filepath is the whole path. Splitting it up...") 
        $filename = $filepath.split("\")[($filepath.split("\")).count-1]
        $basenamefile = ($filename.Split(".pdf"))[0]
        $Outputfolder = ($filepath.split($basenamefile))[0]
    }
    else {
        Write-Verbose ("PowerGPT-Convert-PDFtoText @ "+(Get-Date)+" | Filepath is only filename. Indicates run in the dir where the script was launched") 
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
            Write-Host ("PowerGPT-Convert-PDFtoText @ "+(Get-Date)+" | Invalid option for Switch.")
        }
    }

    Write-Verbose ("PowerGPT-Convert-PDFtoText @ "+(Get-Date)+" | Export type is: "+($exportEnding)) 

    $OutputPath = $Outputfolder+$basenamefile+$exportEnding

    Write-Verbose ("PowerGPT-Convert-PDFtoText @ "+(Get-Date)+" | Outputpath is: "+($OutputPath)) 

    $text | Out-File $OutputPath -Force
    return $OutputPath
}

function Get-PowerGPTHelpMessage {
    Write-Host ("PowerGPT @ "+(Get-Date)+" | To include a file for the model to reference in the prompt, use the following notation 'file | pathtofile | instruction' in the query.") -ForegroundColor DarkMagenta
    Write-Host ("PowerGPT @ "+(Get-Date)+" | Supported file types are: .txt, .pdf, .csv, .json") -ForegroundColor DarkMagenta
    Write-Host ("-------------------------------------------------------------------------------------------------------------------------") -ForegroundColor DarkGray
    Write-Host ("PowerGPT @ "+(Get-Date)+" | Example: file | C:\Users\Yanik\test.txt | Summarize this:") -ForegroundColor DarkGray
    Write-Host ("PowerGPT @ "+(Get-Date)+" | This will summarize the content in the file 'test.txt'") -ForegroundColor DarkGray
    Write-Host ("-------------------------------------------------------------------------------------------------------------------------") -ForegroundColor DarkGray
    Write-Host ("PowerGPT @ "+(Get-Date)+" | There are a few other commands available. ") -ForegroundColor DarkMagenta
    Write-Host ("-------------------------------------------------------------------------------------------------------------------------") -ForegroundColor DarkGray
    Write-Host ("PowerGPT @ "+(Get-Date)+" | Start a new conversation:  ") -ForegroundColor DarkGray
    Write-Host ("PowerGPT @ "+(Get-Date)+" | newconvo | ") -ForegroundColor DarkGray
    Write-Host ("-------------------------------------------------------------------------------------------------------------------------") -ForegroundColor DarkGray
    Write-Host ("PowerGPT @ "+(Get-Date)+" | Export the current prompt: ") -ForegroundColor DarkGray
    Write-Host ("PowerGPT @ "+(Get-Date)+" | export | ") -ForegroundColor DarkGray
    Write-Host ("-------------------------------------------------------------------------------------------------------------------------") -ForegroundColor DarkGray

    Write-Host ("PowerGPT @ "+(Get-Date)+" | Stop PowerGPT: ") -ForegroundColor DarkGray
    Write-Host ("PowerGPT @ "+(Get-Date)+" | quit | ") -ForegroundColor DarkGray
    Write-Host ("-------------------------------------------------------------------------------------------------------------------------") -ForegroundColor DarkGray

    Write-Host ("PowerGPT @ "+(Get-Date)+" | Stop PowerGPT and export the prompt: ") -ForegroundColor DarkGray
    Write-Host ("PowerGPT @ "+(Get-Date)+" | quit | export") -ForegroundColor DarkGray
    Write-Host ("-------------------------------------------------------------------------------------------------------------------------") -ForegroundColor DarkGray
}

function Start-PowerGPT {
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

        .PARAMETER model
        The model of the endpoint to use.

        .PARAMETER stop
        The stop instructor for the model. Tell is where it should generating output.

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
        PS> $model = "gpt-3.5-turbo" 
        PS> $stop = "\n"
        PS> $APIKey = "YOUR_API_KEY"
        PS> $temperature = 0.6
        PS> $max_tokens = 3500
        PS> Start-ChatGPTforPowerShell -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens -model $model -stop $stop
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
        [string]$APIKey,                        # API key for ChatGPT
        [Parameter(Mandatory=$false)]
        [string]$model = "gpt-3.5-turbo",       # The model to use from the endpoint.
        [Parameter(Mandatory=$false)]
        [string]$stop = "\n",                   # The stop instructor for the model. 
        [Parameter(Mandatory=$false)]
        [double]$temperature = 0.4,             # The temperature value to use for sampling.
        [Parameter(Mandatory=$false)]
        [int]$max_tokens = 900,                  # The maximum number of tokens to generate in the response.
        [bool]$ShowOutput = $false,                    # The maximum number of tokens to generate in the response.
        [Parameter(Mandatory=$false)]
        [bool]$ShowTokenUsage = $false                 # The maximum number of tokens to generate in the response.
    )

    Write-Verbose ("PowerGPT @ "+(Get-Date)+" | Initializing... ") 

    $contiueConversation = $(Write-Host ("PowerGPT @ "+(Get-Date)+" | Do you want to restore an existing conversation? (enter 'y' or 'yes'): ") -ForegroundColor yellow -NoNewLine; Read-Host) 

    if ($contiueConversation  -eq "y" -or $contiueConversation -eq "yes")
    {
        Get-PowerGPTHelpMessage
        $importPath = $(Write-Host ("PowerGPT @ "+(Get-Date)+" | Provide the full path to the prompt*.json file you want to continue the conversation on: ") -ForegroundColor yellow -NoNewLine; Read-Host) 
        $importedPrompt = Import-OpenAIPromptFromJson -Path $importPath
        $previousMessages = $importedPrompt
    }
    else 
    {
        # Display a welcome message and instructions for stopping the conversation.
        Get-PowerGPTHelpMessage

        # Initialize the previous messages array.
        $previousMessages = @()

        #select the character
        $option = Read-Host ("PowerGPT @ "+(Get-Date)+" | Select the Character the Model should assume:`n1: Chat`n2: Ticker and Sentiment Analysis`n3: Sentiment Analysis`n4: Intent Analysis`n5: Intent & Topic Analysis`nPowerGPT @ "+(Get-Date)+" | Enter the according number of the character you'd like")

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
                Write-Host ("PowerGPT @ "+(Get-Date)+" | Invalid option selected.")
            }
        }
        Write-Verbose ("PowerGPT @ "+(Get-Date)+" | Selected Character is: "+($Character)) 
        $InitialQuery = Read-Host ("PowerGPT @ "+(Get-Date)+" | Your query for ChatGPT or commands for PowerGPT")

        Write-Verbose ("PowerGPT @ "+(Get-Date)+" | InitialQuery is: "+($InitialQuery)) 

        switch -Regex ($InitialQuery) {
            "^file \|.*" {
                Write-Verbose ("PowerGPT @ "+(Get-Date)+" | InitialQuery is File command")

                $filePath = (($InitialQuery.split("|"))[1]).TrimStart(" ")
                $filepath = $filePath.TrimEnd(" ")
                $FileQuery = (($InitialQuery.split("|"))[2]).TrimStart(" ")

                Write-Verbose ("PowerGPT @ "+(Get-Date)+" | Extracted FilePath from Query is: "+($filePath)) 
                Write-Verbose ("PowerGPT @ "+(Get-Date)+" | Extracted Query is: "+($FileQuery))
                Write-Verbose ("PowerGPT @ "+(Get-Date)+" | Starting Conversation...") 

                $conversationPrompt = New-OpenAICompletionConversation -Character $Character -query $FileQuery -instructor $instructor -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens -model $model -stop $stop -filePath $filePath -ShowTokenUsage $ShowTokenUsage -ShowOutput $ShowOutput
                Write-Host ("CompletionAPI @ "+(Get-Date)+" | "+($conversationPrompt[($conversationPrompt.count)-1].content)) -ForegroundColor Green

            }
            "^quit \|.*" {
                Write-Host ("PowerGPT @ "+(Get-Date)+" | PowerGPT is exiting now...") -ForegroundColor Yellow
                Start-Sleep 5
                exit
            }
            "^export \|.*" {
                Write-Host ("PowerGPT @ "+(Get-Date)+" | PowerGPT has nothing to export :(") -ForegroundColor Yellow
            }
            "^\s*$" {
                Write-Host ("PowerGPT @ "+(Get-Date)+" | You have not provided any input. Will not send this query to the CompletionAPI") -ForegroundColor Yellow
                $conversationPrompt = Set-OpenAICompletionCharacter $Character
            }
            default {
                $conversationPrompt = New-OpenAICompletionConversation -Character $Character -query $InitialQuery -instructor $instructor -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens -model $model -stop $stop -ShowTokenUsage $ShowTokenUsage -ShowOutput $ShowOutput
                Write-Host ("CompletionAPI @ "+(Get-Date)+" | "+($conversationPrompt[($conversationPrompt.count)-1].content)) -ForegroundColor Green
            }
        }

        $previousMessages += $conversationPrompt
    }

    # Initialize the continue variable.
    $continue = $true

    # Loop until the user stops the conversation.
    while ($continue) {

        # Prompt the user to enter their query for ChatGPT or commands for PowerGPT.
        $userQuery = Read-Host ("PowerGPT @ "+(Get-Date)+" | Your query for ChatGPT or commands for PowerGPT")

        switch -Regex ($userQuery) {
            "^file \|.*" {
                Write-Verbose ("PowerGPT @ "+(Get-Date)+" | InitialQuery is File command")

                $filePath = (($userQuery.split("|"))[1]).TrimStart(" ")
                $filepath = $filePath.TrimEnd(" ")
                $FileQuery = (($userQuery.split("|"))[2]).TrimStart(" ")

                Write-Verbose ("PowerGPT @ "+(Get-Date)+" | Extracted FilePath from Query is: "+($filePath)) 
                Write-Verbose ("PowerGPT @ "+(Get-Date)+" | Extracted Query is: "+($FileQuery))
                Write-Verbose ("PowerGPT @ "+(Get-Date)+" | Starting Conversation...") 

                $conversationPrompt = New-OpenAICompletionConversation -Character $Character -query $FileQuery -instructor $instructor -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens -model $model -stop $stop -filePath $filePath -ShowTokenUsage $ShowTokenUsage -ShowOutput $ShowOutput
                Write-Host $conversationPrompt[($conversationPrompt.count)-1].content -ForegroundColor Green
            }
            "^newconvo \|.*" {
                Start-PowerGPT -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens -model $model -stop $stop
            }
            "^quit \|.*" {
                $exportBool = $(Write-Host ("PowerGPT @ "+(Get-Date)+" | Do you want to export the current prompt before exiting? Enter 'y' or 'yes': ") -ForegroundColor yellow -NoNewLine; Read-Host) 
                if ($exportBool -eq "y" -or $exportBool -eq "yes" -or $exportBool -eq "Y" -or $exportBool -eq "YES")
                {
                    $exportPath = $(Write-Host ("PowerGPT @ "+(Get-Date)+" | Provide the full path to the prompt*.json file that you want to export now and later continue the conversation on: ") -ForegroundColor yellow -NoNewLine; Read-Host) 
                    Write-Host ("PowerGPT @ "+(Get-Date)+" | PowerGPT exported the prompt to: "+($exportPath)) -ForegroundColor yellow
                }
                Write-Host ("PowerGPT @ "+(Get-Date)+" | PowerGPT is exiting now...") -ForegroundColor yellow
                Start-Sleep 5
                exit
            }
            "^export \|.*" {
                $exportPath = $(Write-Host ("PowerGPT @ "+(Get-Date)+" | Provide the full path to the prompt*.json file that you want to export now and later continue the conversation on: ") -ForegroundColor yellow -NoNewLine; Read-Host) 
                Export-OpenAIPromptToJson -Path $exportPath -prompt $previousMessages
                Write-Host ("PowerGPT @ "+(Get-Date)+" | PowerGPT exported the prompt to: "+($exportPath)) -ForegroundColor yellow
            }
            "^\s*$" {
                Write-Host ("PowerGPT @ "+(Get-Date)+" | You have not provided any input. Will not send this query to the CompletionAPI") -ForegroundColor Yellow
                $conversationPrompt = Set-OpenAICompletionCharacter $Character
            }
            default {
                $conversationPrompt = Add-OpenAICompletionMessageToConversation -query $userQuery -previousMessages $previousMessages -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens -model $model -stop $stop -ShowTokenUsage $ShowTokenUsage -ShowOutput $ShowOutput
                Write-Host $conversationPrompt[($conversationPrompt.count)-1].content -ForegroundColor Green
            }
        }
        $previousMessages = $conversationPrompt
    }
}
