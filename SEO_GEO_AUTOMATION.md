# SHACMAN SEO/GEO Automation Workflow

Use this workflow after publishing new pages or News articles.

## 1. Run The Local SEO/GEO Maintenance

```powershell
powershell -ExecutionPolicy Bypass -File tools/seo-geo-maintenance.ps1 -Write
```

This updates:

- `sitemap.xml`
- `llms.txt`
- `seo-reports/gsc-urls-to-inspect.txt`

It also checks:

- title and meta description presence and length
- canonical domain
- H1 count
- JSON-LD validity
- missing local links and images
- image `alt` coverage
- indexable page list

## 2. Commit And Push

```powershell
git add -A
git commit -m "Publish SEO/GEO content updates"
git push origin main
```

## 3. Google Search Console Tasks

In Google Search Console for `https://shacmantruck-export.com/`:

1. Open **Sitemaps** and submit:

```text
https://shacmantruck-export.com/sitemap.xml
```

2. Open **URL Inspection** and inspect the priority URLs listed in:

```text
seo-reports/gsc-urls-to-inspect.txt
```

3. For important new product pages or News pages, use **Request indexing** after confirming the page is live.

4. Check **Pages**, **Sitemaps**, **Manual actions**, **Security issues**, **Core Web Vitals** and **Search results** every week.

## 4. Important Google Indexing Note

Do not use Google Indexing API for normal truck product pages or News articles. Google officially limits the Indexing API to pages with `JobPosting` or livestream `BroadcastEvent` inside `VideoObject`. For this site, the correct path is sitemap submission, clean internal links, structured data, and URL Inspection for priority pages.

## 5. Ranking Focus

The site should prioritize pages that match commercial searches:

- `SHACMAN dump truck price`
- `SHACMAN F3000 dump truck`
- `SHACMAN X3000 tractor truck`
- `SHACMAN fuel tanker truck`
- `SHACMAN water tanker truck`
- `SHACMAN concrete mixer truck`
- `SHACMAN cargo truck`
- `SAGMOTO X1s 6x4 dump truck`
- `SAGMOTO X1s 8x4 dump truck`

Each article should link to a product page and the quotation page.
