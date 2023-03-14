@{
    ModuleVersion = '1.1'
    GUID = 'a038bbff-4e60-4201-944e-b2e6a01ed20c'
    RootModule = 'CompletionAPI.psm1'
    FunctionsToExport = @('Invoke-CompletionAPI', 'New-CompletionAPIPrompt', 'Set-CompletionAPICharacter', 'New-CompletionAPIConversation', 'Add-CompletionAPIMessageToConversation', 'Start-ChatGPTforPowerShell', 'Import-PromptFromJson')
    PowerShellVersion = '5.1'
    Author = 'Yanik Maurer'
    Description = 'A set of PowerShell functions to have a chat with OpenAIs completion API.' 
    ProjectUri = 'GitHub Repo: https://github.com/yamautomate/PowerShell-OpenAI-API-Wrapper'  
}
