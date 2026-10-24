//
//  SensorView.swift
//  Lets the user scan for, connect to, and monitor the Arduino BLE
//  temperature sensor. The one animated moment in the whole app lives
//  here: concentric rings pulse outward from the sensor icon while
//  scanning, like a radar sweep, and settle the instant a device
//  connects. Nothing else in the app animates on its own.
//

import SwiftUI
import CoreBluetooth

struct SensorView: View {
    @EnvironmentObject private var bluetoothManager: BluetoothManager
    @EnvironmentObject private var weatherService: WeatherService

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Spacer()
                        RadarBeacon(state: bluetoothManager.state)
                            .frame(height: 120)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 8)
                }

                Section("Status") {
                    HStack {
                        Text("Connection")
                        Spacer()
                        statusLabel
                    }
                    if let temp = bluetoothManager.latestTemperatureC {
                        HStack {
                            Text("Live Reading")
                            Spacer()
                            Text(String(format: "%.1f°C", temp))
                                .font(Theme.readoutFont(17))
                                .foregroundStyle(Theme.ambientColor(temp))
                        }
                    }
                    if let error = bluetoothManager.errorMessage {
                        Text(error).font(Theme.labelFont(.caption)).foregroundStyle(Theme.blazeRed)
                    }
                }

                if case .connected = bluetoothManager.state {
                    Section {
                        Button("Disconnect", role: .destructive) {
                            bluetoothManager.disconnect()
                        }
                    }
                } else {
                    Section("Nearby Sensors") {
                        if bluetoothManager.discoveredPeripherals.isEmpty {
                            HStack {
                                Text("Scanning for devices…")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if case .scanning = bluetoothManager.state {
                                    ProgressView()
                                }
                            }
                        }
                        ForEach(bluetoothManager.discoveredPeripherals, id: \.identifier) { peripheral in
                            Button {
                                bluetoothManager.connect(to: peripheral)
                            } label: {
                                HStack {
                                    Image(systemName: "cpu")
                                        .foregroundStyle(Theme.atmosphereTeal)
                                    Text(peripheral.name ?? "Unknown Sensor")
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Section {
                        Button("Scan for Sensors") {
                            bluetoothManager.startScanning()
                        }
                        .tint(Theme.atmosphereTeal)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(ThermalBackground(temperature: weatherService.current?.temperatureC))
            .navigationTitle("Sensor")
            .onAppear { bluetoothManager.startScanning() }
            .onDisappear { bluetoothManager.stopScanning() }
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch bluetoothManager.state {
        case .connected(let name):
            Label(name, systemImage: "checkmark.circle.fill").foregroundStyle(Theme.atmosphereTeal)
        case .scanning:
            Label("Scanning…", systemImage: "dot.radiowaves.left.and.right").foregroundStyle(Theme.heatAmber)
        case .connecting:
            Label("Connecting…", systemImage: "hourglass").foregroundStyle(Theme.heatAmber)
        case .poweredOff:
            Label("Bluetooth Off", systemImage: "bolt.slash").foregroundStyle(Theme.blazeRed)
        case .unauthorized:
            Label("Not Authorized", systemImage: "lock").foregroundStyle(Theme.blazeRed)
        case .disconnected:
            Label("Not Connected", systemImage: "circle").foregroundStyle(.secondary)
        }
    }
}

/// Concentric rings pulse outward from a central sensor glyph while
/// scanning or connecting; the rings still and fade once a device is
/// connected. This is the app's single orchestrated motion moment.
struct RadarBeacon: View {
    let state: BluetoothManager.ConnectionState
    @State private var animate = false

    private var isActive: Bool {
        switch state {
        case .scanning, .connecting: return true
        default: return false
        }
    }

    private var centerColor: Color {
        switch state {
        case .connected: return Theme.atmosphereTeal
        case .poweredOff, .unauthorized: return Theme.blazeRed
        default: return Theme.heatAmber
        }
    }

    var body: some View {
        ZStack {
            if isActive {
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(centerColor.opacity(0.35), lineWidth: 2)
                        .scaleEffect(animate ? 1.6 : 0.4)
                        .opacity(animate ? 0 : 0.6)
                        .animation(
                            .easeOut(duration: 1.8)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.5),
                            value: animate
                        )
                }
            }

            Circle()
                .fill(centerColor)
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: state.isConnected ? "checkmark" : "dot.radiowaves.left.and.right")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                )
                .shadow(color: centerColor.opacity(0.4), radius: 8)
        }
        .frame(width: 120, height: 120)
        .onAppear { animate = true }
    }
}

private extension BluetoothManager.ConnectionState {
    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

#Preview {
    SensorView()
        .environmentObject(BluetoothManager())
        .environmentObject(WeatherService())
}
