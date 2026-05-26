########################################
# FLUTTER CORE (OBBLIGATORIO)
########################################
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.app.** { *; }

########################################
# ATTRIBUTI ESSENZIALI & ANNOTATIONS
########################################
# Mantiene firme dei metodi e annotazioni necessarie a Riverpod, Hive e i plugin nativi
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

########################################
# WIREDASH (SUPPORTO & FEEDBACK)
########################################
-keep class com.wiredash.** { *; }
-dontwarn com.wiredash.**

########################################
# HIVE (DATABASE LOCALE)
########################################
-keep class hive.** { *; }
-keep class * extends hive.HiveObject { *; }
-dontwarn hive.**

########################################
# SECURE STORAGE
########################################
-keep class com.it_nomads.fluttersecurestorage.** { *; }

########################################
# LOCAL AUTH (BIOMETRIC)
########################################
-keep class io.flutter.plugins.localauth.** { *; }
# Previene la rimozione delle interfacce biometriche di AndroidX
-keep class androidx.biometric.** { *; }

########################################
# FILE PICKER & SHARE PLUS
########################################
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keep class dev.fluttercommunity.plus.share.** { *; }

########################################
# PDF / PRINTING
########################################
-keep class net.nfet.flutter.printing.** { *; }

########################################
# GOOGLE SERVICES & PLAY STORE (RISOLUZIONE ERRORE COMPILAZIONE)
########################################
-keep class com.google.android.gms.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }

# Dice a R8 di ignorare le classi mancanti di Google Play (Deferred Components non usati)
-dontwarn com.google.android.play.core.**

########################################
# PROTEZIONE SERIALIZZAZIONE JSON (GSON / REFLECTION)
########################################
# Molti plugin usano Gson internamente; l'offuscamento distruggerebbe i campi dei JSON
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-dontwarn com.google.errorprone.annotations.**

########################################
# RIMOZIONE DEI LOG IN RILASCIO (R8 COMPATIBILE)
########################################
# Questo metodo non rompe la compilazione di R8 e rimuove i log di Debug e Verbose dall'APK finale
-maximumremovedandroidloglevel 3