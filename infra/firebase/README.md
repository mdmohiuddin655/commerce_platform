# infra/firebase

Empty at FND-001. Owner: FND-004.

Planned: one Firebase project **per environment**, with multiple app
registrations (one per role app per platform). One logical source of truth does
not mean permanently one physical database worldwide — keep `homeRegion` and
routing boundaries so regional cells can be introduced through an ADR.

Must live here eventually: `firebase.json`, Firestore security rules and
indexes, emulator configuration, and the rules test suite. Rules are a security
boundary and get tested against the emulator; that requires the Firebase CLI,
which is **not installed** on the bootstrap host (owner action O4).

**Never commit** to this repository: `google-services.json`,
`GoogleService-Info.plist`, generated `firebase_options.dart`, service-account
JSON or any `.env`. All are git-ignored; `tools/check_layering.sh` also fails on
API-key- and private-key-shaped strings in tracked source.
