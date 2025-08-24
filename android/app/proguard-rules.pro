# CycleAvatar ProGuard Rules

# Keep Flutter classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep SQLite classes
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }

# Keep JSON serialization classes
-keepattributes *Annotation*
-keepclassmembers class ** {
    @com.fasterxml.jackson.annotation.* *;
}

# Keep Freezed generated classes
-keep class **$_$serializers { *; }
-keep class **$$serializer { *; }
-keepclassmembers class ** {
    *** toJson();
    *** fromJson(...);
}

# Keep Riverpod providers
-keep class **Provider { *; }
-keep class **NotifierProvider { *; }

# Keep domain entities
-keep class com.cycleavatar.cycle_avatar.domain.entities.** { *; }

# Keep native method names
-keepclasseswithmembernames class * {
    native <methods>;
}

# Remove logging in release builds
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int d(...);
    public static int e(...);
}

# Keep crash reporting
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# Optimize
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 5
-allowaccessmodification
-dontpreverify