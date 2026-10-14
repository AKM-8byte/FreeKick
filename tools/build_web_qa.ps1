param([string]$GodotPath = "", [string]$ScenePath = 'res://tests/web_parity_scene.tscn')
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $GodotPath) { $GodotPath = Join-Path $projectRoot '.tools/Godot_v4.7.2-stable_win64_console.exe' }
$presetPath = Join-Path $projectRoot 'export_presets.cfg'
$projectPath = Join-Path $projectRoot 'project.godot'
$presets = [IO.File]::ReadAllBytes($presetPath)
$project = [IO.File]::ReadAllBytes($projectPath)
$previousAppData = $env:APPDATA
try {
    # QA only: ship neither this scene nor any tests in FreeKick-Web.zip.
    $qaConfig = [IO.File]::ReadAllText($presetPath).Replace('tests/*,tools/*', 'tools/*')
    [IO.File]::WriteAllText($presetPath, $qaConfig, [Text.UTF8Encoding]::new($false))
    $qaProject = [IO.File]::ReadAllText($projectPath)
    $qaProject = [regex]::Replace($qaProject, 'run/main_scene="[^"]+"', ('run/main_scene="' + $ScenePath + '"'))
    [IO.File]::WriteAllText($projectPath, $qaProject, [Text.UTF8Encoding]::new($false))
    $env:APPDATA = Join-Path $projectRoot '.tools/profile'
    New-Item -ItemType Directory -Path (Join-Path $projectRoot 'build/web-qa') -Force | Out-Null
    & $GodotPath --headless --path $projectRoot --export-release Web (Join-Path $projectRoot 'build/web-qa/index.html') *> (Join-Path $projectRoot '.tools/web-qa-export.log')
    if ($LASTEXITCODE -ne 0) { throw 'QA export başarısız; .tools/web-qa-export.log dosyasını inceleyin.' }
} finally {
    [IO.File]::WriteAllBytes($presetPath, $presets)
    [IO.File]::WriteAllBytes($projectPath, $project)
    $env:APPDATA = $previousAppData
}
