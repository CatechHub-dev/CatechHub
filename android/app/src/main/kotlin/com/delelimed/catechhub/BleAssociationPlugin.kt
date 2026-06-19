package com.delelimed.catechhub

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.ParcelUuid
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.nio.charset.StandardCharsets
import java.util.UUID

class BleAssociationPlugin(private val context: Context, private val engine: FlutterEngine) {
    companion object {
        private const val TAG = "BleAssociation"
        val SERVICE_UUID = UUID.fromString("6e400001-b5a3-f393-e0a9-e50e24dcca9e")
        const val METHOD_CHANNEL = "com.delelimed.catechhub/ble_association"
        const val EVENT_CHANNEL = "com.delelimed.catechhub/ble_association_events"
        private const val AD_SEPARATOR = '\u0000'
    }

    private var bluetoothManager: BluetoothManager? = null
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var advertiser: BluetoothLeAdvertiser? = null
    private var gattServer: BluetoothGattServer? = null
    private var advertiseCallback: AdvertiseCallback? = null
    private var scanCallback: ScanCallback? = null
    private var eventSink: EventChannel.EventSink? = null

    private var isAdvertising = false
    private var isScanning = false
    private var currentProfileName: String = ""
    private var currentRole: String = ""

    private val methodHandler = MethodChannel.MethodCallHandler { call, result ->
        when (call.method) {
            "startAdvertising" -> {
                val profileName = call.argument<String>("profileName") ?: ""
                val role = call.argument<String>("role") ?: ""
                result.success(startAdvertising(profileName, role))
            }
            "stopAdvertising" -> {
                stopAdvertising()
                result.success(null)
            }
            "startScanning" -> {
                result.success(startScanning())
            }
            "stopScanning" -> {
                stopScanning()
                result.success(null)
            }
            "isBluetoothEnabled" -> {
                result.success(isBluetoothEnabled())
            }
            "isBleSupported" -> {
                result.success(isBleSupported())
            }
            else -> result.notImplemented()
        }
    }

    private val eventHandler = object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
            eventSink = events
        }

        override fun onCancel(arguments: Any?) {
            eventSink = null
        }
    }

    fun register() {
        bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager?.adapter

        MethodChannel(engine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler(methodHandler)

        EventChannel(engine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(eventHandler)
    }

    private fun isBluetoothEnabled(): Boolean {
        return bluetoothAdapter?.isEnabled == true
    }

    private fun isBleSupported(): Boolean {
        return bluetoothAdapter?.bluetoothLeScanner != null
    }

    private fun startAdvertising(profileName: String, role: String): Boolean {
        if (isAdvertising) return true
        if (!isBluetoothEnabled()) {
            Log.e(TAG, "Bluetooth non abilitato")
            return false
        }

        currentProfileName = profileName
        currentRole = role
        advertiser = bluetoothAdapter?.bluetoothLeAdvertiser

        if (advertiser == null) {
            Log.e(TAG, "BLE Advertiser non disponibile")
            return false
        }

        try {
            // Setup GATT server
            setupGattServer()

            // Advertise settings
            val settings = AdvertiseSettings.Builder()
                .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
                .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
                .setConnectable(true)
                .setTimeout(0)
                .build()

            // Encode profileName and role into a single service data blob under SERVICE_UUID.
            // BLE requires service data keys to match the advertised service UUID.
            val adBytes = "$profileName$AD_SEPARATOR$role".toByteArray(StandardCharsets.UTF_8)
            val data = AdvertiseData.Builder()
                .setIncludeDeviceName(false)
                .addServiceUuid(ParcelUuid(SERVICE_UUID))
                .addServiceData(ParcelUuid(SERVICE_UUID), adBytes)
                .build()

            advertiseCallback = object : AdvertiseCallback() {
                override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
                    Log.d(TAG, "Advertising avviato con successo")
                    isAdvertising = true
                }

                override fun onStartFailure(errorCode: Int) {
                    Log.e(TAG, "Advertising fallito: $errorCode")
                    isAdvertising = false
                }
            }

            advertiser?.startAdvertising(settings, data, advertiseCallback)
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Errore avvio advertising: ${e.message}")
            return false
        }
    }

    private fun stopAdvertising() {
        if (!isAdvertising) return
        advertiseCallback?.let {
            advertiser?.stopAdvertising(it)
        }
        advertiseCallback = null
        isAdvertising = false
        stopGattServer()
        Log.d(TAG, "Advertising fermato")
    }

    private fun setupGattServer() {
        stopGattServer()

        val service = BluetoothGattService(SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)

        val displayNameCharacteristic = BluetoothGattCharacteristic(
            SERVICE_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ,
            BluetoothGattCharacteristic.PERMISSION_READ
        )
        val adBytes = "$currentProfileName$AD_SEPARATOR$currentRole".toByteArray(StandardCharsets.UTF_8)
        displayNameCharacteristic.value = adBytes

        service.addCharacteristic(displayNameCharacteristic)

        gattServer = bluetoothManager?.openGattServer(context, gattServerCallback)
        gattServer?.addService(service)

        Log.d(TAG, "GATT server avviato")
    }

    private fun stopGattServer() {
        gattServer?.close()
        gattServer = null
    }

    private val gattServerCallback = object : BluetoothGattServerCallback() {
        override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
            Log.d(TAG, "GATT connection state: $device, status: $status, newState: $newState")
        }
    }

    private fun startScanning(): Boolean {
        if (isScanning) return true
        if (!isBluetoothEnabled()) {
            Log.e(TAG, "Bluetooth non abilitato")
            return false
        }

        val scanner = bluetoothAdapter?.bluetoothLeScanner
        if (scanner == null) {
            Log.e(TAG, "BLE Scanner non disponibile")
            return false
        }

        try {
            val filter = ScanFilter.Builder()
                .setServiceUuid(ParcelUuid(SERVICE_UUID))
                .build()

            val settings = ScanSettings.Builder()
                .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                .build()

            scanCallback = object : ScanCallback() {
                override fun onScanResult(callbackType: Int, result: ScanResult) {
                    val device = result.device
                    val scanRecord = result.scanRecord

                    // Parse service data from SERVICE_UUID (contains profileName + \0 + role)
                    val adRaw = scanRecord?.getServiceData(ParcelUuid(SERVICE_UUID))
                    val adStr = adRaw?.let { String(it, StandardCharsets.UTF_8) } ?: ""
                    val parts = adStr.split(AD_SEPARATOR)
                    val profileName = parts.getOrElse(0) { device.name ?: "Sconosciuto" }
                    val role = parts.getOrElse(1) { "" }

                    val deviceInfo = mapOf(
                        "address" to (device.address ?: ""),
                        "profileName" to profileName,
                        "role" to role,
                        "rssi" to result.rssi
                    )

                    Log.d(TAG, "Dispositivo trovato: $deviceInfo")
                    eventSink?.success(deviceInfo)
                }

                override fun onScanFailed(errorCode: Int) {
                    Log.e(TAG, "Scan fallito: $errorCode")
                }
            }

            scanner.startScan(listOf(filter), settings, scanCallback)
            isScanning = true
            Log.d(TAG, "Scanning avviato")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Errore avvio scanning: ${e.message}")
            return false
        }
    }

    private fun stopScanning() {
        if (!isScanning) return
        val scanner = bluetoothAdapter?.bluetoothLeScanner
        scanCallback?.let { scanner?.stopScan(it) }
        scanCallback = null
        isScanning = false
        Log.d(TAG, "Scanning fermato")
    }

    fun cleanup() {
        stopAdvertising()
        stopScanning()
    }
}
