# pezi-release

GitHub Pages release feed for Pezi.

This repo owns:

- `appcast.xml`
- published release archives such as `Pezi.app.zip`
- optional release notes such as `Pezi.app.md`
- the publishing helper script at `./scripts/publish-release.sh`
- the local release skill at `.trae/skills/pezi-release-commit-and-push/SKILL.md`

Typical release flow:

```sh
cd /Users/eason/Documents/GitBuh/pezi-release

./scripts/publish-release.sh \
  --app "/path/to/Pezi.app" \
  --release-notes "./release-notes/<short-version>-<build>.md" \
  --commit \
  --push
```

Guardrails:

- the script refuses to publish if `appcast.xml` already contains the same `CFBundleVersion`
- bump `CFBundleVersion` for every publishable build
- if the release is user-visible, usually bump `CFBundleShortVersionString` too
- when the user says `commit and push`, the repo-local skill should ask for the exported `Pezi.app` path and the release summary if they were not provided

If you need the explicit lower-level path, `./scripts/publish-release.sh --app "/path/to/Pezi.app" --commit --push` is still available.
