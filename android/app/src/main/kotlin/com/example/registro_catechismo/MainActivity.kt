package com.delelimed.catechhub

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.PublicKey
import java.security.spec.X509EncodedKeySpec
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.spec.OAEPParameterSpec
import javax.crypto.spec.PSource
import java.security.spec.MGF1ParameterSpec
import java.security.Signature

class MainActivity : FlutterFragmentActivity() {
    private val securityChannel = "com.delelimed.catechhub/security"
    private val keystoreChannel = "com.catechhub/keystore"
    private val KEYSTORE_PROVIDER = "AndroidKeyStore"
    private val KEY_ALGORITHM = "RSA"
    private val KEY_SIZE = 2048 
    private val SIGNATURE_ALGORITHM = "SHA512withRSA"
    private val CIPHER_TRANSFORMATION = "RSA/ECB/OAEPPadding"
    
    private val OAEP_SPEC = OAEPParameterSpec(
        "SHA-256",
        "MGF1",
        MGF1ParameterSpec.SHA256,
        PSource.PSpecified.DEFAULT
    )

    // SPOSTATO SU DISPATCHERS.IO: Rilascia immediatamente il Thread UI di Android
    private val ioScope = CoroutineScope(Dispatchers.IO)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        // Security channel for screenshot prevention
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, securityChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecureFlag" -> {
                        val requested = call.argument<Boolean>("enabled") ?: false
                        runOnUiThread {
                            if (requested) {
                                window.setFlags(
                                    WindowManager.LayoutParams.FLAG_SECURE,
                                    WindowManager.LayoutParams.FLAG_SECURE,
                                )
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            }
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // Keystore channel completamente asincrono su thread secondario
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, keystoreChannel)
            .setMethodCallHandler { call, result ->
                ioScope.launch {
                    try {
                        when (call.method) {
                            "generateKeyPair" -> {
                                val alias = call.argument<String>("alias") ?: return@launch runOnMain { result.error("BAD_ARGUMENT", "Alias is missing", null) }
                                val publicKey = generateKeyPair(alias)
                                runOnMain { result.success(publicKey) }
                            }
                            "getPublicKey" -> {
                                val alias = call.argument<String>("alias") ?: return@launch runOnMain { result.error("BAD_ARGUMENT", "Alias is missing", null) }
                                val publicKey = getPublicKey(alias)
                                runOnMain { result.success(publicKey) }
                            }
                            "signData" -> {
                                val alias = call.argument<String>("alias") ?: return@launch runOnMain { result.error("BAD_ARGUMENT", "Alias is missing", null) }
                                val data = call.argument<String>("data") ?: return@launch runOnMain { result.error("BAD_ARGUMENT", "Data is missing", null) }
                                val signature = signData(alias, data)
                                runOnMain { result.success(signature) }
                            }
                            "verifySignature" -> {
                                val publicKey = call.argument<String>("publicKey") ?: return@launch runOnMain { result.error("BAD_ARGUMENT", "PublicKey is missing", null) }
                                val data = call.argument<String>("data") ?: return@launch runOnMain { result.error("BAD_ARGUMENT", "Data is missing", null) }
                                val signature = call.argument<String>("signature") ?: return@launch runOnMain { result.error("BAD_ARGUMENT", "Signature is missing", null) }
                                val isValid = verifySignature(publicKey, data, signature)
                                runOnMain { result.success(isValid) }
                            }
                            "encryptWithPublicKey" -> {
                                val publicKey = call.argument<String>("publicKey") ?: return@launch runOnMain { result.error("BAD_ARGUMENT", "PublicKey is missing", null) }
                                val data = call.argument<String>("data") ?: return@launch runOnMain { result.error("BAD_ARGUMENT", "Data is missing", null) }
                                val encrypted = encryptWithPublicKey(publicKey, data)
                                runOnMain { result.success(encrypted) }
                            }
                            "decryptWithPrivateKey" -> {
                                val alias = call.argument<String>("alias") ?: return@launch runOnMain { result.error("BAD_ARGUMENT", "Alias is missing", null) }
                                val encryptedData = call.argument<String>("encryptedData") ?: return@launch runOnMain { result.error("BAD_ARGUMENT", "EncryptedData is missing", null) }
                                val decrypted = decryptWithPrivateKey(alias, encryptedData)
                                runOnMain { result.success(decrypted) }
                            }
                            "keyExists" -> {
                                val alias = call.argument<String>("alias") ?: return@launch runOnMain { result.error("BAD_ARGUMENT", "Alias is missing", null) }
                                val exists = keyExists(alias)
                                runOnMain { result.success(exists) }
                            }
                            "deleteKey" -> {
                                val alias = call.argument<String>("alias") ?: return@launch runOnMain { result.error("BAD_ARGUMENT", "Alias is missing", null) }
                                deleteKey(alias)
                                runOnMain { result.success(null) }
                            }
                            "listKeys" -> {
                                val keys = listKeys()
                                runOnMain { result.success(keys) }
                            }
                            else -> runOnMain { result.notImplemented() }
                        }
                    } catch (e: Exception) {
                        runOnMain { 
                            result.error("KEYSTORE_ERROR", e.localizedMessage ?: e.message, null) 
                        }
                    }
                }
            }

        // RFCOMM server per fallback Bluetooth classico
        RfcommServerPlugin(flutterEngine).register()

        // BLE association plugin per modalità associazione
        BleAssociationPlugin(this, flutterEngine).register()
    }

    // Helper per inviare il risultato a Flutter sul thread principale richiesto dal framework
    private fun runOnMain(action: () -> Unit) {
        runOnUiThread { action() }
    }

    private fun generateKeyPair(alias: String): String {
        val keyPairGenerator = KeyPairGenerator.getInstance(KEY_ALGORITHM, KEYSTORE_PROVIDER)
        val spec = KeyGenParameterSpec.Builder(
            alias,
            KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY or KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setKeySize(KEY_SIZE)
            .setSignaturePaddings(KeyProperties.SIGNATURE_PADDING_RSA_PKCS1)
            .setDigests(KeyProperties.DIGEST_SHA256, KeyProperties.DIGEST_SHA512)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_RSA_OAEP)
            .build()
        
        keyPairGenerator.initialize(spec)
        val keyPair = keyPairGenerator.generateKeyPair()
        return Base64.getEncoder().encodeToString(keyPair.public.encoded)
    }

    private fun getPublicKey(alias: String): String? {
        val keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER)
        keyStore.load(null)
        if (!keyStore.containsAlias(alias)) return null
        val certificate = keyStore.getCertificate(alias) ?: return null
        return Base64.getEncoder().encodeToString(certificate.publicKey.encoded)
    }

    private fun signData(alias: String, data: String): String {
        val keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER)
        keyStore.load(null)
        val privateKey = keyStore.getKey(alias, null) as PrivateKey
        val signature = Signature.getInstance(SIGNATURE_ALGORITHM)
        signature.initSign(privateKey)
        signature.update(data.toByteArray(Charsets.UTF_8))
        return Base64.getEncoder().encodeToString(signature.sign())
    }

    private fun verifySignature(publicKeyStr: String, data: String, signatureStr: String): Boolean {
        val publicKeyBytes = Base64.getDecoder().decode(publicKeyStr)
        val keySpec = X509EncodedKeySpec(publicKeyBytes)
        val keyFactory = java.security.KeyFactory.getInstance(KEY_ALGORITHM)
        val publicKey = keyFactory.generatePublic(keySpec)
        
        val signature = Signature.getInstance(SIGNATURE_ALGORITHM)
        signature.initVerify(publicKey)
        signature.update(data.toByteArray(Charsets.UTF_8))
        
        val signatureBytes = Base64.getDecoder().decode(signatureStr)
        return signature.verify(signatureBytes)
    }

    private fun encryptWithPublicKey(publicKeyStr: String, data: String): String {
        val publicKeyBytes = Base64.getDecoder().decode(publicKeyStr)
        val keySpec = X509EncodedKeySpec(publicKeyBytes)
        val keyFactory = java.security.KeyFactory.getInstance(KEY_ALGORITHM)
        val publicKey = keyFactory.generatePublic(keySpec)
        
        val cipher = Cipher.getInstance(CIPHER_TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, publicKey, OAEP_SPEC)
        
        val encryptedBytes = cipher.doFinal(data.toByteArray(Charsets.UTF_8))
        return Base64.getEncoder().encodeToString(encryptedBytes)
    }

    private fun decryptWithPrivateKey(alias: String, encryptedData: String): String {
        val keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER)
        keyStore.load(null)
        val privateKey = keyStore.getKey(alias, null) as PrivateKey
        val cipher = Cipher.getInstance(CIPHER_TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, privateKey, OAEP_SPEC)
        
        val encryptedBytes = Base64.getDecoder().decode(encryptedData)
        val decryptedBytes = cipher.doFinal(encryptedBytes)
        return String(decryptedBytes, Charsets.UTF_8)
    }

    private fun keyExists(alias: String): Boolean {
        val keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER)
        keyStore.load(null)
        return keyStore.containsAlias(alias)
    }

    private fun deleteKey(alias: String) {
        val keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER)
        keyStore.load(null)
        if (keyStore.containsAlias(alias)) {
            keyStore.deleteEntry(alias)
        }
    }

    private fun listKeys(): List<String> {
        val keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER)
        keyStore.load(null)
        return keyStore.aliases().toList()
    }
}