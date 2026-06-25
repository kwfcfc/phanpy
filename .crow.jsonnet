// Crow CI workflow: build Phanpy from upstream source and publish it to
// Cloudflare Pages via Direct Upload (wrangler).
//
// This is a bare deployment branch: it carries NO app source of its own.
// Unlike Element (which ships a signed, prebuilt release tarball), Phanpy is
// meant to be built by each operator with their own config baked in at build
// time. So the pipeline clones upstream Phanpy at a pinned ref, builds it with
// npm + our PHANPY_* environment, and uploads the resulting `dist/`.
//
// Upstream "custom build" docs:
//   https://github.com/cheeaun/phanpy#custom-build-way
//
// One-time setup on Cloudflare (creates the Pages project; safe to run locally):
//   npx wrangler pages project create phanpy-recursion-link --production-branch main

// ---- Configuration ------------------------------------------------------
// Full node image (buildpack-deps based) ships git/curl, plus node/npm for the
// build and npx for wrangler.
local nodeImage = 'node:24-trixie';

// The branch on this repo that triggers a deploy when pushed.
local deployBranch = 'pages';

// Cloudflare Pages project name (must already exist, see header).
local projectName = 'phanpy-recursion-link';

// The project's "production branch" on Cloudflare. Passing this value to
// `wrangler --branch` makes the upload a *production* deployment (the live
// site) rather than a preview. It does not need to be a real git branch.
local productionBranch = 'main';

// --- Upstream source we build. Bump these to track a new release. ---
// `upstreamRef` can be a branch (e.g. 'production') or a tag (e.g. '2025.06.01').
local upstreamRepo = 'https://github.com/cheeaun/phanpy.git';
local upstreamRef = 'production';
local srcDir = 'phanpy';

// Vite build output that wrangler uploads.
local distDir = srcDir + '/dist';

// ---- Workflow -----------------------------------------------------------
{
  // Only deploy when the tracking branch is pushed, or when a human triggers
  // the pipeline manually from the Crow UI/CLI.
  when: [
    { event: 'push', branch: deployBranch },
    { event: 'manual' },
  ],

  // This branch has nothing worth cloning, so we replace the default clone
  // with a shallow clone of *upstream* Phanpy at the pinned ref. Everything
  // else in the workflow operates inside `srcDir`.
  clone: [
    {
      name: 'clone-upstream',
      image: nodeImage,
      commands: [
        'git clone --depth 1 --branch "%s" "%s" "%s"' % [upstreamRef, upstreamRepo, srcDir],
      ],
    },
  ],

  steps: [
    {
      name: 'build',
      image: nodeImage,
      // ---- CUSTOMIZE ME -------------------------------------------------
      // These PHANPY_* vars are baked into the static bundle at build time.
      // Plain values are fine for non-secret config; use `from_secret` for
      // anything sensitive (API keys). Drop any var you don't need.
      environment: {
        // App identity (title, PWA name, OAuth client name).
        PHANPY_CLIENT_NAME: 'Phanpy Recursion-Link',
        // Canonical URL of THIS deployment (OpenGraph + OAuth client URI).
        PHANPY_WEBSITE: "https://phanpy.recursion-link.eu.org",
        // Pre-fill the login instance: the BACKEND API host (host only, no
        // scheme), NOT the domain Phanpy itself is served from. Setting this
        // sends users straight to this instance's auth page on log-in.
        PHANPY_DEFAULT_INSTANCE: 'social.recursion-link.eu.org',
        // No public sign-up: the instance handles its own auth (Rauthy OIDC),
        // so there is no Phanpy-side registration page to link.
        PHANPY_DEFAULT_INSTANCE_REGISTRATION_URL: '',
        // UI language follows the browser (?lang= query, localStorage, then
        // navigator.language), falling back to English. That is Phanpy's
        // default, so PHANPY_DEFAULT_LANG is intentionally left unset.
        // Custom privacy policy link. Optional.
        PHANPY_PRIVACY_POLICY_URL: '',
        // Block crawlers via robots.txt — set to any non-empty value to enable.
        PHANPY_DISALLOW_ROBOTS: 'true',
      },
      commands: [
        'cd "%s"' % srcDir,
        // Reproducible install from the committed lockfile.
        'npm ci',
        // Vite production build -> writes to `dist/`.
        'npm run build',
      ],
    },
    {
      name: 'deploy',
      image: nodeImage,
      depends_on: ['build'],
      // wrangler auto-reads these for non-interactive auth.
      environment: {
        CLOUDFLARE_API_TOKEN: { from_secret: 'cloudflare_api_token' },
        CLOUDFLARE_ACCOUNT_ID: { from_secret: 'cloudflare_account_id' },
      },
      commands: [
        ('npx wrangler@4 pages deploy "%s"' % distDir) +
        (' --project-name "%s"' % projectName) +
        (' --branch "%s"' % productionBranch) +
        ' --commit-hash "$CI_COMMIT_SHA"' +
        ' --commit-message "$CI_COMMIT_MESSAGE"',
      ],
    },
  ],
}
