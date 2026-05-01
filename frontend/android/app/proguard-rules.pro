# React Native (required by Jitsi Meet SDK)
-keep class com.facebook.react.** { *; }
-keep class com.facebook.hermes.** { *; }
-keep class com.facebook.soloader.** { *; }
-keep class com.facebook.jni.** { *; }
-dontwarn com.facebook.react.**
-dontwarn com.facebook.hermes.**

# Jitsi Meet SDK
-keep class org.jitsi.** { *; }
-keep class org.webrtc.** { *; }
-dontwarn org.jitsi.**
-dontwarn org.webrtc.**
