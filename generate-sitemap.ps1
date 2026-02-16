$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$articlesPath = Join-Path $repoRoot 'data\articles.json'
$cnamePath = Join-Path $repoRoot 'CNAME'
$outPath = Join-Path $repoRoot 'sitemap.xml'

$baseHost = $null
if (Test-Path $cnamePath) {
    $baseHost = (Get-Content -Path $cnamePath -Raw).Trim()
}

if ([string]::IsNullOrWhiteSpace($baseHost)) {
    $baseHost = 'pcupgradeadvisor.com'
}

$baseUrl = "https://$baseHost"

$articles = @()
if (Test-Path $articlesPath) {
    $articles = Get-Content -Path $articlesPath -Raw | ConvertFrom-Json
}

$urls = @(
    @{ loc = "$baseUrl/"; lastmod = (Get-Date).ToString('yyyy-MM-dd'); priority = '1.0' },
    @{ loc = "$baseUrl/articles.html"; lastmod = (Get-Date).ToString('yyyy-MM-dd'); priority = '0.8' }
)

function Get-Slug {
    param(
        [Parameter(Mandatory = $true)]
        $Article
    )

    if ($null -ne $Article.slug -and $Article.slug.ToString().Length -gt 0) {
        return $Article.slug.ToString()
    }

    $source = $Article.title
    if ([string]::IsNullOrWhiteSpace($source)) {
        $source = $Article.id
    }

    if ([string]::IsNullOrWhiteSpace($source)) {
        return $null
    }

    $slug = $source.ToLowerInvariant()
    $slug = $slug -replace '[^a-z0-9]+', '-'
    $slug = $slug -replace '(^-+|-+$)', ''
    return $slug
}

foreach ($article in $articles) {
    $slug = Get-Slug -Article $article
    if ($null -ne $slug -and $slug.ToString().Length -gt 0) {
        $lastMod = $article.date
        if ([string]::IsNullOrWhiteSpace($lastMod)) {
            $lastMod = (Get-Date).ToString('yyyy-MM-dd')
        }
        $urls += @{ loc = "$baseUrl/articles/$slug/"; lastmod = $lastMod; priority = '0.8' }
    }
}

$xml = New-Object System.Xml.XmlDocument
$xmlDeclaration = $xml.CreateXmlDeclaration('1.0', 'UTF-8', $null)
$xml.AppendChild($xmlDeclaration) | Out-Null

$urlset = $xml.CreateElement('urlset')
$urlset.SetAttribute('xmlns', 'http://www.sitemaps.org/schemas/sitemap/0.9')
$xml.AppendChild($urlset) | Out-Null

foreach ($entry in $urls) {
    $urlNode = $xml.CreateElement('url')

    $locNode = $xml.CreateElement('loc')
    $locNode.InnerText = $entry.loc
    $urlNode.AppendChild($locNode) | Out-Null

    $lastmodNode = $xml.CreateElement('lastmod')
    $lastmodNode.InnerText = $entry.lastmod
    $urlNode.AppendChild($lastmodNode) | Out-Null

    if ($entry.ContainsKey('priority')) {
        $priorityNode = $xml.CreateElement('priority')
        $priorityNode.InnerText = $entry.priority
        $urlNode.AppendChild($priorityNode) | Out-Null
    }

    $urlset.AppendChild($urlNode) | Out-Null
}

$xml.Save($outPath)
Write-Host "Sitemap updated: $outPath"
