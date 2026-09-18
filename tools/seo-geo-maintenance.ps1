param(
  [string]$BaseUrl = "https://shacmantruck-export.com",
  [switch]$Write
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$base = $BaseUrl.TrimEnd("/")
$today = Get-Date -Format "yyyy-MM-dd"
$sitemapPath = Join-Path $root "sitemap.xml"
$sitemapCurrent = if (Test-Path $sitemapPath) { Get-Content -LiteralPath $sitemapPath -Raw -Encoding UTF8 } else { "" }
$existingLastmod = @{}
foreach ($entry in [regex]::Matches($sitemapCurrent, '<url>\s*<loc>([^<]+)</loc>\s*<lastmod>([^<]+)</lastmod>\s*</url>')) {
  $existingLastmod[$entry.Groups[1].Value] = $entry.Groups[2].Value
}

function Match-One {
  param([string]$Text, [string]$Pattern)
  $m = [regex]::Match($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if ($m.Success) { return $m.Groups[1].Value.Trim() }
  return ""
}

function Strip-Tags {
  param([string]$Text)
  return ([regex]::Replace($Text, "<[^>]+>", " ") -replace "\s+", " ").Trim()
}

function Normalize-Text {
  param([string]$Text)
  return (($Text -replace "`r`n", "`n").TrimEnd())
}

function Page-Url {
  param([string]$Name)
  if ($Name -eq "index.html") { return "$base/" }
  return "$base/$Name"
}

function Build-Sitemap {
  param($Pages)
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add('<?xml version="1.0" encoding="UTF-8"?>')
  $lines.Add('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">')
  foreach ($page in $Pages) {
    $lines.Add("  <url><loc>$($page.Url)</loc><lastmod>$($page.Lastmod)</lastmod></url>")
  }
  $lines.Add('</urlset>')
  return ($lines -join "`r`n") + "`r`n"
}

function Build-Llms-Block {
  param($Pages)
  $news = $Pages | Where-Object { $_.Name -like "news-*.html" } | Sort-Object Lastmod, Name -Descending | Select-Object -First 35
  $products = $Pages | Where-Object {
    $_.Name -match "^(shacman|sagmoto)-" -and $_.Name -notmatch "-zh\.html$"
  } | Sort-Object Name

  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("<!-- AUTO-SEO-GEO-START -->")
  $lines.Add("## Auto SEO/GEO index")
  $lines.Add("Generated: $today")
  $lines.Add("Indexable HTML pages: $($Pages.Count)")
  $lines.Add("")
  $lines.Add("### Priority product and quotation pages")
  foreach ($page in $products) {
    $lines.Add("- $($page.Title): $($page.Url)")
  }
  $lines.Add("- Request a configuration quotation: $base/request-quote.html")
  $lines.Add("- Contact Andy, Sales Manager: $base/contact-us.html")
  $lines.Add("")
  $lines.Add("### Recent truck export news and buying guides")
  foreach ($page in $news) {
    $lines.Add("- $($page.Title): $($page.Url)")
  }
  $lines.Add("<!-- AUTO-SEO-GEO-END -->")
  return ($lines -join "`r`n") + "`r`n"
}

function Update-Llms {
  param([string]$Block)
  $path = Join-Path $root "llms.txt"
  $current = ""
  if (Test-Path $path) { $current = Get-Content -LiteralPath $path -Raw -Encoding UTF8 }
  $pattern = "(?s)<!-- AUTO-SEO-GEO-START -->.*?<!-- AUTO-SEO-GEO-END -->\s*"
  if ([regex]::IsMatch($current, $pattern)) {
    return [regex]::Replace($current, $pattern, $Block)
  }
  return $current.TrimEnd() + "`r`n`r`n" + $Block
}

$htmlFiles = Get-ChildItem -LiteralPath $root -File -Filter "*.html" |
  Where-Object { $_.Name -notmatch "^google[a-z0-9]+\.html$" } |
  Sort-Object Name

$pages = New-Object System.Collections.Generic.List[object]
$warnings = New-Object System.Collections.Generic.List[string]
$errors = New-Object System.Collections.Generic.List[string]

foreach ($file in $htmlFiles) {
  $html = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
  $robots = Match-One $html '<meta\s+name=["'']robots["'']\s+content=["'']([^"'']+)["'']'
  $isIndexable = $robots -notmatch "(^|,)\s*noindex"
  $title = Strip-Tags (Match-One $html "<title>([\s\S]*?)</title>")
  $description = Match-One $html '<meta\s+name=["'']description["'']\s+content=["'']([^"'']*)["'']'
  $canonical = Match-One $html '<link\s+rel=["'']canonical["'']\s+href=["'']([^"'']+)["'']'
  $h1Count = [regex]::Matches($html, "<h1\b", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase).Count
  $imgWithoutAlt = [regex]::Matches($html, "<img\b(?![^>]*\salt=)", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase).Count

  if ($isIndexable) {
    if ($title.Length -lt 20 -or $title.Length -gt 70) { $warnings.Add("$($file.Name): title length is $($title.Length).") }
    if ($description.Length -lt 70 -or $description.Length -gt 170) { $warnings.Add("$($file.Name): meta description length is $($description.Length).") }
    if ($h1Count -ne 1) { $warnings.Add("$($file.Name): H1 count is $h1Count.") }
    if ($imgWithoutAlt -gt 0) { $warnings.Add("$($file.Name): $imgWithoutAlt image(s) missing alt text.") }
    if (-not $canonical) {
      $warnings.Add("$($file.Name): missing canonical link.")
    } elseif ($canonical -notlike "$base*") {
      $warnings.Add("$($file.Name): canonical is outside the target domain: $canonical")
    }
  }

  $jsonBlocks = [regex]::Matches($html, '<script[^>]+type=["'']application/ld\+json["''][^>]*>([\s\S]*?)</script>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  foreach ($block in $jsonBlocks) {
    try {
      $null = $block.Groups[1].Value | ConvertFrom-Json -ErrorAction Stop
    } catch {
      $errors.Add("$($file.Name): invalid JSON-LD - $($_.Exception.Message)")
    }
  }

  $assetRefs = [regex]::Matches($html, '(?:href|src)=["'']([^"'']+)["'']', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  foreach ($ref in $assetRefs) {
    $url = $ref.Groups[1].Value
    if ($url -match "^(https?:|mailto:|tel:|#|javascript:)" -or $url -eq "") { continue }
    $path = (($url -split "#")[0] -split "\?")[0]
    if ($path -eq "" -or $path -match "^#") { continue }
    if ($path.StartsWith("/")) {
      $local = Join-Path $root $path.TrimStart("/")
    } else {
      $local = Join-Path $root $path
    }
    if (-not (Test-Path $local)) { $errors.Add("$($file.Name): missing local link or asset $path") }
  }

  if ($isIndexable) {
    $pageUrl = Page-Url $file.Name
    $modified = Match-One $html '<meta\s+property=["'']article:modified_time["'']\s+content=["'']([^"'']+)["'']'
    $modifiedDate = if ($modified -match '^\d{4}-\d{2}-\d{2}') { $matches[0] } else { "" }
    if ($existingLastmod.ContainsKey($pageUrl)) {
      $lastmod = $existingLastmod[$pageUrl]
      if ($modifiedDate -and $modifiedDate -gt $lastmod) { $lastmod = $modifiedDate }
    } elseif ($modifiedDate) {
      $lastmod = $modifiedDate
    } else {
      $lastmod = $today
    }
    $pages.Add([pscustomobject]@{
      Name = $file.Name
      Url = $pageUrl
      Lastmod = $lastmod
      Title = if ($title) { $title } else { $file.BaseName }
    })
  }
}

$pages = @($pages | Sort-Object @{Expression={ if ($_.Name -eq "index.html") { "0000" } else { $_.Name } }})
$sitemapNew = Build-Sitemap $pages
$llmsNew = Update-Llms (Build-Llms-Block $pages)

$llmsPath = Join-Path $root "llms.txt"
$llmsCurrent = if (Test-Path $llmsPath) { Get-Content -LiteralPath $llmsPath -Raw -Encoding UTF8 } else { "" }

if ($Write) {
  Set-Content -LiteralPath $sitemapPath -Value $sitemapNew -Encoding utf8 -NoNewline
  Set-Content -LiteralPath $llmsPath -Value $llmsNew -Encoding utf8 -NoNewline
} else {
  if ((Normalize-Text $sitemapCurrent) -ne (Normalize-Text $sitemapNew)) { $errors.Add("sitemap.xml is not synchronized. Run tools/seo-geo-maintenance.ps1 -Write.") }
  if ((Normalize-Text $llmsCurrent) -ne (Normalize-Text $llmsNew)) { $errors.Add("llms.txt is not synchronized. Run tools/seo-geo-maintenance.ps1 -Write.") }
}

$reportDir = Join-Path $root "seo-reports"
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
$newUrlsPath = Join-Path $reportDir "gsc-urls-to-inspect.txt"
$newNews = $pages | Where-Object { $_.Name -like "news-*.html" } | Sort-Object Lastmod, Name -Descending | Select-Object -First 30
$newUrls = (($newNews | ForEach-Object { $_.Url }) -join "`r`n") + "`r`n"
$currentUrls = if (Test-Path $newUrlsPath) { Get-Content -LiteralPath $newUrlsPath -Raw -Encoding UTF8 } else { "" }
if ($Write) {
  Set-Content -LiteralPath $newUrlsPath -Value $newUrls -Encoding utf8 -NoNewline
} elseif ((Normalize-Text $currentUrls) -ne (Normalize-Text $newUrls)) {
  $errors.Add("seo-reports/gsc-urls-to-inspect.txt is not synchronized. Run tools/seo-geo-maintenance.ps1 -Write.")
}

Write-Host "SEO/GEO maintenance report"
Write-Host "Indexable pages: $($pages.Count)"
Write-Host "GSC URL inspection list: seo-reports/gsc-urls-to-inspect.txt"
if ($warnings.Count -gt 0) {
  Write-Host ""
  Write-Host "Warnings:"
  $warnings | ForEach-Object { Write-Host "- $_" }
}
if ($errors.Count -gt 0) {
  Write-Host ""
  Write-Host "Errors:"
  $errors | ForEach-Object { Write-Host "- $_" }
  exit 1
}
Write-Host "SEO/GEO checks passed."
