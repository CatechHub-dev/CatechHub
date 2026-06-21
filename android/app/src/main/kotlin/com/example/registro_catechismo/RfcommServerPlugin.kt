package com.delelimed.catechhub

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothServerSocket
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.util.UUID
import java.util.concurrent.LinkedBlockingQueue

class RfcommServerPlugin(private val engine: FlutterEngine) {
    companion object {
        private const val TAG = "RfcommServer"
        val SERVICE_UUID = UUID.fromString("6e400001-b5a3-f393-e0a9-e50e24dcca9e")
        const val METHOD_CHANNEL = "com.delelimed.catechhub/rfcomm_server"
        const val EVENT_CHANNEL = "com.delelimed.catechhub/rfcomm_server_events"
        private const val MSG_DELIMITER = '\n'
        private const val BUFFER_SIZE = 65536
    }

    private var serverSocket: BluetoothServerSocket? = null
    @Volatile private var isRunning = false

    // Persistent sync connection
    @Volatile private var syncSocket: BluetoothSocket? = null
    private var syncInput: InputStream? = null
    private var syncOutput: OutputStream? = null
    private val responseQueue = LinkedBlockingQueue<String>()

    @Volatile private var responseData: ByteArray? = null
    private var eventSink: EventChannel.EventSink? = null

    // Classic Bluetooth discovery
    private var discoveryReceiver: BroadcastReceiver? = null
    @Volatile private var isDiscovering = false
    private val discoveredDevices = mutableMapOf<String, BluetoothDevice>()
    private var discoveryEventSink: EventChannel.EventSink? = null

    private val methodHandler = MethodChannel.MethodCallHandler { call, result ->
        when (call.method) {
            "startServer" -> {
                val response = call.argument<String>("response") ?: ""
                responseData = response.toByteArray(Charsets.UTF_8)
                result.success(startServer())
            }
            "stopServer" -> {
                stopServer()
                result.success(null)
            }
            "getBondedDevices" -> {
                val list = getBondedDevices()
                result.success(list)
            }
            "connectAndExchange" -> {
                val address = call.argument<String>("address") ?: ""
                val payload = call.argument<String>("payload") ?: ""
                Thread({
                    try {
                        val response = connectAndExchange(address, payload)
                        result.success(response)
                    } catch (e: Exception) {
                        result.error("RFCOMM_ERROR", e.message, null)
                    }
                }, "rfcomm-client").start()
            }
            "connectAndExchangeKeys" -> {
                val address = call.argument<String>("address") ?: ""
                val payload = call.argument<String>("payload") ?: ""
                Thread({
                    try {
                        val response = connectAndExchangeKeys(address, payload)
                        result.success(response)
                    } catch (e: Exception) {
                        result.error("RFCOMM_ERROR", e.message, null)
                    }
                }, "rfcomm-client").start()
            }
            "connectForSync" -> {
                val address = call.argument<String>("address") ?: ""
                Thread({
                    try {
                        connectForSync(address)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("RFCOMM_ERROR", e.message, null)
                    }
                }, "rfcomm-sync-connect").start()
            }
            "sendData" -> {
                val data = call.argument<String>("data") ?: ""
                Thread({
                    try {
                        sendData(data)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("RFCOMM_ERROR", e.message, null)
                    }
                }, "rfcomm-send").start()
            }
            "respondToSync" -> {
                val response = call.argument<String>("response") ?: ""
                Thread({
                    try {
                        respondToSync(response)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("RFCOMM_ERROR", e.message, null)
                    }
                }, "rfcomm-respond").start()
            }
            "startClassicDiscovery" -> {
                result.success(startClassicDiscovery())
            }
            "stopClassicDiscovery" -> {
                stopClassicDiscovery()
                result.success(null)
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

    private val discoveryEventHandler = object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
            discoveryEventSink = events
        }

        override fun onCancel(arguments: Any?) {
            discoveryEventSink = null
        }
    }

    fun register() {
        MethodChannel(engine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler(methodHandler)

        EventChannel(engine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(eventHandler)

        EventChannel(engine.dartExecutor.binaryMessenger, "com.delelimed.catechhub/rfcomm_discovery_events")
            .setStreamHandler(discoveryEventHandler)
    }

    private fun startServer(): Boolean {
        if (isRunning) return true
        val adapter = BluetoothAdapter.getDefaultAdapter() ?: return false
        return try {
            serverSocket = adapter.listenUsingRfcommWithServiceRecord("CatechHub", SERVICE_UUID)
            isRunning = true
            Thread({ acceptLoop() }, "rfcomm-server").start()
            Log.d(TAG, "Server RFCOMM avviato")
            true
        } catch (e: SecurityException) {
            Log.e(TAG, "Permesso negato: ${e.message}"); false
        } catch (e: IOException) {
            Log.e(TAG, "Errore avvio server: ${e.message}"); false
        }
    }

    private fun acceptLoop() {
        while (isRunning) {
            try {
                serverSocket?.accept()?.let { socket ->
                    Log.d(TAG, "Connessione RFCOMM da ${socket.remoteDevice.address}")
                    if (syncSocket == null) {
                        syncSocket = socket
                        handlePersistentConnection(socket)
                    } else {
                        // Already have a sync connection, handle as one-shot
                        handleOneShotConnection(socket)
                    }
                }
            } catch (e: IOException) {
                if (isRunning) Log.e(TAG, "Accept error: ${e.message}")
            }
        }
    }

    private fun handleOneShotConnection(socket: BluetoothSocket) {
        try {
            val input = socket.inputStream
            val output = socket.outputStream
            val buffer = ByteArray(4096)
            val bytes = input.read(buffer)
            if (bytes > 0) {
                val received = ByteArray(bytes)
                System.arraycopy(buffer, 0, received, 0, bytes)
                Log.d(TAG, "Ricevuti $bytes bytes via RFCOMM (one-shot)")
                eventSink?.success(received)
                responseData?.let { response ->
                    output.write(response)
                    output.flush()
                }
            }
        } catch (e: IOException) {
            Log.e(TAG, "Errore one-shot: ${e.message}")
        } finally {
            try { socket.close() } catch (_: IOException) {}
        }
    }

    private fun handlePersistentConnection(socket: BluetoothSocket) {
        try {
            syncInput = socket.inputStream
            syncOutput = socket.outputStream
            val reader = Thread({
                try {
                    val buffer = ByteArray(BUFFER_SIZE)
                    val input = syncInput ?: return@Thread
                    while (isRunning && socket.isConnected) {
                        val bytes = input.read(buffer)
                        if (bytes > 0) {
                            val received = ByteArray(bytes)
                            System.arraycopy(buffer, 0, received, 0, bytes)
                            val message = String(received, Charsets.UTF_8)
                            Log.d(TAG, "Ricevuti $bytes bytes sync: ${message.take(100)}")
                            eventSink?.success(received)
                        } else if (bytes == -1) {
                            break
                        }
                    }
                } catch (e: IOException) {
                    Log.d(TAG, "Sync connection chiusa: ${e.message}")
                } finally {
                    closeSyncSocket()
                }
            }, "rfcomm-sync-reader")
            reader.start()
        } catch (e: Exception) {
            Log.e(TAG, "Errore setup sync: ${e.message}")
            closeSyncSocket()
        }
    }

    private fun closeSyncSocket() {
        try { syncInput?.close() } catch (_: IOException) {}
        try { syncOutput?.close() } catch (_: IOException) {}
        try { syncSocket?.close() } catch (_: IOException) {}
        syncSocket = null
        syncInput = null
        syncOutput = null
        Log.d(TAG, "Sync socket chiuso")
    }

    private fun connectForSync(address: String) {
        val adapter = BluetoothAdapter.getDefaultAdapter()
            ?: throw IOException("Bluetooth non disponibile")
        val device = adapter.getRemoteDevice(address)
        adapter.cancelDiscovery()

        // Close any existing sync connection
        closeSyncSocket()

        val socket = device.createRfcommSocketToServiceRecord(SERVICE_UUID)
        socket.connect()
        syncSocket = socket
        Log.d(TAG, "Connesso per sync a $address")

        handlePersistentConnection(socket)
    }

    @Synchronized
    private fun sendData(data: String) {
        val output = syncOutput ?: throw IOException("Sync non connesso")
        val bytes = data.toByteArray(Charsets.UTF_8)
        output.write(bytes)
        output.flush()
        Log.d(TAG, "Inviato ${bytes.size} bytes sync")
    }

    @Synchronized
    private fun respondToSync(response: String) {
        val output = syncOutput ?: throw IOException("Sync non connesso")
        val bytes = response.toByteArray(Charsets.UTF_8)
        output.write(bytes)
        output.flush()
        Log.d(TAG, "Risposta sync inviata ${bytes.size} bytes")
    }

    private fun stopServer() {
        isRunning = false
        closeSyncSocket()
        try { serverSocket?.close() } catch (_: IOException) {}
        serverSocket = null
        eventSink = null
        Log.d(TAG, "Server RFCOMM fermato")
    }

    private fun getBondedDevices(): List<Map<String, String>> {
        val adapter = BluetoothAdapter.getDefaultAdapter()
            ?: return emptyList()
        return adapter.bondedDevices.map { device ->
            mapOf(
                "address" to (device.address ?: ""),
                "name" to (device.name ?: device.address ?: "Sconosciuto")
            )
        }
    }

    private fun connectAndExchange(address: String, payload: String): ByteArray {
        val adapter = BluetoothAdapter.getDefaultAdapter()
            ?: throw IOException("Bluetooth non disponibile")
        val device = adapter.getRemoteDevice(address)
        adapter.cancelDiscovery()
        val socket = device.createRfcommSocketToServiceRecord(SERVICE_UUID)
        try {
            socket.connect()
            val payloadBytes = payload.toByteArray(Charsets.UTF_8)
            socket.outputStream.write(payloadBytes)
            socket.outputStream.flush()
            Log.d(TAG, "Inviato payload ${payloadBytes.size} bytes a $address")
            val buffer = ByteArray(4096)
            val bytes = socket.inputStream.read(buffer)
            if (bytes <= 0) throw IOException("Nessuna risposta")
            val response = ByteArray(bytes)
            System.arraycopy(buffer, 0, response, 0, bytes)
            Log.d(TAG, "Ricevuta risposta ${response.size} bytes da $address")
            return response
        } finally {
            try { socket.close() } catch (_: IOException) {}
        }
    }

    private fun connectAndExchangeKeys(address: String, payload: String): ByteArray {
        val adapter = BluetoothAdapter.getDefaultAdapter()
            ?: throw IOException("Bluetooth non disponibile")
        val device = adapter.getRemoteDevice(address)
        adapter.cancelDiscovery()

        // Use insecure RFCOMM to avoid system pairing dialog
        val socket = device.createInsecureRfcommSocketToServiceRecord(SERVICE_UUID)
        try {
            socket.connect()
            val payloadBytes = payload.toByteArray(Charsets.UTF_8)
            socket.outputStream.write(payloadBytes)
            socket.outputStream.flush()
            Log.d(TAG, "Inviato payload ${payloadBytes.size} bytes a $address")
            val buffer = ByteArray(4096)
            val bytes = socket.inputStream.read(buffer)
            if (bytes <= 0) throw IOException("Nessuna risposta")
            val response = ByteArray(bytes)
            System.arraycopy(buffer, 0, response, 0, bytes)
            Log.d(TAG, "Ricevuta risposta ${response.size} bytes da $address")
            return response
        } finally {
            try { socket.close() } catch (_: IOException) {}
        }
    }

    private fun startClassicDiscovery(): Boolean {
        val adapter = BluetoothAdapter.getDefaultAdapter() ?: return false
        if (isDiscovering) return true
        if (!adapter.isEnabled) {
            Log.e(TAG, "Bluetooth non abilitato per discovery classico")
            return false
        }

        discoveredDevices.clear()

        discoveryReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val action = intent?.action
                when (action) {
                    BluetoothDevice.ACTION_FOUND -> {
                        val device = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
                        device?.let {
                            if (!discoveredDevices.containsKey(it.address)) {
                                discoveredDevices[it.address] = it
                                // Check if device has our service UUID via SDP
                                checkServiceOnDevice(it)
                            }
                        }
                    }
                    BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> {
                        Log.d(TAG, "Discovery classico completato. Trovati ${discoveredDevices.size} dispositivi")
                        isDiscovering = false
                    }
                }
            }
        }

        val filter = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_FOUND)
            addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
        }
        engine.activity?.registerReceiver(discoveryReceiver, filter)

        adapter.cancelDiscovery()
        val started = adapter.startDiscovery()
        if (started) {
            isDiscovering = true
            Log.d(TAG, "Discovery classico avviato")
        }
        return started
    }

    private fun checkServiceOnDevice(device: BluetoothDevice) {
        Thread({
            try {
                // Try to fetch SDP records for our UUID using insecure socket to avoid pairing dialog
                val socket = device.createInsecureRfcommSocketToServiceRecord(SERVICE_UUID)
                socket.connect()
                socket.close()
                // If connection succeeds, device has our service
                Log.d(TAG, "Dispositivo con servizio CatechHub trovato: ${device.name} (${device.address})")
                discoveryEventSink?.success(mapOf(
                    "address" to device.address ?: "",
                    "name" to device.name ?: device.address ?: "Sconosciuto"
                ))
            } catch (e: IOException) {
                // Device doesn't have our service, ignore
                Log.d(TAG, "Dispositivo ${device.address} non ha il servizio CatechHub: ${e.message}")
            }
        }, "sdp-check-${device.address}").start()
    }

    private fun stopClassicDiscovery() {
        if (!isDiscovering) return
        val adapter = BluetoothAdapter.getDefaultAdapter()
        adapter?.cancelDiscovery()
        discoveryReceiver?.let { receiver ->
            try { engine.activity?.unregisterReceiver(receiver) } catch (_: Exception) {}
        }
        discoveryReceiver = null
        isDiscovering = false
        Log.d(TAG, "Discovery classico fermato")
    }
}
