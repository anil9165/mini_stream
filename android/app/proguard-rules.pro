# Keep Agora RTC bindings intact while allowing the rest of the app to shrink.
-keep class io.agora.** { *; }
-dontwarn io.agora.**

# Flutter plugins use generated registrants and reflection in a few native paths.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Flutter references Play Core deferred-component classes even when the app does
# not use deferred components. They are optional for this APK build.
-dontwarn com.google.android.play.core.**
