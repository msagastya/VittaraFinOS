# ML Kit Text Recognition — keep all script recognizer options
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.vision.text.chinese.** { *; }
-keep class com.google.mlkit.vision.text.devanagari.** { *; }
-keep class com.google.mlkit.vision.text.japanese.** { *; }
-keep class com.google.mlkit.vision.text.korean.** { *; }
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Flutter TTS
-keep class com.tundralabs.fluttertts.** { *; }

# Speech to text
-keep class com.csdcorp.speech_to_text.** { *; }

# General Flutter keep rules
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter Play Core deferred components (not used, suppress missing class warnings)
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
