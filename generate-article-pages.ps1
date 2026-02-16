$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$articlesPath = Join-Path $repoRoot 'data\articles.json'
$cnamePath = Join-Path $repoRoot 'CNAME'
$outputRoot = Join-Path $repoRoot 'articles'

$baseHost = $null
if (Test-Path $cnamePath) {
    $baseHost = (Get-Content -Path $cnamePath -Raw).Trim()
}

if ([string]::IsNullOrWhiteSpace($baseHost)) {
    $baseHost = 'pcupgradeadvisor.com'
}

$baseUrl = "https://$baseHost"

if (-not (Test-Path $articlesPath)) {
    throw "Missing articles JSON: $articlesPath"
}

$articles = Get-Content -Path $articlesPath -Raw | ConvertFrom-Json
if ($null -eq $articles) {
    throw 'No articles found.'
}

if (-not (Test-Path $outputRoot)) {
    New-Item -ItemType Directory -Path $outputRoot | Out-Null
}

$usedSlugs = @{}

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

function Get-UniqueSlug {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Slug
    )

    $candidate = $Slug
    $counter = 2
    while ($usedSlugs.ContainsKey($candidate)) {
        $candidate = "$Slug-$counter"
        $counter++
    }

    $usedSlugs[$candidate] = $true
    return $candidate
}

foreach ($article in $articles) {
    $slug = Get-Slug -Article $article
    if ([string]::IsNullOrWhiteSpace($slug)) {
        Write-Warning "Skipping article with missing slug/title/id."
        continue
    }

    $slug = Get-UniqueSlug -Slug $slug
    $articleDir = Join-Path $outputRoot $slug
    if (-not (Test-Path $articleDir)) {
        New-Item -ItemType Directory -Path $articleDir | Out-Null
    }

    $title = [System.Net.WebUtility]::HtmlEncode($article.title)
    $excerpt = [System.Net.WebUtility]::HtmlEncode($article.excerpt)
    $contentHtml = $article.content

    $dateDisplay = $null
    if (-not [string]::IsNullOrWhiteSpace($article.date)) {
        $dateValue = [DateTime]::Parse($article.date, [Globalization.CultureInfo]::InvariantCulture)
        $dateDisplay = $dateValue.ToString('MMMM d, yyyy', [Globalization.CultureInfo]::GetCultureInfo('en-US'))
    } else {
        $dateDisplay = (Get-Date).ToString('MMMM d, yyyy', [Globalization.CultureInfo]::GetCultureInfo('en-US'))
    }

    $metaParts = @($dateDisplay)
    if (-not [string]::IsNullOrWhiteSpace($article.author)) {
        $metaParts += "By $([System.Net.WebUtility]::HtmlEncode($article.author))"
    }
    if ($article.readTime) {
        $metaParts += "$($article.readTime) min read"
    }
    $metaText = ($metaParts -join ' • ')

    $tagsHtml = ''
    if ($article.tags -and $article.tags.Count -gt 0) {
        $tagItems = @()
        foreach ($tag in $article.tags) {
            $tagItems += "<span class='article-tag'>$([System.Net.WebUtility]::HtmlEncode($tag))</span>"
        }
        $tagsHtml = "<div class='article-tags'>$($tagItems -join '')</div>"
    }

    $canonicalUrl = "$baseUrl/articles/$slug/"

    $html = @"
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width,initial-scale=1" />
    <title>$title - PC Upgrade Advisor</title>
    <meta name="description" content="$excerpt" />
    <link rel="canonical" href="$canonicalUrl" />
    <link rel="stylesheet" href="../../style.css" />
    <style>
        .article-container {
            max-width: 900px;
            margin: 0 auto;
            padding: 2rem;
        }

        .article-meta {
            display: flex;
            flex-wrap: wrap;
            gap: 1rem;
            font-size: 0.875rem;
            color: var(--text-secondary, #666);
            margin-bottom: 0.75rem;
        }

        .article-tags {
            display: flex;
            flex-wrap: wrap;
            gap: 0.5rem;
            margin-top: 1rem;
            margin-bottom: 1rem;
        }

        .article-tag {
            background: var(--tag-bg, #e3f2fd);
            color: var(--primary-color, #2196F3);
            padding: 0.25rem 0.75rem;
            border-radius: 12px;
            font-size: 0.875rem;
        }

        .article-full {
            background: var(--card-bg, #fff);
            border: 1px solid var(--border-color, #e0e0e0);
            border-radius: 8px;
            padding: 2rem;
            margin-bottom: 2rem;
        }

        .article-full h1 {
            font-size: 2rem;
            margin-bottom: 1rem;
        }

        .article-content {
            line-height: 1.8;
            color: var(--text-color, #333);
        }

        .article-content h2 {
            font-size: 1.5rem;
            margin-top: 2rem;
            margin-bottom: 1rem;
        }

        .article-content h3 {
            font-size: 1.25rem;
            margin-top: 1.5rem;
            margin-bottom: 0.75rem;
        }

        .article-content p {
            margin-bottom: 1rem;
        }

        .article-content ul, .article-content ol {
            margin-bottom: 1rem;
            padding-left: 2rem;
        }

        .article-content li {
            margin-bottom: 0.5rem;
        }

        .nav-links {
            display: flex;
            flex-wrap: wrap;
            gap: 1rem;
            margin-bottom: 2rem;
        }

        .nav-links a {
            color: var(--primary-color, #2196F3);
            text-decoration: none;
            font-weight: 600;
        }

        .nav-links a:hover {
            text-decoration: underline;
        }

        body.dark-mode {
            --card-bg: #2d2d2d;
            --border-color: #444;
            --text-color: #e0e0e0;
            --text-secondary: #999;
            --tag-bg: #1e3a5f;
        }
    </style>
</head>
<body>
    <header>
        <div class="header-content">
            <h1>PC Upgrade Articles</h1>
            <p>Expert guides and insights for optimizing your PC</p>
        </div>
        <button id="themeToggle" class="theme-toggle" title="Toggle dark mode">🌙</button>
    </header>

    <main class="article-container">
        <div class="nav-links">
            <a href="../../articles.html">← Back to Articles</a>
            <a href="../../index.html">Upgrade Recommendation →</a>
        </div>

        <article class="article-full">
            <div class="article-meta">
                <span>$metaText</span>
            </div>
            <h1>$title</h1>
            $tagsHtml
            <div class="article-content">
                $contentHtml
            </div>
        </article>
    </main>

    <script>
        const themeToggle = document.getElementById('themeToggle');
        const body = document.body;

        if (localStorage.getItem('darkMode') === 'enabled') {
            body.classList.add('dark-mode');
            themeToggle.textContent = '☀️';
        }

        themeToggle.addEventListener('click', () => {
            body.classList.toggle('dark-mode');
            if (body.classList.contains('dark-mode')) {
                localStorage.setItem('darkMode', 'enabled');
                themeToggle.textContent = '☀️';
            } else {
                localStorage.setItem('darkMode', 'disabled');
                themeToggle.textContent = '🌙';
            }
        });
    </script>
</body>
</html>
"@

    $outFile = Join-Path $articleDir 'index.html'
    Set-Content -Path $outFile -Value $html -Encoding utf8
}

Write-Host "Article pages generated under: $outputRoot"
