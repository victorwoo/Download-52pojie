#$DebugPreference = 'SilentlyContinue'
$DebugPreference = 'Continue'

$baseUrl = 'https://down.52pojie.cn/'

function Process-Page ([string]$url) {
    Write-Debug $url
    $resp = Invoke-WebRequest $url -UseBasicParsing
    if ($resp.StatusCode -ne 200) { exit }
    $resp.Links | Where-Object {
        $link = $PSItem
        if ($link.href.StartsWith('?')) { return $false }
        if ($link.href.StartsWith('http')) { return $false }
        if ($link.href -eq '#') { return $false }
        if ($url.StartsWith($link.title)) { return $false }
        return $true
    } | ForEach-Object {
        $link = $PSItem
        $href = [System.Web.HttpUtility]::UrlDecode($link.href) 
        $titleBytes = [System.Text.Encoding]::GetEncoding('latin1').GetBytes($link.title)
        $title = [System.Text.Encoding]::UTF8.GetString($titleBytes)
        return [PSCustomObject][Ordered]@{
            href = $href;
            title = $title;
        }
    } | ForEach-Object {
        $sublink = $PSItem
        if ($sublink.href.EndsWith('/')) {
            # 目录
            Write-Debug "目录 $link"
            if (-not (Test-Path $sublink.title)) {
                md $sublink.title | Out-Null
            }
            Set-Location $sublink.title
            $suburl = $url + $sublink.href
            Process-Page $suburl
            Set-Location ..
        } else {
            # 文件
            Write-Debug "文件 $sublink"
            Invoke-WebRequest ($url + $sublink.href) -OutFile $sublink.title
        }
    }
}

Process-Page $baseUrl