# Community Distribution Guide (No Apple Developer Account)

Use this guide when sharing DocumentOrganizer builds without Apple Developer signing/notarization.

## Who this is for

- Trusted testers
- Internal pilots
- Community users who understand macOS security prompts

## What to expect

- App is unsigned and not notarized.
- macOS Gatekeeper will block first launch by default.
- Users must manually approve the app once.

## Distributor checklist

1. Build and package a community release:

   RELEASE_CHANNEL=community ./scripts/create_release_artifacts.sh
   ./scripts/generate_release_manifest.sh

2. Confirm release metadata includes:
   - Release Channel: community
   - Release Policy: community-unsigned

3. Publish with explicit acknowledgment:

   ALLOW_COMMUNITY_RELEASE=1 DRY_RUN=1 ./scripts/publish_github_release.sh
   ALLOW_COMMUNITY_RELEASE=1 DRY_RUN=0 ./scripts/publish_github_release.sh

4. Include this warning in release notes:
   - "This build is unsigned/unnotarized and intended for trusted testers."
   - Base your text on `docs/operations/community-release-notes-template.md`.

## End-user install steps (first launch)

1. Download and extract/open the app bundle.
2. Move DocumentOrganizer.app to Applications (optional but recommended).
3. Try opening the app normally once (it will likely be blocked).
4. Open System Settings > Privacy & Security.
5. In the Security section, click Open Anyway for DocumentOrganizer.
6. Confirm by clicking Open.
7. Next launches should open normally.

Alternative method:

1. In Finder, right-click DocumentOrganizer.app.
2. Choose Open.
3. Click Open in the confirmation dialog.

## Support notes for testers

- If macOS still blocks launch, re-open Privacy & Security and use Open Anyway again.
- If the app was quarantined by browser download attributes, move it to Applications and retry Open Anyway.
- If needed, delete the app, re-download, and repeat the approval flow.

## Risk disclosure template

Use this plain-text disclosure alongside every community release:

This community build is unsigned and not notarized by Apple. It is provided for trusted testing only. macOS may show security warnings on first launch. Only install if you trust the source of this build.
