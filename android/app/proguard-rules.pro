# Firebase Authentication
-keepattributes Signature
-keepattributes *Annotation*

# Firebase core classes that use reflection
-keep class com.google.firebase.FirebaseApp { *; }
-keep class com.google.firebase.auth.** { *; }
-keep class com.google.firebase.firestore.** { *; }
-keep class com.google.firebase.analytics.** { *; }

# Google Play Services tasks (used by Firebase callbacks)
-keep class com.google.android.gms.tasks.** { *; }
-keep class com.google.android.gms.common.** { *; }

# Keep app-specific models if needed
-keep class se.butlery.app.models.** { *; }

# Suppress warnings
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
