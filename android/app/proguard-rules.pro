# Play Console flagged the release build for near-zero DEX shrinking/
# obfuscation (isMinifyEnabled was off). These rules keep R8 from stripping
# or renaming anything the app's plugins reach via reflection or JNI, while
# still shrinking/obfuscating everything else.

# --- Flutter / Play Core -----------------------------------------------
# Flutter's embedding references the Play Core split-install API even when
# the app does not use dynamic feature modules; R8 fails the build without
# either the dependency or these -dontwarn lines.
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
-dontwarn com.google.android.play.core.**
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# --- Firebase Messaging --------------------------------------------------
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.iid.** { *; }

# --- Google Sign-In / Play Services Auth --------------------------------
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.signin.** { *; }

# --- Google Maps ----------------------------------------------------------
-keep class com.google.android.gms.maps.** { *; }
-keep interface com.google.android.gms.maps.** { *; }

# --- Google Mobile Ads (AdMob) -------------------------------------------
-keep class com.google.android.gms.ads.** { *; }

# --- local_auth (biometric prompt) ---------------------------------------
-keep class androidx.biometric.** { *; }

# --- video_player / ExoPlayer ---------------------------------------------
-dontwarn com.google.android.exoplayer2.**

# --- Gson / JSON used by several plugins for reflection-based (de)serialization
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# --- General Android housekeeping ----------------------------------------
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
