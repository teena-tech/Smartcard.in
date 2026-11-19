# ── Application Classes ────────────────────────────────────────────────────────
-keep class com.antz_media_solutions.SmartCards.** { *; }
-dontwarn com.antz_media_solutions.SmartCards.**

# ── Keep Essential Attributes ────────────────────────────────────────────────
-keepattributes Signature,Annotation,*Annotation*,EnclosingMethod,InnerClasses,Exceptions

# ── Flutter Engine & Native Plugins ──────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**
-dontwarn io.flutter.plugins.**

# ── Network Stack (Dio, OkHttp3, Okio) ────────────────────────────────────────
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn dio.**
-keep class dio.** { *; }

# ── GSON / Serialization ──────────────────────────────────────────────────────
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# ── Razorpay Payment Gateway ──────────────────────────────────────────────────
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# ── ML Kit Vision & Barcode Scanning ──────────────────────────────────────────
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-keep class com.google.android.odml.** { *; }

# ── CameraX & ZXing ───────────────────────────────────────────────────────────
-keep class androidx.camera.** { *; }
-keep class com.google.zxing.** { *; }

# ── Firebase Stack ────────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class io.flutter.plugins.firebase.** { *; }

# ── Flutter Contacts & SQLite / Storage ───────────────────────────────────────
-keep class co.quis.flutter_contacts.** { *; }
-keep class com.tekartik.sqflite.** { *; }
-keep class com.it_ne.flutter_secure_storage.** { *; }
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**

# ── Flutter DotEnv & Generative AI ───────────────────────────────────────────
-keep class com.github.dime.flutterdotenv.** { *; }
-keep class com.google.ai.client.generativeai.** { *; }

# ── Media, Cropper & Scanner Plugins ─────────────────────────────────────────
-keep class com.yalantis.ucrop.** { *; }
-keep class vn.hunghd.flutter.plugins.imagecropper.** { *; }
-keep class dev.nfet.flutter.mobile_scanner.** { *; }
-keep class com.pierfrancescosoffritti.androidyoutubeplayer.** { *; }
-keep class com.airbnb.lottie.** { *; }
-keep class xyz.luan.audioplayers.** { *; }
-dontwarn xyz.luan.audioplayers.**

# ── SMS Retriever / User Consent API ─────────────────────────────────────────
-keep class com.google.android.gms.auth.api.phone.** { *; }
-keep class fman.ge.smart_auth.** { *; }
-keep class com.jaumard.smsautofill.** { *; }
-dontwarn com.google.android.gms.auth.api.phone.**
-dontwarn fman.ge.smart_auth.**
-dontwarn com.jaumard.smsautofill.**

# ── Google Play Core / In-App Update ──────────────────────────────────────────
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**
-keep class dev.feelfreelinux.in_app_update.** { *; }
-dontwarn dev.feelfreelinux.in_app_update.**

