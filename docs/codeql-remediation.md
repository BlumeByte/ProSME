# CodeQL remediation

Baseline: `791ee31bc7d78bbc952ff578a5e346265a9a9b0a` (pulled 2026-11-16).

## Android scan

The historical run 27557962109 contains a failed Java/Kotlin job
81461938495 followed by an Adjust Configuration job. Current default-setup
runs contain only Actions and JavaScript/TypeScript. The historical log download
returns HTTP 410, so the exact original compiler error cannot be established.

The repository requires Flutter's SDK and generated local.properties/plugin
configuration before Gradle can build it. `codeql.yml` supplies Flutter, Java 17,
plugin resolution and an explicit debug APK build after CodeQL initialization.
Debug avoids the release-keystore requirement and does not need production secrets.
It preserves scans for Actions and JavaScript/TypeScript, including generated JS.

To activate this workflow, publish it and switch GitHub Settings → Code security
→ CodeQL from default setup to advanced setup. Default setup blocks advanced
analysis uploads. Run the workflow and verify successful results for all three
languages before considering the scan failure resolved. Local build success
alone does not prove CodeQL extraction/upload success.

## Alert triage

- #155: preview requests now look up files in a startup catalogue. Request strings
  never become filesystem paths. Symlink entries are excluded. Malformed URL
  encodings and traversal segments receive 400, and file read errors no longer
  crash the server. `node --test scripts/serve_web.test.js` covers hostile paths,
  malformed encodings, normal assets, SPA routes, HEAD and missing files.
- #14: the pulled source already uses `crypto.randomUUID` / `getRandomValues`
  for analytics identifiers and rejection-sampled cryptographic random indices.
  No `Math.random` remains in `admin_web/src/main.js`. Confirm closure in the next
  scan rather than dismissing the alert without a fresh analysis.
- #281–289: supplied locations include Flutter plugin channel names and the
  CanvasKit CDN URL, rather than hostname validation expressions. They need
  their complete CodeQL dataflow traces reviewed before a final disposition.
- #279–280: the supplied location is XML comment parsing, not an HTML sanitizer.
  Do not replace it with ad-hoc regex escaping in the compiled bundle.
- #277–278: expressions exist in generated code (stack-trace parsing and SVG
  transform parsing). Dependency-source review and input-reachability analysis
  remain necessary; no claim of remediation is made for these alerts.
- #290–295: generated property/map operations need complete dataflow traces to
  establish whether attacker-controlled keys reach unsafe objects.
- #21–48: historical generated-bundle locations no longer identify the originally
  reported expression reliably. Use the alert's analyzed commit and current
  instance, rather than editing compiled output by stale line number.

No alerts were dismissed, query rules disabled, or generated files excluded.
