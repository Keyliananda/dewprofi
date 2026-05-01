# dewprofi Project Context

## Govee Hygrometer Notes

- Target device candidate: Govee H5075 Bluetooth thermo-hygrometer.
- Official Govee cloud/OpenAPI is not the preferred path for H5075 because the device is Bluetooth-only.
- Passive BLE advertising can provide current temperature, humidity, and often battery level locally without a Govee account.
- Historical data is likely retrievable over an active BLE/GATT connection, similar to how the Govee Home app syncs device history before CSV export.
- Community references show this is technically feasible, though not officially documented by Govee:
  - Heckie75/govee-h5075-thermo-hygrometer: reads device information, current values, configuration, and historical data via BLE.
  - wcbonner/GoveeBTTempLogger: documents Govee BLE logging and notes many devices store around 20 days of history.
  - Thrilleratplay/GoveeWatcher: documents passive BLE advertisement decoding for H5075 current readings.
- Best architecture for dewprofi: a local BLE collector that syncs live values and device history into the app database.
- Android/native, Raspberry Pi, or desktop collector are practical targets. Browser-only Web Bluetooth is likely too limited, especially on iOS.

## Implementation Direction

Start with a local collector prototype:

1. Scan for H5075 devices by BLE advertisement/name.
2. Decode passive advertisements for live readings.
3. Connect via GATT only when history sync is needed.
4. Store normalized readings with timestamp, temperature, relative humidity, battery, source device, and sync metadata.
5. Keep raw BLE payload samples during early development for debugging parser differences across firmware versions.
