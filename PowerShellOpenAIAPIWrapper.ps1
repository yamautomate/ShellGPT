function Invoke-OpenAIAPI {
    param (    
        $prompt,        # The initial prompt to send to the API.
        $APIKey,        # The API key to authenticate the request.
        $model,         # The ID of the GPT model to use.
        $temperature,   # The temperature value to use for sampling.
        $stop,          # The string to use as a stopping criterion
        $max_tokens     # The maximum number of tokens to generate in the response.

    )

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

    #Convert the whole Body to be JSON, so that API likes it.
    $RequestBody = $RequestBody | ConvertTo-Json

    $RestMethodParameter=@{
        Method='Post'
        Uri ='https://api.openai.com/v1/chat/completions'
        body=$RequestBody
        Headers=$Headers
        ContentType='application/json'
    }

    try {
        #Call the OpenAI completions API
        $APIresponse = Invoke-RestMethod @RestMethodParameter -ErrorAction SilentlyContinue

        #Extract Textresponse from API response
        $convertedResponseForOutput = $APIresponse.choices.message.content

        #Append text output to prompt for returning it
        $prompt = New-OpenAIAPIPrompt -query $convertedResponseForOutput -role "assistant" -previousMessages $prompt

        $promptToReturn = $prompt
    }
    catch {
        # If there was an error, throw an exception and output an error message.
        Throw $_.Exception.Message
        $convertedResponseForOutput = "Unable to handle error. Retry query."
    }

    #Output the text response.
    write-host "ChatGPT:"$convertedResponseForOutput -ForegroundColor Green

    #return the new full prompt with the added text response from the API
    return $promptToReturn
}

# This function constructs a new prompt for sending to the API, either as a new conversation or as a continuation of an existing conversation.
function New-OpenAIAPIPrompt {
    param (   
        $query,             # The user's query to add to the prompt. 
        $role,              # The role to add to the prompt. 
        $instructor,        # The instruction string to add to the prompt.
        $previousMessages   # An array of previous messages in the conversation.
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
        $promptToReturn = @(
            @{
                role = "system"
                content = $instructor
            },
            @{
                role = "assistant"
                content = "Hello! I'm a GPT-3.5-turbo model. How can I assist you?"
            },
            @{
                role = $role
                content = $query
            }
        )

    }

    return $promptToReturn
}


# A wrapper function that creates the prompt and calls the Open AI API using "New-ChatGPTPrompt" and "Invoke-OpenAIAPI"
function New-OpenAIAPIConversation {
    param (
          
        $query,         # The user's query to add to the prompt.
        $instructor,    # The instruction string to add to the prompt.
        $APIKey,        # API key for ChatGPT.
        $model,         # The ID of the GPT model to use.
        $temperature,   # The temperature value to use for sampling.
        $stop,          # The string to use as a stopping criterion.
        $max_tokens     # The maximum number of tokens to generate in the response.
    )

    $promptForAPI = New-OpenAIAPIPrompt -query $query -instructor $instructor -role "user"
    $returnPromptFromAPI = Invoke-OpenAIAPI -Prompt $promptForAPI -APIKey $APIKey -Model $model -temperature $temperature -stop $stop -max_tokens $max_tokens

    return $returnPromptFromAPI
}


# This function acts as a wrappe and adds a new message to an existing ChatGPT conversation using the given parameters.
function Add-OpenAIAPIMessageToConversation {
    param (
        $query,             # The user's query to be added to the conversation.
        $previousMessages,  # An array of previous messages in the conversation.
        $instructor,        # The instruction string to add to the prompt..
        $APIKey,            # API key for ChatGPT.
        $model,             # The ID of the GPT model to use.
        $temperature,       # The temperature value to use for sampling.
        $stop,              # The string to use as a stopping criterion.
        $max_tokens         # The maximum number of tokens to generate in the response.
    )

    $prompt = New-OpenAIAPIPrompt -query $query -role "user" -instructor $instructor -previousMessages $previousMessages

    # Call the Invoke-ChatGPT function to get the response from the API.
    $returnPromptFromAPI = Invoke-OpenAIAPI -prompt $prompt -APIKey $APIKey -Model $model -temperature $temperature -stop $stop -max_tokens $max_tokens
    
    # Return the response from the API and the updated previous messages.
    return $returnPromptFromAPI
    
}


function Import-PromptFromJson {
    param (
        [string]$Path
    )

    $promptJson = Get-Content -Path $Path -Raw
    $prompt = $promptJson | ConvertFrom-Json

    return $prompt
}

# This function starts a new ChatGPT conversation.
function Start-ChatGPTforPowerShell {
    param (
        $APIKey,          # API key for ChatGPT
        $model,           # ChatGPT model to use
        $temperature,     # Temperature parameter for ChatGPT
        $stop,            # Stop parameter for ChatGPT
        $max_tokens       # Max_tokens parameter for ChatGPT
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

        # Prompt the user to provide the instructor for ChatGPT.
        $instructor = $(Write-Host "Provide the instructor for ChatGPT: " -ForegroundColor DarkGreen -NoNewLine; Read-Host) 

        # Call the Invoke-ChatGPTConversation function to start the conversation and add the initial prompt to the previous messages array.
        $conversationPrompt = New-OpenAIAPIConversation -query (Read-Host "Your query for ChatGPT") -instructor $instructor -APIKey $APIKey -model $model -temperature $temperature -stop $stop -max_tokens $max_tokens

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
                Start-ChatGPTforPowerShell -APIKey $APIKey -model $model -temperature $temperature -stop $stop -max_tokens $max_tokens
            }
        }
        else
        {
            # Call the Add-ChatGPTMessageToConversation function to add the user's query to the conversation and get the response from ChatGPT.
            $conversationPrompt = Add-OpenAIAPIMessageToConversation -query $userQuery -previousMessages $previousMessages -instructor $instructor -APIKey $APIKey -Model $model -temperature $temperature -stop $stop -max_tokens $max_tokens
            $previousMessages = $conversationPrompt
        }
    }
}

$APIKey = "YOUR_API_KEY"
$model = "gpt-3.5-turbo" 
$temperature = 0.6
$stop = "\n"
$max_tokens = 3500

Start-ChatGPTforPowerShell -APIKey $APIKey -model $model -temperature $temperature -stop $stop -max_tokens $max_tokens
