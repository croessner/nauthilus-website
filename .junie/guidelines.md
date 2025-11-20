Project Guidelines — Nauthilus Website (Docusaurus)

Audience: These notes target contributors familiar with Node.js, Docusaurus v3, and documentation workflows. The focus is on details unique to this repository.

1. Build and Configuration Instructions

- Toolchain
  - Node.js: >= 18.x (see package.json engines). Use an LTS 18 or newer.
  - Package manager: npm. Prefer `npm ci` for reproducible installs.

- Install and common scripts
  - Install deps: `npm ci`
  - Develop (hot reload): `npm start`
  - Production build: `npm run build`
  - Serve the production build locally: `npm run serve` (serves the ./build folder)
  - Clear caches: `npm run clear`

- Configuration highlights (docusaurus.config.js)
  - Latest version display uses NAUTHILUS_LATEST_VERSION when present; otherwise it falls back to latest-version.json, then to a hardcoded version.
    - Example: `NAUTHILUS_LATEST_VERSION=1.10.3 npm run build`
  - onBrokenLinks is set to "throw" to fail builds on broken links (link checking happens during `npm run build`).
  - i18n only includes `en`.
  - Theme defaults to dark mode and respects system settings.
  - Mermaid is enabled via `@docusaurus/theme-mermaid` with dark/light theme bound to color mode.

- Versions
  - Docs are versioned with `lastVersion: '1.10'`. The `current` channel is labeled “Next” with an ‘unreleased’ banner.
  - Versioned content lives under `versioned_docs/` with metadata tracked in `versions.json` and `versioned_sidebars/`.

- Content locations and conventions
  - Primary docs (Next): `docs/`
  - Static assets (unprocessed): `static/` (served at site root). Prefer placing shared images in `static/img/` and referencing them via `/img/...`.
  - Sidebar configuration: `sidebars.js`.
  - Blog (optional): `blog/`.

2. Testing Information

- What constitutes a “test” for this site
  - Build-time checks double as tests. With `onBrokenLinks: 'throw'`, the production build will fail on broken links and some MDX issues.
  - You can add lightweight Node-based checks to assert presence of critical build artifacts or to enforce content rules.

- Running tests
  - Core validation: run a clean install and a production build.
    - `npm ci`
    - `npm run build`
  - Optional: serve locally to manually inspect output.
    - `npm run serve` (then open the printed local URL)

- Adding a new lightweight test
  - Create a Node ESM script (e.g., `temp/test-something.mjs`) that imports `fs/promises` and asserts existence or content of key build outputs under `./build`.
  - Keep tests project-specific (e.g., check that important docs pages still generate and that expected HTML files exist).
  - Example test script (copy into a temporary file when needed):

    ```js
    // temp/test-build-check.mjs
    import {access} from 'fs/promises';
    import {constants} from 'fs';
    import {spawnSync} from 'child_process';

    function assertPath(p) {
      return access(p, constants.F_OK).catch(() => {
        throw new Error(`Missing required artifact: ${p}`);
      });
    }

    async function main() {
      // Ensure there is a production build
      const needBuild = access('build', constants.F_OK).then(() => false).catch(() => true);
      if (await needBuild) {
        const r = spawnSync('npm', ['run', 'build'], {stdio: 'inherit', shell: process.platform === 'win32'});
        if (r.status !== 0) process.exit(r.status ?? 1);
      }

      // Check a couple of critical artifacts
      await assertPath('build/index.html');
      await assertPath('build/docs/configuration/server-configuration/index.html');

      console.log('OK: build artifacts present');
    }

    main().catch((e) => { console.error(e); process.exit(1); });
    ```

  - Run the test:
    - `node temp/test-build-check.mjs`
  - Remove temporary test files once done to keep the repo clean (tests are transient demonstrations for this docs site).

- Notes for adding new docs/tests
  - New doc pages should include front matter (`title`, `description`, optional `sidebar_position`, etc.).
  - Prefer relative links within the docs section; use absolute `/img/...` for static assets.
  - If you add links between versions, verify them by running `npm run build` to catch broken links.

3. Additional Development Information

- Language policy
  - All documentation content must be written exclusively in English. This applies to `docs/`, `versioned_docs/`, `blog/`, and any MDX examples/components embedded in pages.
  - Avoid non-English text in docs pages, headings, front matter (`title`, `description`), admonitions, and in code snippets where comments are part of the rendered documentation. If non-English proper nouns or configuration keys appear, provide an English explanation alongside.
  - This complements the i18n configuration (English-only locale) and aims to keep the documentation consistent and searchable.

- Content style and MDX
  - Use standard Markdown/MDX. MDX is available for React components if needed, but keep pages static where possible for search indexing.
  - Code blocks: prefer language tags for syntax highlighting. Prism themes are configured; common languages render well.
  - Admonitions are supported via Docusaurus syntax (`:::tip`, `:::warning`, etc.).
  - Mermaid diagrams are supported using fenced blocks with `mermaid`.

- Navigation and search
  - Local search is enabled via `@easyops-cn/docusaurus-search-local`. It indexes docs and blog content. No extra config usually required.
  - Keep sidebar structure logical via `sidebars.js`. Large sections should be organized with `category` items.

- Versioning workflow
  - Before a release: snapshot the current docs into a new version using the standard Docusaurus versioning workflow (via Docusaurus CLI or manual maintenance). Update `versions.json` accordingly.
  - Keep `latest-version.json` (optional, maintained by CI) in sync so the site header reflects the current latest release. You can override with the `NAUTHILUS_LATEST_VERSION` env var during build.

- Common pitfalls
  - Broken links will fail `npm run build` due to `onBrokenLinks: 'throw'`. Use site-relative paths that Docusaurus can resolve.
  - Static files go in `static/`. Files in `docs/` are processed by the MDX loader and should not be referenced as raw assets.
  - Large images should be optimized before committing; they are served as-is from `static/`.

- Debugging the build
  - If the build fails, re-run with a clean cache: `npm run clear && npm run build`.
  - Inspect partial outputs in `build/` and terminal logs for the specific page that fails.
  - To isolate MDX issues, temporarily comment out problematic sections and reintroduce them incrementally.

Change management
- Keep documentation changes small and focused. Build locally before pushing.
- For larger restructures, validate both the dev server (`npm start`) and the production build (`npm run build`), as behavior can differ.
