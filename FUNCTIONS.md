# NOT UP TO DATE. CHECK SOURCE
## New-CompletionAPIPrompt
This function is used to create a prompt for the `Invoke-CompletionAPI` function.

### Parameters
- `$query`: The user's query to add to the prompt. This parameter is mandatory.
- `$role`: The role to add to the prompt. The role can be one of three values: "system", "assistant", or "user". This parameter is mandatory.
- `$instructor`: The instruction string to add to the prompt. This parameter is optional.
- `$assistantReply`: The first, unseen reply by the model. This parameter can be used to help train the model and get expected output. This parameter is optional.
- `$previousMessages`: An array of previous messages in the conversation. This parameter is optional.

### Usage
The `New-CompletionAPIPrompt` function is used by the `Invoke-CompletionAPI` function to create a prompt that includes the user's query, the role of the user in the conversation, an instruction string, and previous messages in the conversation. The resulting prompt is then sent to the OpenAI API for completion.

### Example
```powershell
New-CompletionAPIPrompt -query "What is the Capitol of Switzerland?" -role "user" -instructor "You are a helpful AI." -assistantReply "How can I help you today?"
```

### Output
```powershell
Name                           Value
----                           -----
content                        You are a helpful AI.
role                           system
content                        How can I help you today?
role                           assistant
content                        What is the Capitol of Switzerland?
role                           user
```

## Invoke-CompletionAPI
This PowerShell function is used to send a prompt to the OpenAI Completion API, get a response, and append it to the prompt.

### Parameters
- `$prompt`: The prompt to send to the API to act upon. This parameter is mandatory and accepts a System.Object data type. This parameter is mandatory.
- `$APIKey`: The API key to authenticate the request. This parameter is mandatory and accepts a string data type. This parameter is mandatory.
- `$temperature`: The temperature value to use for sampling. This parameter is mandatory and accepts a double data type. This parameter is mandatory.
- `$max_tokens`: The maximum number of tokens to generate in the response. This parameter is mandatory and accepts an integer data type. This parameter is mandatory.

### Usage
This PowerShell function is used to send a prompt to the OpenAI Completion API, get a response, and append it to the prompt.

### Example
First we need to generate a prompt we can send to the API. We use `New-CompletionAPIPrompt` for that:
```powershell
$prompt = New-CompletionAPIPrompt -query "What is the Capitol of Switzerland?" -role "user" -instructor "You are a helpful AI." -assistantReply "How can I help you today?"
```
Then we need to define the `$APIKey`, `$temperature` and `$max_token` parameters:
```powershell
$APIKey = "YOUR_API_KEY"
$temperature = 0.6
$max_tokens = 3500
```
Ultimately, we can use `Invoke-CompletionAPI` with all the parameters we just just declared, to invoke the Open AI Completion API with our prompt:
```powershell
$response = Invoke-CompletionAPI -prompt $prompt -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens   

```

### Output
The function returns the new full prompt with the added text response from the API.
```powershell
ChatGPT: The capital of Switzerland is Bern.
```

```powershell
PS C:\Users\Yanik> $response

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

```

## Set-CompletionAPICharacter
This function generates a "Character" (a prompt that represents a character) to use. 
These five characters are hardcoded into that function:
- `Chat`: Instructed to be a helpful AI assistant
- `SentimentAnalysis`: Analyzes the sentiment of a text and responds in a defined .JSON format
- `SentimentAndTickerAnalysis`: Analyzes the sentiment of a text and extracts the ticker of an asset that mentioned within and responds in a defined .JSON format
- `IntentAnalysis`: Analyzes the intent of a text and responds in a defined .JSON format
- `IntentAndSubjectAnalysis` Analyzes the intent and subject of a text and responds in a defined .JSON format

### Parameters
- `$mode`: The Character/Mode that is used to generate the prompt. This parameter is mandatory.

### Usage
It returns the generated character prompt to use, append a user query and send it to the Open AI Completion API. It is used by the `New-CompletionAPIConversation` function to create a Conversation based on a character.

### Example
```powershell
$character = Set-CompletionAPICharacter -mode SentimentAnalysis
```

### Output
```powershell
PS C:\Users\Yanik> $character

Name                           Value
----                           -----
content                        You are an API that analyzes text sentiment. You provide your answer in a .JSON format in the following structure: { "sentiment": 0.9 } You only answer with the .JSON object. You do not provide any reasoning why you did it that way.  The sentiment is a value between 0 - 1. Where 1 is th... 
role                           system
content                        {sentiment}
role                           assistant
```


## New-CompletionAPIConversation

This is a wrapper function that creates the prompt and calls the Open AI API using "New-CompletionAPIPrompt" and "Invoke-CompletionAPI".

### Parameters

- `Character` - A string that determines the type of conversation to have. Valid options are "Chat", "SentimentAndTickerAnalysis", "SentimentAnalysis", "IntentAnalysis", and "IntentAndSubjectAnalysis". If specified, do not add instructor and assistantReply. This parameter is optional.
- `query` - A string representing the user's query to add to the prompt. This parameter is mandatory.
- `instructor` - A string representing the instruction string to add to the prompt. Only use when you dont use a Character. This parameter is optional.
- `assistantReply` - A string representing the first, unseen reply by the model. Can be used to help train it and get expected output. Only use when you dont use a Character. This parameter is optional.
- `APIKey` - A string representing the API key for ChatGPT. This parameter is mandatory.
- `temperature` - A double representing the temperature value to use for sampling. This parameter is mandatory.
- `max_tokens` - An integer representing the maximum number of tokens to generate in the response. This parameter is mandatory.

If Character is null, it creates a prompt with the user's query, instruction string, and assistant reply (if provided) and calls `Invoke-CompletionAPI` to generate a response. If Character is not null, it creates a prompt with the user's query and the character's previous messages and calls `Invoke-CompletionAPI` to generate a response.

### Usage
This function can be used to easily interact with the Open AI API for generating responses to user queries in various conversational contexts.

### Example
First we need to define the `$APIKey`, `$temperature` and `$max_token` parameters:
```powershell
$APIKey = "YOUR_API_KEY"
$temperature = 0.6
$max_tokens = 3500
```
Then we can use `New-CompletionAPIConversation` and pass along the character, query and API parameters we defined above:
```powershell
$conversation = New-CompletionAPIConversation -Character SentimentAnalysis -query "Twitter is amazing" -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens
```

### Output
```powershell
ChatGPT: { "sentiment": 0.875 }
```
```powershell
PS C:\Users\Yanik> $conversation

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
```

## Add-CompletionAPIMessageToConversation
This function acts as a wrapper and adds a new message to an existing conversation or prompt using the given parameters. 

### Parameters
- `query`: A mandatory parameter that represents the user's query to be added to the conversation. It is of type string.
- `previousMessages`: A mandatory parameter that represents an array of previous messages in the conversation. It is of type System.Object. 
- `instructor`: An optional parameter that represents the instruction string to add to the prompt. It is of type string. 
- `APIKey`: A mandatory parameter that represents the API key for ChatGPT. It is of type string. 
- `temperature`: A mandatory parameter that represents the temperature value to use for sampling. It is of type double. 
- `max_tokens`: A mandatory parameter that represents the maximum number of tokens to generate in the response. It is of type int. 

### Usage
The function is used by `Start-ChatGPTforPowerShell`. It creates a new prompt using `New-CompletionAPIPrompt` with the given query and previous messages, and passes it to the `Invoke-CompletionAPI` function to get a response from the API. The function then returns the response from the API and the updated previous messages.

### Example
First we need to define the `$APIKey`, `$temperature` and `$max_token` parameters:
```powershell
$APIKey = "YOUR_API_KEY"
$temperature = 0.6
$max_tokens = 3500
```
We also need some values for $previousMessages, where we want to append a message to the prompt:
```powershell
$previousMessages = New-CompletionAPIConversation -Character SentimentAnalysis -query "Twitter is amazing" -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens

```

Then we can use `Add-CompletionAPIMessageToConversation` and pass along the $previousMessages, so that it adds them to the prompt and calls the API with the updated prompt.

```powershell
$conversation = Add-CompletionAPIMessageToConversation -query "I dont like Twitter" -previousMessages $conversation -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens 
```

### Output
```powershell
ChatGPT: { "sentiment": 0.0 }
```
```powershell
PS C:\Users\Yanik> $conversation

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
```




## Start-ChatGPTforPowerShell 
This PowerShell function starts a conversation with the ChatGPT API, allowing users to interact with the model via PowerShell. The function accepts three mandatory parameters: APIKey, temperature, and max_tokens.

The function prompts the user to either start a new conversation or restore an existing one. If the user chooses to restore an existing conversation, they must provide the full path to the prompt*.json file.

If the user chooses to start a new conversation, the function prompts the user to select the character that the model should assume. The available options are:

- `Chat`: Instructed to be a helpful AI assistant
- `SentimentAnalysis`: Analyzes the sentiment of a text and responds in a defined .JSON format
- `SentimentAndTickerAnalysis`: Analyzes the sentiment of a text and extracts the ticker of an asset that mentioned within and responds in a defined .JSON format
- `IntentAnalysis`: Analyzes the intent of a text and responds in a defined .JSON format
- `IntentAndSubjectAnalysis` Analyzes the intent and subject of a text and responds in a defined .JSON format

The user must then enter their query for ChatGPT. The function adds the query to the conversation and retrieves the response from ChatGPT.
The conversation continues until the user enters 'q' or 'quit'. At that point, the function prompts the user to export the current prompt for future use and/or start a new conversation. If the user chooses to export the prompt, they must provide the full path to the prompt*.json file.

If the user chooses to start a new conversation, the function calls itself recursively. If the user chooses to exit the conversation, the function ends.

### Import and Export of conversation prompts
A conversation with the gpt-3.5-turbo Model via OpenAI's APIs is made up of prompts. A prompt can also be used to steer the behaviour of the model. It can for instance, become a pirate, an actor, or anything you want it to be. Literally. At some point you may want to export your current prompt, so that you can continue on it. 

The import and export functions allow users exactly that; to continue conversations from a previous session or save a conversation for later use.

The user needs to provide the full path to a prompt*.json file that contains the prompts and responses from a previous conversation. The function uses the `Import-PromptFromJson` function to import the prompts and responses from the file.

The export functionality allows the user to save the prompts and responses from the current conversation to a prompt*.json file, which can be used later to continue the conversation. The user is prompted to provide the full path to the file and then it is written to disk using the `Out-File` function.

### Parameters
- `APIKey` - The API key for ChatGPT. This parameter is mandatory.
- `temperature` - The temperature parameter for ChatGPT. This parameter is mandatory.
- `max_tokens` - The max_tokens parameter for ChatGPT. This parameter is mandatory.

### Usage
```powershell
$APIKey = "YOUR_API_KEY"
$temperature = 0.6
$max_tokens = 3500
```
```powershell
Start-ChatGPTforPowerShell -APIKey $APIKey -temperature $temperature -max_tokens $max_tokens
```

### Output
```powershell
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
```

## Import-PromptFromJson
This function takes in a file path to a JSON file that contains a prompt for a ChatGPT conversation and converts the JSON data into a PowerShell object.
### Parameters
- `Path`: Required. The file path to the JSON file containing the prompt. This parameter is mandatory.

### Usage
```powershell
prompt = Import-PromptFromJson -Path bern.json
```
### Output
```powershell
PS C:\Users\Yanik> $prompt

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
```

## Export-PromptToJson
This function takes in a file path to a JSON file that contains a prompt for a ChatGPT conversation and converts the JSON data into a PowerShell object.

### Parameters
- `Path`: Required. The file path to the JSON file containing the prompt. This parameter is mandatory.
- `Prompt`: Required. The prompt (System.Object) to export to a .JSON file.
### Usage
```powershell
Export-PromptToJson -Path myprompt.json -prompt $prompt 
```
