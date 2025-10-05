# Contributing

Thank you for taking the time to contribute to **mcp-stacks**. This document captures the basics for keeping the repository healthy when you submit pull requests.

## PowerShell formatting and linting

We run [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) and the PowerShell formatter in CI. To reproduce the checks locally you need PowerShell 7+ (`pwsh`) and the `PSScriptAnalyzer` module.

1. Install the module if necessary:

   ```powershell
   Install-Module -Name PSScriptAnalyzer -Scope CurrentUser
   ```

2. Check formatting (fails if a file would be reformatted):

   ```powershell
   pwsh ./tools/lint.ps1 -Mode FormatCheck
   ```

3. Automatically apply formatting fixes:

   ```powershell
   pwsh ./tools/lint.ps1 -Mode FormatFix
   ```

4. Run the analyzer (prints a formatted table of diagnostics and fails only on errors):

   ```powershell
   pwsh ./tools/lint.ps1 -Mode Analyze
   ```

### Working with the warning baseline (optional)

If you want CI to fail only on new warnings, generate or refresh the baseline file before pushing:

```powershell
pwsh ./tools/lint.ps1 -Mode Analyze -UpdateWarningBaseline
```

This writes `.pssa-warning-baseline.json` in the repository root. When present, CI compares warnings to that file so that only newly introduced warnings cause failures (`./tools/lint.ps1 -Mode Analyze -FailOnNewWarnings`). Remove warnings from the code and re-run the command above to keep the baseline accurate.

## Fixing common analyzer findings

PSScriptAnalyzer enforces a curated set of rules. Some common findings and their fixes include:

- **Avoid `Invoke-Expression`** (`PSAvoidUsingInvokeExpression`): refactor to use splatting or `&` with explicit command arguments.
- **Add `ShouldProcess` support** (`PSUseSupportsShouldProcess`): decorate advanced functions that mutate state with `[CmdletBinding(SupportsShouldProcess)]` and wrap operations inside `if ($PSCmdlet.ShouldProcess(...))`.
- **Avoid empty catch blocks** (`PSAvoidUsingEmptyCatchBlock`): handle the exception explicitly, log, or rethrow via `throw`.
- **Prefer approved verbs and singular nouns** (`PSUseApprovedVerbs`, `PSUseSingularNouns`): adjust function names to use standard PowerShell verb-noun patterns.
- **Declare and use variables deliberately** (`PSUseDeclaredVarsMoreThanAssignments`): remove unused variables or use them meaningfully.
- **Document functions** (`PSProvideCommentHelp`): add comment-based help for public functions and scripts.

Run the analyzer after applying fixes to ensure the issue is resolved.
