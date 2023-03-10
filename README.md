# PowerShell Open AI API Wrapper
A set of PowerShell functions to have a chat with OpenAIs completion API via PowerShell.

## Invoke-OpenAIAPI

This function sends a request to the OpenAI API to generate a response for the given prompt. It takes the following parameters:

- `$prompt`: The initial prompt to send to the API.
- `$APIKey`: The API key to authenticate the request.
- `$model`: The ID of the GPT model to use.
- `$temperature`: The temperature value to use for sampling.
- `$stop`: The string to use as a stopping criterion.
- `$max_tokens`: The maximum number of tokens to generate in the response.

The function builds a request for the API, converts the prompt and the request body to JSON, and sends the request using Invoke-RestMethod. If the API returns a response, it extracts the text response from the response and returns the new full prompt with the added text response from the API.

## New-ChatGPTPrompt

This function constructs a new prompt for sending to the API, either as a new conversation or as a continuation of an existing conversation. It takes the following parameters:

- `$query`: The user's query to add to the prompt.
- `$instructor`: The instruction string to add to the prompt.
- `$PreviousPrompt`: The previous prompt, if any.

The function appends the constructed string with the query to the previous prompt if one exists, otherwise, it builds a new prompt as this indicates a "new conversation."

## Invoke-ChatGPTConversation

This function is a wrapper function that creates the prompt and calls the Open AI API using `New-ChatGPTPrompt` and `Invoke-OpenAIAPI`. It takes the following parameters:

- `$query`: The user's query to add to the prompt.
- `$instructor`: The instruction string to add to the prompt.
- `$APIKey`: API key for ChatGPT.
- `$model`: The ID of the GPT model to use.
- `$temperature`: The temperature value to use for sampling.
- `$stop`: The string to use as a stopping criterion.
- `$max_tokens`: The maximum number of tokens to generate in the response.

The function uses `New-ChatGPTPrompt` to create the prompt for the API, and then uses `Invoke-OpenAIAPI` to send the request and get a response. It returns the new full prompt with the added text response from the API.

## Add-ChatGPTMessageToConversation

This function adds a new message to an existing ChatGPT conversation using the given parameters. It takes the following parameters:

- `$query`: The user's query to be added to the conversation.
- `$previousMessages`: An array of previous messages in the conversation.
- `$instructor`: The instruction string to add to the prompt.
- `$APIKey`: API key for ChatGPT.
- `$model`: The ID of the GPT model to use.
- `$temperature`: The temperature value to use for sampling.
- `$stop`: The string to use as a stopping criterion.
- `$max_tokens`: The maximum number of tokens to generate in the response.

The function adds the new message to the previous messages, gets the last five messages from the previous messages, constructs the prompt to send to the ChatGPT API, and then uses `Invoke-OpenAIAPI` to send the request and get a response. Finally, it returns the new full prompt with the added text response from the API.
