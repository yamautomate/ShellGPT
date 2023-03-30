@{
    ModuleVersion = '1.3'
    GUID = 'a038bbff-4e60-4201-944e-b2e6a01ed20c'
    RootModule = 'PowerGPT.psm1'
    FunctionsToExport = @('Invoke-CompletionAPI', 'New-CompletionAPIPrompt', 'Set-CompletionAPICharacter', 'New-CompletionAPIConversation', 'Add-CompletionAPIMessageToConversation', 'Start-PowerGPT', 'Import-PromptFromJson', 'Export-PromptToJson')
    PowerShellVersion = '5.1'
    Author = 'Yanik Maurer'
    Description = 'The CompletionAPI PowerShell Module is a command-line tool that provides an easy-to-use interface for accessing OpenAIs GPT API using PowerShell. It makes it easy to access the full potential of GPT-3 from the comfort of your command line and within your scripts and automations. GitHub Repo: https://github.com/yamautomate/PowerGPT' 
}
