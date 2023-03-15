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

## Understanding prompts
Before we construct a prompt, we need to define what that actually is.
A prompt is a collection of one or more messages between one ore more parties. It resembles a conversation. It looks like this:
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

As shown above, a message in a prompt can be assigned to three roles:
- `system`
- `assistant`
- `user`

With that, we can construct a chain of messages (a conversation) between an assistant, and a user. 

The `system` value defines the general behaviour of the assistant. This is also often referred to as the "Instructor". With that, we can control what the model should behave and act like. For example: 
- "You are a helpful AI"
- "A Pirate, that answers every request with Arrrr!"
- "A villain in a James Bond Movie"

With the prompt, we can generate context for the model. For example, we can use prompts to construct a chat conversation, or use prompts to "train" the model to behave even more as we want it to. 

When we use prompts for a chat conversation, the prompt contains the whole conversation, so that the model has enough context in order to have a natural conversation. This allows the model to "remember" what you asked a few questions ago. In a conversation, we want to make sure we always incorporate the response from the model.

When we use prompts for training, the prompt also contains a conversation, but this one was specifically crafted to show the model how it should behave. This is used in the `Set-CompletionAPICharacter` function, where the function returns a "trained" character prompt we can use. 

For example, the prompt for the trained character "SentimentAnalysis" look like this:
```
Name                           Value
----                           -----
content                        You are an API that analyzes text sentiment. You provide your answer in a .JSON format in the following structure: { "sentiment": 0.9 } You only answer with the .JSON object. You do not provide any reasoning why you did it that way.  The sentiment is a va…
role                           system
content                        {[sentiment, 0.9]}
role                           assistant
```
And the Instructor expanded reads:
```
You are an API that analyzes the core intent of the text. 
You provide your answer in a .JSON format in the following structure: { "intent": descriptive verb for intent } 
You only answer with the .JSON object. 
You do not provide any reasoning why you did it that way. 
The intent represents the one intent you extracted during your analysis. 
If you can not extract the intent with a probability of 70% or more, you specify it with "unknown" in your response.
```
The more examples (messages) are provided in a prompt, the more context the model has and the more predictable becomes its output. When using a prompt for training, we only need to make sure that we can include the last question to the prompt before we run into the `max_token` limit, whereas in chat-mode we should limit training to what is only necessary.

So, essentially we stitch together an object that represents a conversation between a `system`, the `assistant` and a `user`. Then we add the users question/message to the conversation prompt and send it to the model for completion.

## How to construct prompts
TBD


# Function Documentation
For detailled funtion documentation see the FUNCTIONS.md [here](https://github.com/yamautomate/PowerShell-OpenAI-API-Wrapper/blob/main/FUNCTIONS.md).


