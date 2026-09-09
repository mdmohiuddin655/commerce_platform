/// Platforms this repository reasons about when describing capabilities.
///
/// This is a *capability* axis, not a Flutter `TargetPlatform`: it exists so
/// capability tables can be written and tested without a Flutter binding and
/// without importing any vendor SDK.
enum CapabilityPlatform { android, ios, web, windows, macos, linux }
