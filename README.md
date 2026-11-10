# Parlance

Parlance gives World of Warcraft characters ability-triggered dialogue and emotes with built-in text-to-speech. See the [in-game guide](ForeverVoice/README.txt) for installation and settings.

## Update the addon

1. Open this repository folder in VS Code. Edit the source in `ForeverVoice/` and bump `## Version` in `ForeverVoice/ForeverVoice.toc` when preparing a release.
2. Run `npm ci` once after cloning to install the test dependencies. Run `npm test` or the **Parlance: Test addon** VS Code task to check Lua syntax and addon behavior in a simulated client.
3. Press **Ctrl+Shift+B** in VS Code to build the CurseForge ZIP in `dist/`. From PowerShell, run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/package.ps1`.
4. Use VS Code's Source Control view to review and commit your changes. Upload the ZIP from `dist/` when preparing a CurseForge file submission.

The release ZIP installs to the `ForeverVoice` folder to preserve settings from previous releases. Open the addon in game with `/parlance`.
