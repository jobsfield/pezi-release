# pezi-release

GitHub Pages release feed for Pezi.

This repo owns:

- `appcast.xml`
- published release archives such as `Pezi.app.zip`
- optional release notes such as `Pezi.app.md`
- the publishing helper script at `./scripts/publish-release.sh`
- the zero-argument release wrapper at `./scripts/commit-and-push.sh`
- the release-notes generator at `./scripts/generate-release-notes.sh`
- the local release skill at `.trae/skills/pezi-release-commit-and-push/SKILL.md`

Typical release flow:

```sh
cd /Users/eason/Documents/GitBuh/pezi-release

./scripts/commit-and-push.sh
```

Guardrails:

- the script refuses to publish if `appcast.xml` already contains the same `CFBundleVersion`
- bump `CFBundleVersion` for every publishable build
- if the release is user-visible, usually bump `CFBundleShortVersionString` too
- if release notes do not already exist, the wrapper auto-generates them from the archived app metadata and recent `candy-jar` commits

If you need the explicit lower-level path, `./scripts/publish-release.sh --app "/path/to/Pezi.app" --commit --push` is still available.
