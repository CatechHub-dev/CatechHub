# CateREG Locale - Summary

## Goal
Sincronizzazione bidirezionale cifrata end-to-end con associazione solo via Bluetooth classico (RFCOMM), rimuovendo completamente BLE per massima compatibilità.

## Constraints & Preferences
- Sync solo all'avvio, non costante
- Niente QR code, tutto via Bluetooth classico RFCOMM
- Dati cifrati end-to-end (AES-256-GCM + RSA key-wrapping)
- Nome visibile durante discovery = nome profilo salvato
- Associazione: elenco dispositivi già accoppiati (bonded) da Android → selezione → RFCOMM → scambio chiave pubblica → salvataggio
- Sync bidirezionale solo dati nuovi (per timestamp `updatedAt`)
- Massima compatibilità: nessuna dipendenza BLE, solo Bluetooth classico nativo

## Progress
### Done
- **Rimosso `flutter_blue_plus` e `ble_peripheral`** da `pubspec.yaml` (BLE completamente eliminato)
- **Rimosso `flutter_bluetooth_serial: ^0.4.0`** (incompatibile con AGP corrente, usa `jcenter()` deprecato e `kotlin-android` senza Android Gradle plugin)
- **Aggiunto `RfcommServerPlugin.kt`** (nativo Android): `BluetoothServerSocket` in ascolto per RFCOMM, `BluetoothSocket` lato client per `connectAndExchange`, EventChannel per payload in arrivo, `getBondedDevices` per elenco dispositivi già accoppiati
- **Registrato canali nel `MainActivity.kt`**: MethodChannel `com.delelimed.catechhub/rfcomm_server` + EventChannel `com.delelimed.catechhub/rfcomm_server_events`
- **`ble_discovery_service.dart` riscritto**: nessuna dipendenza BLE; `startDiscovery` legge bonded devices da nativo e avvia server RFCOMM; `connectAndExchangeKeys` usa solo `connectAndExchange` via MethodChannel
- **Frammentazione BLE write**: prima della rimozione BLE, aggiunto split payload con header `__LEN__:` e chunk da max 509 bytes con delay 80ms (fixato errore `dataLen: 1024 > max: 509`)
- **`_onWriteRequest` aggiornato**: gestione frammentazione con buffer `_pairBuffer` e `_expectedPairLen`
- **`RfcommServerPlugin.kt`**: aggiunto `getBondedDevices()` che restituisce `List<Map<name, address>>` da `BluetoothAdapter.getBondedDevices()`
- **`ble_pairing_service.dart` pulito**: rimosso `BleDiscoveryEvent`, `matchToPairedDevices`, `scanForPairedDevices`, import `flutter_blue_plus`
- **`ble_sync_service.dart`**: rimosso import `flutter_blue_plus`; `syncWithDevice` ora accetta `String deviceId` invece di `BluetoothDevice`
- **`ble_sync_manager.dart`**: rimosso uso di `rssi`, `device`, `requestConsent` su `BleDiscoveredDevice`
- **`data_share_selection_page.dart`**: rimosso `device.rssi` (non più disponibile)
- **Eliminato `ble_service.dart`** (legacy BLE, non più importato)
- **0 errori `dart analyze`**

### In Progress
- (none)

### Blocked
- **Sync via RFCOMM non ancora implementato**: `BleSyncService` e `BleSyncManager` hanno ancora protocollo basato su BLE. Sync è al momento rotto (i metodi `connectForSync`, `respondToSync`, ecc. lanciano `Exception('Sync non disponibile su Bluetooth classico')`).

## Key Decisions
- **BLE rimosso completamente**: `flutter_blue_plus` e `ble_peripheral` eliminati perché `ble_peripheral` non funziona sul dispositivo reale (GATT server non supportato). Si usa solo Bluetooth classico RFCOMM per massima compatibilità.
- **Solo dispositivi già accoppiati (bonded)**: invece di fare discovery BLE, si mostra la lista dei dispositivi già associati dal sistema Android (`BluetoothAdapter.getBondedDevices()`). L'utente seleziona uno di questi per lo scambio chiavi.
- **RFCOMM nativo via MethodChannel**: non usando `flutter_bluetooth_serial` (0.4.0 incompatibile con AGP corrente), tutto il RFCOMM (client + server) è implementato in Kotlin nativo e richiamato via canali Flutter.
- **Server RFCOMM sempre attivo during discovery**: ogni dispositivo avvia un `BluetoothServerSocket` in ascolto durante `startDiscovery` per accettare connessioni RFCOMM in ingresso.
- **Scambio chiavi via RFCOMM**: l'iniziatore usa `BluetoothSocket.connect()` → scrive payload JSON → legge risposta JSON. Il responder accetta dal server nativo, legge payload, risponde automaticamente con `responseData` (il `_myPairingPayload`).

## Next Steps
1. **Convertire sync a RFCOMM**: `BleSyncService.syncWithDevice` e `BleSyncManager` ancora usano protocollo GATT/BLE. Da riscrivere per usare RFCOMM persistente.
2. **Testare associazione RFCOMM su due dispositivi reali**: verificare che lo scambio chiavi via RFCOMM funzioni correttamente
3. **Rimuovere `ScanResult` e `Subscription` dall'isolate match**: `ble_sync_manager.dart` usa ancora `compute` con `_matchDevicesIsolate` che non ha più senso senza BLE

## Critical Context
- **Service UUID**: `6e400001-b5a3-f393-e0a9-e50e24dcca9e` (usato anche per RFCOMM)
- **Char Read UUID**: `6e400002-b5a3-f393-e0a9-e50e24dcca9e`
- **Char Write UUID**: `6e400003-b5a3-f393-e0a9-e50e24dcca9e`
- **MethodChannel**: `com.delelimed.catechhub/rfcomm_server` (metodi: `startServer`, `stopServer`, `getBondedDevices`, `connectAndExchange`)
- **EventChannel**: `com.delelimed.catechhub/rfcomm_server_events` (payload ricevuti via RFCOMM)
- **`flutter_bluetooth_serial: ^0.4.0` rimosso**: build.gradle chiama `jcenter()` (deprecato) e applica `kotlin-android` senza `com.android.library` → incompatibile con AGP 8+/9+
- **`ble_peripheral: ^2.4.0` rimosso**: `isSupported()` buggy (`bluetoothManager` null prima di `initialize()`), GATT server non supportato sul dispositivo reale
- **RBAC**: `myDevice` = auto-sync, `catechist` = consent
- **Protocollo sync**: SYNC_REQ → SYNC_ACK → SUMMARY → SUMMARY → DATA → DATA → DONE (ancora via BLE, da convertire)

## Relevant Files
- **`lib/core/services/ble_discovery_service.dart`**: riscritto senza BLE; bonding list + RFCOMM solo
- **`android/app/src/main/kotlin/com/.../RfcommServerPlugin.kt`**: nativo Android per RFCOMM (server, client, bonded devices)
- **`android/app/src/main/kotlin/com/.../MainActivity.kt`**: registra `RfcommServerPlugin`
- **`lib/core/services/ble_pairing_service.dart`**: gestione dispositivi associati, chiavi (pulito da BLE)
- **`lib/core/services/ble_sync_manager.dart`**: orchestratore sync (ancora usa protocollo BLE)
- **`lib/core/services/ble_sync_service.dart`**: protocollo sync (da convertire a RFCOMM)
- **`lib/features/data_share/data_share_selection_page.dart`**: UI associazione/sync
- **`lib/core/services/ble_constants.dart`**: UUID (ancora validi per RFCOMM)
- **`pubspec.yaml`**: dipendenze BLE rimosse
