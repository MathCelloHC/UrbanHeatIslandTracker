import Foundation
import CoreBluetooth

enum UHIBLEIdentifiers {
    static let serviceUUID = CBUUID(string: "19B10000-E8F2-537E-4F6C-D104768A1214")
    static let temperatureCharacteristicUUID = CBUUID(string: "19B10001-E8F2-537E-4F6C-D104768A1214")
    static let statusCharacteristicUUID = CBUUID(string: "19B10002-E8F2-537E-4F6C-D104768A1214")
}

@MainActor
final class BluetoothManager: NSObject, ObservableObject {
    enum ConnectionState: Equatable {
        case poweredOff
        case scanning
        case connecting
        case connected(deviceName: String)
        case disconnected
        case unauthorized
    }

    @Published var state: ConnectionState = .disconnected
    @Published var latestTemperatureC: Double?
    @Published var discoveredPeripherals: [CBPeripheral] = []
    @Published var errorMessage: String?

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var statusCharacteristic: CBCharacteristic?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        discoveredPeripherals.removeAll()
        state = .scanning
        centralManager.scanForPeripherals(
            withServices: [UHIBLEIdentifiers.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func stopScanning() {
        centralManager.stopScan()
        if case .scanning = state {
            state = .disconnected
        }
    }

    func connect(to peripheral: CBPeripheral) {
        stopScanning()
        state = .connecting
        connectedPeripheral = peripheral
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect() {
        guard let peripheral = connectedPeripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
    }

    func sendStatusToDisplay(_ text: String) {
        guard let peripheral = connectedPeripheral,
              let characteristic = statusCharacteristic else { return }
        let trimmed = String(text.prefix(16))
        guard let data = trimmed.data(using: .utf8) else { return }
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }
}

extension BluetoothManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                self.state = .disconnected
            case .unauthorized:
                self.state = .unauthorized
            case .poweredOff:
                self.state = .poweredOff
            default:
                self.state = .disconnected
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        Task { @MainActor in
            if !self.discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
                self.discoveredPeripherals.append(peripheral)
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([UHIBLEIdentifiers.serviceUUID])
        Task { @MainActor in
            self.state = .connected(deviceName: peripheral.name ?? "Sensor")
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            self.errorMessage = error?.localizedDescription ?? "Failed to connect."
            self.state = .disconnected
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            self.state = .disconnected
            self.connectedPeripheral = nil
            self.statusCharacteristic = nil
        }
    }
}

extension BluetoothManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == UHIBLEIdentifiers.serviceUUID {
            peripheral.discoverCharacteristics(
                [UHIBLEIdentifiers.temperatureCharacteristicUUID,
                 UHIBLEIdentifiers.statusCharacteristicUUID],
                for: service
            )
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            switch characteristic.uuid {
            case UHIBLEIdentifiers.temperatureCharacteristicUUID:
                peripheral.setNotifyValue(true, for: characteristic)
                peripheral.readValue(for: characteristic)
            case UHIBLEIdentifiers.statusCharacteristicUUID:
                Task { @MainActor in
                    self.statusCharacteristic = characteristic
                }
            default:
                break
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard characteristic.uuid == UHIBLEIdentifiers.temperatureCharacteristicUUID,
              let data = characteristic.value,
              let stringValue = String(data: data, encoding: .utf8),
              let tempValue = Double(stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }

        Task { @MainActor in
            self.latestTemperatureC = tempValue
        }
    }
}
