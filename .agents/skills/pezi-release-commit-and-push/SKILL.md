---
name: pezi-release-commit-and-push
description: "Publish a signed and notarized Pezi build from the pezi-release repository. Use this whenever the user is working in the pezi-release repo and says things like 'commit and push', 'publish release', 'ship the new version', 'push the new version', or asks you to handle the release feed for them. This skill should ask the user for the Pezi.app path and release summary when those inputs are missing, rewrite rough release-note text into concise user-facing changelog copy, then finish the Sparkle publish flow in the release repo."
---

# Pezi Release Commit And Push

This skill is for the `pezi-release` repository only.

The intent is deliberately narrow: the user has already built, signed, and notarized `Pezi.app` in Xcode, and wants the release repo to do the rest.

## What this skill does

1. Asks for the exported `Pezi.app` path if the user did not provide it
2. Asks what changed in this release if the user did not provide release notes
3. Rewrites the user's rough release summary into polished changelog wording
4. Writes a Markdown release-notes file in this repo
5. Packages the app correctly with `ditto`
6. Regenerates `appcast.xml`
7. Commits and pushes the `pezi-release` repository

## Preconditions

Before running the script, confirm:

- the current repository is `pezi-release`
- the user has provided the exact `Pezi.app` they want to publish
- the app has already been signed and notarized

If those assumptions are false, stop and ask.

## Workflow

1. If the user did not provide an app path, ask for it directly. Do not guess by scanning Xcode archives.

2. If the user did not say what changed in this release, ask for a short bullet summary.

3. Always rewrite the user's summary into polished release-note copy before writing the Markdown file under `release-notes/`.

Guidelines for rewriting:
- Preserve the actual meaning. Do not invent features, fixes, or scope.
- Prefer concise, user-facing phrasing over internal implementation wording.
- Fix grammar, tense, and terminology.
- Avoid copying awkward raw text verbatim unless the user explicitly asks for that.
- For a single change, use one strong bullet. For multiple changes, keep each bullet short and parallel in structure.
- Prefer outcome-oriented phrasing such as "Improved...", "Fixed...", or "Refined..." when that accurately reflects the change.

4. Run the deterministic publisher:

```sh
./scripts/publish-release.sh \
  --app "/path/to/Pezi.app" \
  --release-notes "./release-notes/<short-version>-<build>.md" \
  --commit \
  --push
```

5. If the script fails because the build already exists in `appcast.xml`, tell the user to bump `CFBundleVersion` in the app repo and rebuild.

6. If the script fails because the app path is wrong or the app is not export-ready, tell the user exactly what needs to be rebuilt or re-exported.

7. If the script succeeds, report:
   - the chosen archive path
   - the version/build that was published
   - the release repo commit hash
   - the public URLs for `appcast.xml` and the zip

## Release Notes Convention

Create `release-notes/<short-version>-<build>.md` before publishing.

Recommended content:

```md
# Pezi <short-version>

Build <build>

Highlights:
- ...
- ...
```

The `Highlights` bullets should be polished release-note copy, not a raw paste of the user's wording.

Examples of acceptable rewrites:

- Raw: `improve the robustness of instagram media extraction`
  Final: `Improved the reliability of Instagram media extraction`

- Raw: `Refresh folder artwork in the Favorites section in time to prevent empty folders when Bankai Mode is on.`
  Final: `Refreshed Favorites folder artwork promptly to prevent empty folder thumbnails when Bankai Mode is enabled`

## Failure Modes

- `appcast.xml already contains build ...`:
  The build number was not bumped. Do not work around this. Tell the user to increment `CFBundleVersion`.

- Missing app path:
  Ask the user for the exact exported `Pezi.app`.

- Missing release summary:
  Ask the user what changed in this release, rewrite it into polished changelog wording, then write the release notes file yourself.

- Sparkle packaging or signing validation failures:
  Surface the exact error and stop. Do not hand-roll `appcast.xml`.

## Examples

**Example 1**

User: `commit and push`

Action: Ask for the exported `Pezi.app` path and what changed in this release if either is missing. Then write the release notes file, run `publish-release.sh`, and report the result.

**Example 2**

User: `publish the latest build`

Action: Same workflow. This phrase should trigger the skill even if the user does not mention Sparkle or appcast explicitly.

**Example 3**

User: `ship the new version`

Action: Same workflow. Do not scan for a candidate archive; ask the user which `Pezi.app` to publish.
