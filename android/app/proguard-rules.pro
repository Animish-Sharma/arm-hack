# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Google Play Services & Core
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# MediaPipe (used by flutter_gemma / dependencies)
-keep class com.google.mediapipe.** { *; }
-keep class com.google.mediapipe.proto.** { *; }
-keep class com.google.mediapipe.framework.** { *; }
-dontwarn com.google.mediapipe.**

# Protobuf
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**

# Prevent R8 from stripping native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# General
-dontwarn java.lang.invoke.*
-dontwarn javax.**

