#$DebugPreference = 'SilentlyContinue'
$DebugPreference = 'Continue'
$ErrorActionPreference = 'Stop'

$baseUrl = 'https://down.52pojie.cn/'

[Reflection.Assembly]::LoadWithPartialName("System.Web") | Out-Null

function Process-Page ([string]$url) {
    Write-Debug "Processing $url"
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
        #$href = [System.Web.HttpUtility]::UrlDecode($link.href) 
        $titleBytes = [System.Text.Encoding]::GetEncoding('latin1').GetBytes($link.title)
        $title = [System.Text.Encoding]::UTF8.GetString($titleBytes)
        return [PSCustomObject][Ordered]@{
            href = $link.href;
            title = $title;
        }
    } | ForEach-Object {
        $sublink = $PSItem
        if ($sublink.href.EndsWith('/')) {
            # 目录
            #Write-Debug "目录 $link"
            if (-not (Test-Path $sublink.title)) {
                md $sublink.title | Out-Null
            }
            Write-Output "进入目录 $($sublink.title)"
            Push-Location
            Set-Location $sublink.title
            $suburl = $url + $sublink.href
            Process-Page $suburl
            Pop-Location
        } else {
            if ($sublink.title.StartsWith('Accent')) {
                Write-Output 'debug'
            }
            # 文件
            #Write-Debug "文件 $sublink"
            if (Test-Path -PathType Leaf -LiteralPath $sublink.title) { return } # 文件已存在
            #Write-Output "下载 $($sublink.title)"
            Write-Output "下载 $($url + $sublink.href)"
            $fileResp = Invoke-WebRequest ($url + $sublink.href) -OutFile "temp.downloading"
            if ($resp.StatusCode -ne 200) { exit }
            Rename-Item "temp.downloading" $sublink.title
        }
    }
}

Push-Location
try {
    Remove-Item *.downloading -Recurse
    if (-not (Test-Path download)) { md download | Out-Null }
    Set-Location download
    Process-Page $baseUrl
} finally {
    Pop-Location
}