# Flutter-specific ProGuard rules
# Keep Flutter engine classes
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep Drift/SQLite classes (for your database)
-keep class drift.** { *; }
-keep class org.sqlite.** { *; }
-keep class androidx.sqlite.** { *; }

# Keep JSON serialization (if using jsonDecode/jsonEncode)
-keepattributes *Annotation*
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Don't warn about missing classes from optional dependencies
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
