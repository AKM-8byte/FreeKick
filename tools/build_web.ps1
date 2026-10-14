param([string]$GodotPath = "")
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $GodotPath) { $GodotPath = Join-Path $projectRoot '.tools/Godot_v4.7.2-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Godot bulunamadı. -GodotPath ile Godot 4.7.2 yolunu belirtin.' }
$GodotPath = (Resolve-Path -LiteralPath $GodotPath).Path
$version = (& $GodotPath --version | Out-String).Trim()
if ($version -notlike '4.7.2.stable*') { throw "Bu preset Godot 4.7.2 ile doğrulandı; bulunan sürüm: $version" }

# Portable editor copies only the Web templates, never changes Windows presets.
$portableMarker = Join-Path ([IO.Path]::GetDirectoryName($GodotPath)) '_sc_'
if (Test-Path -LiteralPath $portableMarker) {
    $templateFolder = Join-Path ([IO.Path]::GetDirectoryName($GodotPath)) 'editor_data/export_templates/4.7.2.stable'
    foreach ($name in @('web_nothreads_debug.zip', 'web_nothreads_release.zip')) {
        $target = Join-Path $templateFolder $name
        if (-not (Test-Path -LiteralPath $target)) {
            $installed = Join-Path $env:APPDATA "Godot/export_templates/4.7.2.stable/$name"
            if (-not (Test-Path -LiteralPath $installed)) { throw "Export şablonu eksik: $name. Godot 4.7.2 Export Templates kurun." }
            New-Item -ItemType Directory -Path $templateFolder -Force | Out-Null
            Copy-Item -LiteralPath $installed -Destination $target
        }
    }
}

$stage = Join-Path $projectRoot ('.tools/web-stage-' + [Guid]::NewGuid().ToString('N'))
$output = Join-Path $projectRoot 'build/web'
$archive = Join-Path $projectRoot 'build/FreeKick-Web.zip'
$log = Join-Path $projectRoot '.tools/web-export.log'
$previousAppData = $env:APPDATA
New-Item -ItemType Directory -Path (Join-Path $projectRoot 'build') -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $projectRoot 'build/.gdignore'), '')
New-Item -ItemType Directory -Path $stage -Force | Out-Null
try {
    $env:APPDATA = Join-Path $projectRoot '.tools/profile'
    & $GodotPath --headless --editor --path $projectRoot --import *> $log
    if ($LASTEXITCODE -ne 0) { throw "Import başarısız. Günlük: $log" }
    & $GodotPath --headless --path $projectRoot --export-release Web (Join-Path $stage 'index.html') *>> $log
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR:|^ERROR:' -Quiet)) {
        throw "Web export başarısız. ZIP hazırlanmadı. Günlük: $log"
    }
    foreach ($name in @('index.html','index.js','index.wasm','index.pck')) {
        $file = Join-Path $stage $name
        if (-not (Test-Path -LiteralPath $file) -or (Get-Item -LiteralPath $file).Length -eq 0) { throw "Export dosyası eksik: $name" }
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    New-Item -ItemType Directory -Path $output -Force | Out-Null
    # ZIP is created outside the source folder, with index.html at its root.
    $temporaryZip = Join-Path $projectRoot ('.tools/web-' + [Guid]::NewGuid().ToString('N') + '.zip')
    [IO.Compression.ZipFile]::CreateFromDirectory($stage, $temporaryZip, [IO.Compression.CompressionLevel]::Optimal, $false)
    foreach ($file in Get-ChildItem -LiteralPath $stage -File) { Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $output $file.Name) -Force }
    Move-Item -LiteralPath $temporaryZip -Destination $archive -Force
    Write-Output "Web hazır: $archive ($([Math]::Round((Get-Item -LiteralPath $archive).Length / 1MB, 2)) MiB)"
} finally {
    $env:APPDATA = $previousAppData
    # Delete only this invocation's generated staging directory inside .tools.
    $allowedRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '.tools')) + [IO.Path]::DirectorySeparatorChar
    if ([IO.Path]::GetFullPath($stage).StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $stage -Recurse -Force
    }
}
