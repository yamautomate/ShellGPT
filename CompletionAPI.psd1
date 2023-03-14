@{
    ModuleVersion = '1.0'
    RootModule = 'CompletionAPI.psm1'
    FunctionsToExport = @('Invoke-CompletionAPI', 'New-CompletionAPIPrompt', 'Set-CompletionAPICharacter','New-CompletionAPIConversation','Add-CompletionAPIMessageToConversation', 'Start-ChatGPTforPowerShell', 'Import-PromptFromJson'  )
    PowerShellVersion = '5.1'
    Author = 'Yanik Maurer'
    Description = 'A set of PowerShell functions to have a chat with OpenAIs completion API.'
}
