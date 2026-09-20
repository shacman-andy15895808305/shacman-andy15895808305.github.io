import fs from "node:fs";
import path from "node:path";
import { GoogleAuth } from "google-auth-library";

const siteUrl = process.env.GSC_SITE_URL || "https://shacmantruck-export.com/";
const sitemapUrl = new URL("sitemap.xml", siteUrl).href;
const inspectionLimit = Number.parseInt(process.env.GSC_INSPECTION_LIMIT || "30", 10);
const outputDir = path.resolve(process.env.GSC_OUTPUT_DIR || "gsc-output");
const credentialsJson = process.env.GSC_SERVICE_ACCOUNT_JSON;

if (!credentialsJson) {
  throw new Error("GSC_SERVICE_ACCOUNT_JSON is not configured in GitHub Actions secrets.");
}

let credentials;
try {
  credentials = JSON.parse(credentialsJson);
} catch {
  throw new Error("GSC_SERVICE_ACCOUNT_JSON is not valid JSON.");
}

const auth = new GoogleAuth({
  credentials,
  scopes: ["https://www.googleapis.com/auth/webmasters"],
});
const client = await auth.getClient();

function apiUrl(base, ...parts) {
  return `${base}/${parts.map((part) => encodeURIComponent(part)).join("/")}`;
}

async function submitSitemap() {
  const url = apiUrl("https://www.googleapis.com/webmasters/v3/sites", siteUrl, "sitemaps", sitemapUrl);
  await client.request({ url, method: "PUT" });
  return { submitted: true, sitemapUrl };
}

async function inspectUrl(inspectionUrl) {
  const response = await client.request({
    url: "https://searchconsole.googleapis.com/v1/urlInspection/index:inspect",
    method: "POST",
    data: { inspectionUrl, siteUrl, languageCode: "en-US" },
  });
  const result = response.data?.inspectionResult || {};
  const index = result.indexStatusResult || {};
  return {
    url: inspectionUrl,
    verdict: index.verdict || "UNKNOWN",
    coverageState: index.coverageState || "Unknown",
    robotsTxtState: index.robotsTxtState || "Unknown",
    indexingState: index.indexingState || "Unknown",
    pageFetchState: index.pageFetchState || "Unknown",
    googleCanonical: index.googleCanonical || "",
    userCanonical: index.userCanonical || "",
    lastCrawlTime: index.lastCrawlTime || "",
  };
}

function isoDate(daysAgo) {
  const date = new Date();
  date.setUTCDate(date.getUTCDate() - daysAgo);
  return date.toISOString().slice(0, 10);
}

async function querySearchAnalytics(dimensions = [], rowLimit = 25) {
  const url = apiUrl("https://www.googleapis.com/webmasters/v3/sites", siteUrl, "searchAnalytics", "query");
  const response = await client.request({
    url,
    method: "POST",
    data: {
      startDate: isoDate(30),
      endDate: isoDate(3),
      dimensions,
      rowLimit,
      dataState: "final",
    },
  });
  return response.data?.rows || [];
}

function readInspectionUrls() {
  const preferredPath = path.resolve("seo-reports/gsc-urls-to-inspect.txt");
  if (fs.existsSync(preferredPath)) {
    return fs
      .readFileSync(preferredPath, "utf8")
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter((line) => line.startsWith(siteUrl));
  }

  const sitemap = fs.readFileSync(path.resolve("sitemap.xml"), "utf8");
  return [...sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map((match) => match[1]);
}

function formatNumber(value, digits = 0) {
  return Number(value || 0).toLocaleString("en-US", {
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  });
}

function analyticsTable(rows, label) {
  const lines = [`| ${label} | Clicks | Impressions | CTR | Position |`, "|---|---:|---:|---:|---:|"];
  for (const row of rows.slice(0, 15)) {
    const key = String(row.keys?.[0] || "(not provided)").replaceAll("|", "\\|");
    lines.push(`| ${key} | ${formatNumber(row.clicks)} | ${formatNumber(row.impressions)} | ${formatNumber((row.ctr || 0) * 100, 1)}% | ${formatNumber(row.position, 1)} |`);
  }
  if (rows.length === 0) lines.push("| No final data returned | 0 | 0 | 0% | 0 | ");
  return lines.join("\n");
}

function buildMarkdown(report) {
  const totals = report.analytics.totals[0] || {};
  const indexed = report.inspections.filter((item) => item.verdict === "PASS").length;
  const needsAttention = report.inspections.length - indexed;
  const lines = [
    "# SHACMAN Google Search Console automation report",
    "",
    `Generated: ${report.generatedAt}`,
    `Property: ${siteUrl}`,
    `Sitemap submitted: ${report.sitemap.submitted ? "Yes" : "No"}`,
    "",
    "## 28-day search performance",
    "",
    `- Clicks: ${formatNumber(totals.clicks)}`,
    `- Impressions: ${formatNumber(totals.impressions)}`,
    `- CTR: ${formatNumber((totals.ctr || 0) * 100, 1)}%`,
    `- Average position: ${formatNumber(totals.position, 1)}`,
    "",
    "## Priority URL inspection",
    "",
    `- Checked: ${report.inspections.length}`,
    `- Indexed/pass: ${indexed}`,
    `- Needs attention: ${needsAttention}`,
    "",
    "| URL | Verdict | Coverage | Last crawl |",
    "|---|---|---|---|",
  ];

  for (const item of report.inspections) {
    lines.push(`| ${item.url} | ${item.verdict} | ${item.coverageState.replaceAll("|", "\\|")} | ${item.lastCrawlTime || "-"} |`);
  }

  lines.push(
    "",
    "## Top queries",
    "",
    analyticsTable(report.analytics.queries, "Query"),
    "",
    "## Top pages",
    "",
    analyticsTable(report.analytics.pages, "Page"),
    "",
    "## Top countries",
    "",
    analyticsTable(report.analytics.countries, "Country"),
    "",
    "> Note: The URL Inspection API reports Google's indexed version. It cannot run a live test or automatically request indexing for normal product and News pages.",
    ""
  );
  return lines.join("\n");
}

fs.mkdirSync(outputDir, { recursive: true });

const sitemap = await submitSitemap();
const urls = [...new Set(readInspectionUrls())].slice(0, inspectionLimit);
const inspections = [];
for (const url of urls) {
  try {
    inspections.push(await inspectUrl(url));
  } catch (error) {
    inspections.push({
      url,
      verdict: "ERROR",
      coverageState: error.response?.data?.error?.message || error.message,
      lastCrawlTime: "",
    });
  }
}

const [totals, queries, pages, countries] = await Promise.all([
  querySearchAnalytics([], 1),
  querySearchAnalytics(["query"]),
  querySearchAnalytics(["page"]),
  querySearchAnalytics(["country"]),
]);

const report = {
  generatedAt: new Date().toISOString(),
  siteUrl,
  sitemap,
  inspectedUrlCount: inspections.length,
  inspections,
  analytics: { totals, queries, pages, countries },
};

fs.writeFileSync(path.join(outputDir, "report.json"), `${JSON.stringify(report, null, 2)}\n`);
fs.writeFileSync(path.join(outputDir, "report.md"), buildMarkdown(report));
console.log(`GSC report created for ${siteUrl}: ${inspections.length} URLs inspected.`);
