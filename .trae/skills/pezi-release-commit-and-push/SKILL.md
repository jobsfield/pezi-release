---
name: pezi-release-commit-and-push
description: "Publish the latest signed and notarized Pezi build from the pezi-release repository. Use this whenever the user is working in the pezi-release repo and says things like 'commit and push', 'publish release', 'ship the latest build', 'push the new version', or asks you to handle the release feed for them. This skill assumes Xcode has already produced a signed/notarized Pezi.app archive and turns that archive into a published Sparkle release."
---

# Pezi Release Commit And Push

This skill is for the `pezi-release` repository only.

The intent is deliberately narrow: the user has already built, signed, and notarized `Pezi.app` in Xcode, and wants the release repo to do the rest.

## What this skill does

1. Finds the latest archived `Pezi.app` under `~/Library/Developer/Xcode/Archives`
2. Optionally picks up release notes from `release-notes/` if a matching Markdown file exists
3. Packages the app correctly with `ditto`
4. Regenerates `appcast.xml`
5. Commits and pushes the `pezi-release` repository

The deterministic entrypoint is:

```sh
./scripts/commit-and-push.sh
```

## Preconditions

Before running the script, confirm:

- the current repository is `pezi-release`
- the latest Xcode archive is the one the user actually wants to publish
- the app has already been signed and notarized

If those assumptions are false, stop and ask for the explicit archive path or for a fresh archive.

## Workflow

1. Run:

```sh
./scripts/commit-and-push.sh
```

2. If the script fails because the build already exists in `appcast.xml`, tell the user to bump `CFBundleVersion` in the app repo and rebuild.

3. If the script fails because no archive exists, tell the user to archive/export the app from Xcode first.

4. If the script succeeds, report:
   - the chosen archive path
   - the version/build that was published
   - the release repo commit hash
   - the public URLs for `appcast.xml` and the zip

## Release Notes Convention

If `release-notes/` exists in this repo, the wrapper script looks for:

- `release-notes/<short-version>-<build>.md`
- `release-notes/<short-version>.md`
- `release-notes/<build>.md`
- `release-notes/latest.md`

If none of those exist, it publishes without release notes.

## Failure Modes

- `appcast.xml already contains build ...`:
  The build number was not bumped. Do not work around this. Tell the user to increment `CFBundleVersion`.

- `Could not find a Pezi.app archive ...`:
  There is no exportable archive in Xcode's archive directory. Ask the user to build/sign/notarize first.

- Sparkle packaging or signing validation failures:
  Surface the exact error and stop. Do not hand-roll `appcast.xml`.

## Examples

**Example 1**

User: `commit and push`

Action: Run `./scripts/commit-and-push.sh` in the `pezi-release` repo and report the result.

**Example 2**

User: `publish the latest build`

Action: Same workflow. This phrase should trigger the skill even if the user does not mention Sparkle or appcast explicitly.

**Example 3**

User: `ship the new version`

Action: Same workflow, but if the newest archive is ambiguous, stop and ask which archive to use.
