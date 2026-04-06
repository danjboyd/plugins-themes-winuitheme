# Screenshot Corpus

The screenshot corpus is organized by harness:

- `ThemeDemo/<variant>/<page>.png`
- `Reference/default/<page>.png`
- `ObjcMarkdown/objcmarkdown-main-window.png`

Use these scripts to regenerate the corpus:

- `powershell -ExecutionPolicy Bypass -File Tests/Scripts/Invoke-ThemeAcceptanceMatrix.ps1`
- `powershell -ExecutionPolicy Bypass -File Tests/Scripts/Invoke-ObjcMarkdownValidation.ps1 -Build -RunTests`

The capture manifest is written to `Tests/Screenshots/acceptance-manifest.json`.
