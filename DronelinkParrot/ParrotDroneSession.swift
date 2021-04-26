//
//  ParrotDroneSession.swift
//  DronelinkParrot
//
//  Created by Jim McAndrew on 11/20/19.
//  Copyright © 2019 Dronelink. All rights reserved.
//
import Foundation
import os
import DronelinkCore
import GroundSdk
import CoreLocation

public class ParrotDroneSession: NSObject {
    internal static let log = OSLog(subsystem: "DronelinkParrot", category: "ParrotDroneSession")
    
    public let adapter: ParrotDroneAdapter
    
    private var telemetry: DatedValue<ParrotTelemetry>? { DronelinkParrot.telemetryProvider?.telemetry }
    
    private let _opened = Date()
    private var _closed = false
    private var _id = UUID().uuidString
    private var _initialized = false
    private var _located = false
    private var _lastKnownGroundLocation: CLLocation?
    
    private let delegates = MulticastDelegate<DroneSessionDelegate>()
    private let droneCommands = CommandQueue()
    private let cameraCommands = MultiChannelCommandQueue()
    private let gimbalCommands = MultiChannelCommandQueue()
    
    private var deviceStateRef: Ref<DeviceState>?
    private var flyingIndicatorsRef: Ref<FlyingIndicators>?
    private var gpsRef: Ref<Gps>?
    private var compassRef: Ref<Compass>?
    private var altimeterRef: Ref<Altimeter>?
    private var speedometerRef: Ref<Speedometer>?
    private var attitudeIndicatorRef: Ref<AttitudeIndicator>?
    private var geofenceRef: Ref<Geofence>?
    private var alarmsRef: Ref<Alarms>?
    private var radioRef: Ref<Radio>?
    private var pilotingStateRef: Ref<ManualCopterPilotingItf>?
    private var batteryInfoRef: Ref<BatteryInfo>?
    private var remoteControllerBatteryInfoRef: Ref<BatteryInfo>?
    
    private var _deviceState: DatedValue<DeviceState>?
    private var _flyingIndicators: DatedValue<FlyingIndicators>?
    private var _alarms: DatedValue<Alarms>?
    private var _gps: DatedValue<Gps>?
    private var _compass: DatedValue<Compass>?
    private var _altimeter: DatedValue<Altimeter>?
    private var _speedometer: DatedValue<Speedometer>?
    private var _attitudeIndicator: DatedValue<AttitudeIndicator>?
    private var _radio: DatedValue<Radio>?
    private var _batteryInfo: DatedValue<BatteryInfo>?
    private var _remoteControllerBatteryInfo: DatedValue<BatteryInfo>?
    
    public var flyingIndicators: DatedValue<FlyingIndicators>? { _flyingIndicators }
    public var batteryInfo: DatedValue<BatteryInfo>? { _batteryInfo }
    public var remoteBatteryInfo: DatedValue<BatteryInfo>? { _remoteControllerBatteryInfo }
    
    public init(drone: Drone, remoteControl: RemoteControl?) {
        adapter = ParrotDroneAdapter(drone: drone, remoteControl: remoteControl)
        super.init()
        adapter.session = self
        initDrone()
        initRemoteController()
        Thread.detachNewThread(self.execute)
    }
    
    private func initDrone() {
        os_log(.info, log: ParrotDroneSession.log, "Drone session opened")
        
        deviceStateRef = adapter.drone.getState { [weak self] value in
            guard let value = value else { return }
            self?._deviceState = DatedValue<DeviceState>(value: value)
        }
        
        flyingIndicatorsRef = adapter.drone.getInstrument(Instruments.flyingIndicators) { [weak self] value in
            guard let value = value, let session = self else { return }
            let motorsOnPrevious = session._flyingIndicators?.value.areMotorsOn ?? false
            session._flyingIndicators = DatedValue<FlyingIndicators>(value: value)
            if (motorsOnPrevious != value.areMotorsOn) {
                DispatchQueue.global().async {
                    session.delegates.invoke { $0.onMotorsChanged(session: session, value: value.areMotorsOn) }
                }
            }
        }
        
        alarmsRef = adapter.drone.getInstrument(Instruments.alarms) { [weak self] value in
            guard let value = value else { return }
            self?._alarms = DatedValue<Alarms>(value: value)
        }
        
        gpsRef = adapter.drone.getInstrument(Instruments.gps) { [weak self] value in
            guard let value = value else { return }
            self?._gps = DatedValue<Gps>(value: value)
        }
        
        compassRef = adapter.drone.getInstrument(Instruments.compass) { [weak self] value in
            guard let value = value else { return }
            self?._compass = DatedValue<Compass>(value: value)
        }
        
        altimeterRef = adapter.drone.getInstrument(Instruments.altimeter) { [weak self] value in
            guard let value = value else { return }
            self?._altimeter = DatedValue<Altimeter>(value: value)
        }
        
        speedometerRef = adapter.drone.getInstrument(Instruments.speedometer) { [weak self] value in
            guard let value = value else { return }
            self?._speedometer = DatedValue<Speedometer>(value: value)
        }
        
        attitudeIndicatorRef = adapter.drone.getInstrument(Instruments.attitudeIndicator) { [weak self] value in
            guard let value = value else { return }
            self?._attitudeIndicator = DatedValue<AttitudeIndicator>(value: value)
        }
        
        radioRef = adapter.drone.getInstrument(Instruments.radio) { [weak self] value in
            guard let value = value else { return }
            self?._radio = DatedValue<Radio>(value: value)
        }
        
        batteryInfoRef = adapter.drone.getInstrument(Instruments.batteryInfo) { [weak self] value in
            guard let value = value else { return }
            self?._batteryInfo = DatedValue<BatteryInfo>(value: value)
        }
        
        geofenceRef = adapter.drone.getPeripheral(Peripherals.geofence) { [weak self] value in
            guard let value = value else { return }
            value.mode.value = .altitude
        }
        
        _initialized = true
        delegates.invoke { $0.onInitialized(session: self) }
    }
    
    public var remoteControl: RemoteControl? {
        get {
            return adapter.remoteControl
        }
        set {
            adapter.remoteControl = newValue
            initRemoteController()
        }
    }
    
    private func initRemoteController() {
        remoteControllerBatteryInfoRef = adapter.remoteControl?.getInstrument(Instruments.batteryInfo) { [weak self] value in
            guard let value = value else { return }
            self?._remoteControllerBatteryInfo = DatedValue<BatteryInfo>(value: value)
        }
    }
    
    private func execute() {
        while !_closed {
            if let location = location {
                if (!_located) {
                    _located = true
                    DispatchQueue.global().async { [weak self] in
                        guard let session = self else {
                            return
                        }
                        session.delegates.invoke { $0.onLocated(session: session) }
                    }
                }

                if !isFlying {
                    _lastKnownGroundLocation = location
                }
            }
            
            droneCommands.process()
            cameraCommands.process()
            gimbalCommands.process()
            
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        deviceStateRef = nil
        flyingIndicatorsRef = nil
        geofenceRef = nil
        gpsRef = nil
        compassRef = nil
        altimeterRef = nil
        speedometerRef = nil
        attitudeIndicatorRef = nil
        radioRef = nil
        batteryInfoRef = nil
        remoteControllerBatteryInfoRef = nil
        
        os_log(.info, log: ParrotDroneSession.log, "Drone session closed")
    }
    
    internal func sendResetVelocityCommand() {
        adapter.sendResetVelocityCommand()
    }
    
    internal func sendResetGimbalCommands() {
        adapter.gimbals?.forEach {
            if let adapter = $0 as? ParrotGimbalAdapter {
                adapter.gimbal.control(mode: .position, yaw: 0, pitch:  -12, roll: 0)
            }
        }
    }
    
    internal func sendResetCameraCommands() {
        adapter.cameras?.forEach {
            if let adapter = $0 as? ParrotCameraAdapter {
                if adapter.camera.canStopPhotoCapture {
                    adapter.camera.stopPhotoCapture()
                }
                else if adapter.camera.canStopRecord {
                    adapter.camera.stopRecording()
                }
            }
        }
    }
}

extension ParrotDroneSession: DroneSession {
    public var drone: DroneAdapter { adapter }
    public var state: DatedValue<DroneStateAdapter>? { DatedValue(value: self, date: telemetry?.date ?? _deviceState?.date ?? Date()) }
    public var opened: Date { _opened }
    public var id: String { _id }
    public var manufacturer: String { "Parrot" }
    public var serialNumber: String? { adapter.drone.uid }
    public var name: String? { adapter.drone.name }
    public var model: String? { adapter.drone.model.description }
    public var firmwarePackageVersion: String? { nil }
    public var initialized: Bool { _initialized }
    public var located: Bool { _located }
    public var telemetryDelayed: Bool { -(state?.date.timeIntervalSinceNow ?? 0) > 10.0 }
    public var disengageReason: Kernel.Message? {
        if adapter.flightController == nil {
            return Kernel.Message(title: "MissionDisengageReason.drone.control.unavailable.title".localized)
        }
        
        if state?.value == nil {
            return Kernel.Message(title: "MissionDisengageReason.telemetry.unavailable.title".localized)
        }
        
        if telemetryDelayed {
            return Kernel.Message(title: "MissionDisengageReason.telemetry.delayed.title".localized)
        }
        
        return nil
    }
    public var rtkManager: RTKManager? { nil }
    
    public func identify(id: String) { _id = id }
    
    public func add(delegate: DroneSessionDelegate) {
        delegates.add(delegate)
        
        if _initialized {
            delegate.onInitialized(session: self)
        }
        
        if _located {
            delegate.onLocated(session: self)
        }
    }
    
    public func remove(delegate: DroneSessionDelegate) {
        delegates.remove(delegate)
    }
    
    public func add(command: KernelCommand) throws {
        if let command = command as? KernelDroneCommand {
            try droneCommands.add(command: Command(
                id: command.id,
                name: command.type.rawValue,
                execute: { [weak self] finished in
                    self?.commandExecuted(command: command)
                    return self?.execute(droneCommand: command, finished: finished)
                },
                finished: { [weak self] error in
                    self?.commandFinished(command: command, error: error)
                },
                config: command.config
            ))
            return
        }

        if let command = command as? KernelCameraCommand {
            try cameraCommands.add(channel: command.channel, command: Command(
                id: command.id,
                name: command.type.rawValue,
                execute: { [weak self] finished in
                    self?.commandExecuted(command: command)
                    return self?.execute(cameraCommand: command, finished: finished)
                },
                finished: { [weak self] error in
                    self?.commandFinished(command: command, error: error)
                },
                config: command.config
            ))
            return
        }

        if let command = command as? KernelGimbalCommand {
            try gimbalCommands.add(channel: command.channel, command: Command(
                id: command.id,
                name: command.type.rawValue,
                execute: { [weak self] finished in
                    self?.commandExecuted(command: command)
                    return self?.execute(gimbalCommand: command, finished: finished)
                },
                finished: { [weak self] error in
                    self?.commandFinished(command: command, error: error)
                },
                config: command.config
            ))
            return
        }
        
        throw DroneSessionError.commandTypeUnhandled
    }
    
    private func commandExecuted(command: KernelCommand) {
        self.delegates.invoke { $0.onCommandExecuted(session: self, command: command) }
    }
    
    private func commandFinished(command: KernelCommand, error: Error?) {
        self.delegates.invoke { $0.onCommandFinished(session: self, command: command, error: error) }
    }
    
    public func removeCommands() {
        droneCommands.removeAll()
        cameraCommands.removeAll()
        gimbalCommands.removeAll()
    }
    
    public func createControlSession() -> DroneControlSession { ParrotControlSession(droneSession: self) }
    
    public func cameraState(channel: UInt) -> DatedValue<CameraStateAdapter>? {
        guard let camera = adapter.camera(channel: channel) as? ParrotCameraAdapter else { return nil }
        return DatedValue<CameraStateAdapter>(value: camera)
    }
    
    public func gimbalState(channel: UInt) -> DatedValue<GimbalStateAdapter>? {
        return DatedValue<GimbalStateAdapter>(value: ParrotGimbalStateAdapter(orientation: telemetry?.value.gimbalOrientation ?? (adapter.gimbal(channel: channel) as? ParrotGimbalAdapter)?.gimbal.kernelOrientation))
    }
    
    public func remoteControllerState(channel: UInt) -> DatedValue<RemoteControllerStateAdapter>? {
        //TODO
        return nil
    }
    
    public func resetPayloads() {
        sendResetGimbalCommands()
        sendResetCameraCommands()
    }
    
    public func close() {
        _closed = true
    }
}

extension ParrotDroneSession: DroneStateAdapter {
    public var statusMessages: [Kernel.Message]? {
        var messages: [Kernel.Message] = []
        
        if let state = state?.value {
            if state.location == nil {
                messages.append(Kernel.Message(title: "ParrotDroneSession.location.unavailable".localized, level: .warning))
            }
        }
        else {
            messages.append(Kernel.Message(title: "ParrotDroneSession.telemetry.unavailable".localized, level: .danger))
        }
        
        if let state = flyingIndicators?.value.state {
            switch state {
            case .landed:
                switch flyingIndicators?.value.landedState ?? .none {
                case .none, .idle, .waitingUserAction:
                    break
                    
                case .initializing, .motorRamping:
                    
                    break
                }
                break
                
            case .flying:
                switch flyingIndicators?.value.flyingState ?? .none {
                case .none, .waiting, .flying:
                    break
                    
                case .takingOff, .landing:
                    messages.append(Kernel.Message(title: state.display, level: .warning))
                    break
                }
                break
                
            case .emergencyLanding, .emergency:
                messages.append(Kernel.Message(title: state.display, level: .danger))
                break
            }
        }
        
        if let alarms = _alarms?.value {
            for kind in Alarm.Kind.allCases {
                let alarm = alarms.getAlarm(kind: kind)
                switch alarm.level {
                case .notAvailable, .off:
                    break
                    
                case .warning:
                    messages.append(Kernel.Message(title: alarm.description, level: .warning))
                    break
                    
                case .critical:
                    messages.append(Kernel.Message(title: alarm.description, level: .danger))
                    break
                }
            }
        }
        
        return messages
    }
    public var mode: String? {
        guard let state = flyingIndicators?.value.state else {
            return nil
        }
        
        switch state {
        case .landed:
            return flyingIndicators?.value.landedState.display
            
        case .flying:
            return flyingIndicators?.value.flyingState.display
            
        case .emergencyLanding, .emergency:
            return state.display
        }
    }
    public var isFlying: Bool { _flyingIndicators?.value.isFlying ?? false }
    public var location: CLLocation? {
        let instrumentLocation = _gps?.value.fixed ?? false ? _gps?.value.lastKnownLocation : nil
        if let location = telemetry?.value.location {
            if location.coordinate.latitude.isNaN || location.coordinate.longitude.isNaN || (location.coordinate.latitude == 0 && location.coordinate.longitude == 0) {
                return instrumentLocation
            }
            return location
        }
        return instrumentLocation
    }
    public var homeLocation: CLLocation? { adapter.returnHomeController?.homeLocation }
    public var lastKnownGroundLocation: CLLocation? { _lastKnownGroundLocation }
    public var takeoffLocation: CLLocation? { isFlying ? (lastKnownGroundLocation ?? homeLocation) : location }
    public var takeoffAltitude: Double? { telemetry?.value.takeoffAltitude }
    public var course: Double {
        if let telemetry = telemetry?.value {
            return atan2(telemetry.speedNorth, telemetry.speedEast)
        }
        return _speedometer?.value.course ?? 0
    }
    public var horizontalSpeed: Double {
        if let telemetry = telemetry?.value {
            return sqrt(pow(telemetry.speedNorth, 2) + pow(telemetry.speedEast, 2))
        }
        return _speedometer?.value.groundSpeed ?? 0
    }
    public var verticalSpeed: Double {
        if let telemetry = telemetry?.value {
            return telemetry.speedDown == 0 ? 0 : -telemetry.speedDown
        }
        return _speedometer?.value.verticalSpeed ?? 0
    }
    public var altitude: Double {
        if let altitude = telemetry?.value.altitude, !altitude.isNaN {
            return altitude
        }
        return _altimeter?.value.takeoffRelativeAltitude ?? 0
    }
    public var batteryPercent: Double? {
        if let batteryLevel = batteryInfo?.value.batteryLevel {
            return Double(batteryLevel) / 100
        }
        return nil
    }
    public var lowBatteryThreshold: Double? { 0.2 }
    public var obstacleDistance: Double? { nil }
    public var orientation: Kernel.Orientation3 {
        if let droneOrientation = telemetry?.value.droneOrientation {
            return droneOrientation
        }
        
        return _attitudeIndicator?.value.kernelOrientation ?? Kernel.Orientation3()
    }
    public var gpsSatellites: Int? { _gps?.value.satelliteCount }
    public var gpsSignalStrength: Double? {
        guard let gpsSatellites = gpsSatellites else {
            return nil
        }
        
        return min(1.0, Double(gpsSatellites) / 10)
    }
    public var downlinkSignalStrength: Double? { nil }
    public var uplinkSignalStrength: Double? {
        guard let rssi = _radio?.value.rssi, rssi != 0 else {
            return nil
        }
        
        return min(1.0, max(0.0, 1.0 - ((Double(min(-30, max(-80, rssi))) + 30.0) / -50.0)))
    }
}
