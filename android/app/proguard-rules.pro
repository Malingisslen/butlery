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

# ML Kit text recognition: the four non-Latin scripts are absent BY DESIGN, not
# stripped. google_mlkit_text_recognition declares them `compileOnly`
# (its android/build.gradle:51-54), so `TextRecognizer.initialize` names all five
# option classes while only `text-recognition` (Latin) is on the runtime
# classpath. A -keep rule cannot keep a class that was never packaged; R8 fails
# the release build on the dangling references unless they are declared expected.
# Scoped to the four unshipped scripts on purpose — a blanket
# `-dontwarn com.google.mlkit.**` would also silence a real break in the Latin
# recognizer, which IS shipped and IS the only script the app requests
# (device_text_recognizer_mlkit.dart: TextRecognitionScript.latin).
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
