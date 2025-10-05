@{
    Severity = @('Error', 'Warning')
    IncludeRules = @(
        'PSAvoidDefaultValueSwitchParameter',
        'PSAvoidGlobalVars',
        'PSAvoidLongLines',
        'PSAvoidOverwritingBuiltInCmdlets',
        'PSAvoidShouldContinueWithoutForce',
        'PSAvoidUsingCmdletAliases',
        'PSAvoidUsingConvertToSecureStringWithPlainText',
        'PSAvoidUsingEmptyCatchBlock',
        'PSAvoidUsingInvokeExpression',
        'PSAvoidUsingPlainTextForPassword',
        'PSAvoidUsingPositionalParameters',
        'PSAvoidUsingWriteHost',
        'PSDSCDscExamplesPresent',
        'PSDSCDscTestsPresent',
        'PSMisleadingBacktick',
        'PSPossibleIncorrectComparisonWithNull',
        'PSPossibleIncorrectUsageOfRedirectionOperator',
        'PSProvideCommentHelp',
        'PSUseApprovedVerbs',
        'PSUseCompatibleCommands',
        'PSUseConsistentIndentation',
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSUseLiteralInitializerForHashtable',
        'PSUseOutputTypeCorrectly',
        'PSUseSingularNouns',
        'PSUseSupportsShouldProcess'
    )
    Rules = @{
        PSUseCompatibleCommands = @{
            # Target PowerShell 7.3 (current GitHub hosted runner version) and Windows PowerShell 5.1
            TargetProfiles = @('PS7.3','PS5.1-Windows')
        }
        PSAvoidUsingCmdletAliases = @{
            AllowList = @('cd', 'cp', 'mv', 'rm')
        }
    }
}
