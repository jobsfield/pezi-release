# pezi-release

GitHub Pages release feed for Pezi.

This repo owns:

- `appcast.xml`
- published release archives such as `Pezi.app.zip`
- optional release notes such as `Pezi.app.md`
- the publishing helper script at `./scripts/publish-release.sh`

Typical release flow:

```sh
cd /Users/eason/Documents/GitBuh/pezi-release

./scripts/publish-release.sh \
  --app "/path/to/Pezi.app" \
  --release-notes ./release-notes/1.0.1.md \
  --commit \
  --push
```

Guardrails:

- the script refuses to publish if `appcast.xml` already contains the same `CFBundleVersion`
- bump `CFBundleVersion` for every publishable build
- if the release is user-visible, usually bump `CFBundleShortVersionString` too
