# Flutter ProGuard Rules

# Keep Flutter wrapper and engine classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Don't warn for missing dependencies in plugins
-dontwarn io.flutter.plugins.**
-dontwarn io.flutter.common.**

# Keep standard Android/Kotlin runtime features
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# Keep model/serialization classes if needed
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
