# MediaPipe LLM Inference (flutter_gemma): R8 спотыкается об опциональные
# proto-классы профилировщика графа — их нет в рантайм-зависимостях, и они
# не нужны. Глушим предупреждения и держим остальной MediaPipe целым.
-dontwarn com.google.mediapipe.proto.**
-keep class com.google.mediapipe.** { *; }
-keep class com.google.protobuf.** { *; }
