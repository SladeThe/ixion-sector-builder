# Regenerate base64 data-URL scripts from the mirrored binaries.
$ErrorActionPreference = 'Stop'

$items = @(
    @{ File = 'index.pck'; Mime = 'application/octet-stream' },
    @{ File = 'index.wasm'; Mime = 'application/wasm' }
)

foreach ($item in $items) {
    $bytes = [IO.File]::ReadAllBytes((Join-Path $PWD $item.File))
    $data = [Convert]::ToBase64String($bytes)
    $js = 'window.__IXION_EMBED__=window.__IXION_EMBED__||{};window.__IXION_EMBED__["' +
        $item.File + '"]="data:' + $item.Mime + ';base64,' + $data + '";' + "`n"
    [IO.File]::WriteAllText((Join-Path $PWD ($item.File + '.data.js')), $js, [Text.UTF8Encoding]::new($false))
}
