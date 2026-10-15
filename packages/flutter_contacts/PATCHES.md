# Local compatibility patch

Based on flutter_contacts 1.1.9+2 from pub.dev; upstream LICENSE retained.
Android and Dart APIs are unchanged.

The iOS plugin retains its FlutterPluginRegistrar instead of force-unwrapping
UIApplicationDelegate.window at registration. UIScene leaves that window nil.
Native contact dialogs resolve registrar.viewController() at presentation time
and return a FlutterError if the view is unavailable, instead of crashing or
leaving the Dart call unanswered.

Upstream issue: https://github.com/QuisApp/flutter_contacts/issues/230
Migration guidance: https://docs.flutter.dev/release/breaking-changes/uiscenedelegate
Remove this local dependency when upgrading the app to a compatible upstream
version, after validating its Android requirements and new Dart API.
