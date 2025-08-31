# Firebase Authentication
-keepattributes Signature
-keepattributes *Annotation*

# Firebase Firestore
-keep class com.google.firebase.firestore.** { *; }
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Firebase Auth
-keep class com.google.firebase.auth.** { *; }
-keep class com.google.android.gms.internal.** { *; }

# Prevent obfuscation of Firebase classes
-keep class com.google.firebase.FirebaseApp { *; }
-keep class com.google.firebase.analytics.** { *; }

# Keep Google Play Services classes
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.tasks.** { *; }

# Keep Android X classes
-keep class androidx.** { *; }
-keep interface androidx.** { *; }

# Keep app-specific models if needed
-keep class com.example.butlery.models.** { *; }

# Suppress warnings
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**