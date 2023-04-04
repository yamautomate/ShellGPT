@{
    ModuleVersion = '1.3'
    GUID = 'a038bbff-4e60-4201-944e-b2e6a01ed20c'
    RootModule = 'PowerGPT.psm1'
    FunctionsToExport = @('Invoke-OpenAICompletion', 'New-OpenAICompletionPrompt', 'Set-OpenAICompletionCharacter', 'New-OpenAICompletionConversation', 'Add-OpenAICompletionMessageToConversation', 'New-OpenAIEdit', 'New-OpenAIImage', 'Get-OpenAIModels', 'Get-OpenAIModelById', 'Get-OpenAIFiles','Get-OpenAIFileById', 'Get-OpenAIFileContent', 'New-OpenAIFile', 'Remove-OpenAIFile', 'Get-OpenAIFineTuneJobs','Get-OpenAIFineTuneJobById','Get-OpenAIFineTuneEvents', 'Remove-OpenAIFineTuneModel', 'Stop-OpenAIFineTuneJob', 'New-OpenAIFineTuneJob', 'New-OpenAIFineTuneTrainingFile', 'Import-OpenAIPromptFromJson', 'Export-OpenAIPromptToJson', 'New-OpenAIEmbedding', 'Convert-PDFtoText', 'Get-PowerGPTHelpMessage', 'Start-PowerGPT')
    PowerShellVersion = '5.1'
    Author = 'Yanik Maurer'
    Description = 'The CompletionAPI PowerShell Module is a command-line tool that provides an easy-to-use interface for accessing OpenAIs GPT API using PowerShell. It makes it easy to access the full potential of GPT-3 from the comfort of your command line and within your scripts and automations. GitHub Repo: https://github.com/yamautomate/PowerGPT' 
}
