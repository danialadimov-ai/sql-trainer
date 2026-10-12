$root = $PSScriptRoot
$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 8585)
$listener.Start()
Write-Host 'Server: http://localhost:8585/'
$mime = @{ '.html'='text/html; charset=utf-8'; '.js'='text/javascript; charset=utf-8'; '.css'='text/css; charset=utf-8' }
while ($true) {
    $client = $listener.AcceptTcpClient()
    try {
        $client.ReceiveTimeout = 5000
        $client.SendTimeout = 5000
        $client.NoDelay = $true
        $stream = $client.GetStream()
        $buf = New-Object byte[] 8192
        $req = ''
        try {
            while ($req -notmatch "`r`n`r`n") {
                $n = $stream.Read($buf, 0, 8192)
                if ($n -le 0) { break }
                $req += [System.Text.Encoding]::ASCII.GetString($buf, 0, $n)
            }
        } catch [System.IO.IOException] {}
        $path = ''
        if ($req -match '(?m)^GET\s+([^\s?]+)') { $path = [System.Uri]::UnescapeDataString($Matches[1]).TrimStart('/') }
        if ([string]::IsNullOrEmpty($path)) { $path = 'sql-trainer.html' }
        $file = Join-Path $root $path
        if ($req -match '(?m)^GET\s' -and (Test-Path $file -PathType Leaf) -and $path -notmatch '\.\.') {
            $bytes = [System.IO.File]::ReadAllBytes($file)
            $ctype = $mime[[System.IO.Path]::GetExtension($file)]
            if (-not $ctype) { $ctype = 'application/octet-stream' }
            $head = [System.Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 OK`r`nContent-Type: $ctype`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`n`r`n")
            $stream.Write($head, 0, $head.Length)
            $stream.Write($bytes, 0, $bytes.Length)
        } else {
            $head = [System.Text.Encoding]::ASCII.GetBytes("HTTP/1.1 404 Not Found`r`nContent-Length: 0`r`nConnection: close`r`n`r`n")
            $stream.Write($head, 0, $head.Length)
        }
        $stream.Flush()
    } catch {}
    try { $client.Close() } catch {}
}
