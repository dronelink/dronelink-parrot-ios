//
//  ParrotAdapters.swift
//  DronelinkParrot
//
//  Created by Jim McAndrew on 11/20/19.
//  Copyright © 2019 Dronelink. All rights reserved.
//
import DronelinkCore
import GroundSdk

public class ParrotDroneAdapter: DroneAdapter {
    public var remoteControllers: [RemoteControllerAdapter]?
    
    public let drone: Drone
    public let remoteControl: RemoteControl?
    
    private var telemetry: DatedValue<ParrotTelemetry>? { DronelinkParrot.telemetryProvider?.telemetry }
    
    private var flightControllerRef: Ref<ManualCopterPilotingItf>?
    private var returnHomeControllerRef: Ref<ReturnHomePilotingItf>?
    private var copilotControllerRef: Ref<CopilotDesc.ApiProtocol>?
    private var geoFenceRef: Ref<GeofenceDesc.ApiProtocol>?
    private var mainCameraRef: Ref<MainCameraDesc.ApiProtocol>?
    private var thermalCameraRef: Ref<ThermalCameraDesc.ApiProtocol>?
    private var gimbalRef: Ref<GimbalDesc.ApiProtocol>?
    
    private var _flightController: ManualCopterPilotingItf?
    private var _returnHomeController: ReturnHomePilotingItf?
    private var _copilotController: Copilot?
    private var _geoFence: Geofence?
    private var mainCamera: ParrotCameraAdapter?
    private var thermalCamera: ParrotCameraAdapter?
    private var gimbal: ParrotGimbalAdapter?
    
    public var flightController: ManualCopterPilotingItf? { _flightController }
    public var copilotController: Copilot? { _copilotController }
    public var returnHomeController: ReturnHomePilotingItf? { _returnHomeController }
    public var geoFence: Geofence? { _geoFence }

    public init(drone: Drone, remoteControl: RemoteControl?) {
        self.drone = drone
        self.remoteControl = remoteControl
        
        flightControllerRef = drone.getPilotingItf(PilotingItfs.manualCopter) { [weak self] itf in
            self?._flightController = itf
        }
        
        returnHomeControllerRef = drone.getPilotingItf(PilotingItfs.returnHome) { [weak self] itf in
            self?._returnHomeController = itf
        }
        
        copilotControllerRef = remoteControl?.getPeripheral(Peripherals.copilot) { [weak self] copilot in
            self?._copilotController = copilot
        }
        
        geoFenceRef = drone.getPeripheral(Peripherals.geofence) { [weak self] geoFence in
            self?._geoFence = geoFence
        }
        
        mainCameraRef = drone.getPeripheral(Peripherals.mainCamera) { [weak self] mainCamera in
            if let mainCamera = mainCamera {
                self?.mainCamera = ParrotCameraAdapter(camera: mainCamera, model: drone.model.description)
            }
            else {
                self?.mainCamera = nil
            }
        }
        
        thermalCameraRef = drone.getPeripheral(Peripherals.thermalCamera) { [weak self] thermalCamera in
            if let thermalCamera = thermalCamera {
                self?.thermalCamera = ParrotCameraAdapter(camera: thermalCamera, model: drone.model.description)
            }
            else {
                self?.thermalCamera = nil
            }
        }
        
        gimbalRef = drone.getPeripheral(Peripherals.gimbal) { [weak self] gimbal in
            if let gimbal = gimbal {
                self?.gimbal = ParrotGimbalAdapter(gimbal: gimbal)
            }
            else {
                self?.gimbal = nil
            }
        }
    }
    
    public func remoteController(channel: UInt) -> RemoteControllerAdapter? { remoteControllers?[safeIndex: Int(channel)] }
    
    public var cameras: [CameraAdapter]? {
        if let mainCamera = mainCamera {
            if let thermalCamera = thermalCamera {
                return [mainCamera, thermalCamera]
            }
            return [mainCamera]
        }
        else if let thermalCamera = thermalCamera {
            return [thermalCamera]
        }
        return nil
    }
    
    public func camera(channel: UInt) -> CameraAdapter? { cameras?[safeIndex: Int(channel)] }
    
    public var gimbals: [GimbalAdapter]? {
        if let gimbal = gimbal {
            return [gimbal]
        }
        return nil
    }
    
    public func gimbal(channel: UInt) -> GimbalAdapter? { gimbals?[safeIndex: Int(channel)] }

    public func send(velocityCommand: Kernel.VelocityDroneCommand?) {
        guard let velocityCommand = velocityCommand else {
            sendResetVelocityCommand()
            return
        }
        
        guard
            let flightController = flightController,
            let telemetry = telemetry?.value
        else {
            return
        }
        
        //offset the velocity vector by the heading of the drone
        let orientation = telemetry.droneMissionOrientation
        var horizontal = velocityCommand.velocity.horizontal
        horizontal = Kernel.Vector2(direction: horizontal.direction - orientation.yaw, magnitude: horizontal.magnitude)
        let pitch = -Int(max(-1, min(1, horizontal.x / DronelinkParrot.maxVelocityHorizontal)) * 100)
        let roll = Int(max(-1, min(1, horizontal.y / DronelinkParrot.maxVelocityHorizontal)) * 100)
        let verticalSpeed = Int(max(-1, min(1, velocityCommand.velocity.vertical / flightController.maxVerticalSpeed.value)) * 100)
        var rotationalSpeed = 0.0
        if let heading = velocityCommand.heading {
            rotationalSpeed = heading.angleDifferenceSigned(angle: orientation.yaw).convertRadiansToDegrees
        }
        else {
            rotationalSpeed = velocityCommand.velocity.rotational.convertRadiansToDegrees
        }
        rotationalSpeed = max(-1, min(1, rotationalSpeed / flightController.maxYawRotationSpeed.max)) * 100
        
        flightController.set(pitch: pitch)
        flightController.set(roll: roll)
        flightController.set(verticalSpeed: verticalSpeed)
        flightController.set(yawRotationSpeed: Int(rotationalSpeed))
    }
    
    public func send(remoteControllerSticksCommand: Kernel.RemoteControllerSticksDroneCommand?) {
        guard let remoteControllerSticksCommand = remoteControllerSticksCommand else {
            sendResetVelocityCommand()
            return
        }
        
        flightController?.set(pitch: Int(remoteControllerSticksCommand.rightStick.y * 100))
        flightController?.set(roll: Int(remoteControllerSticksCommand.rightStick.x * 100))
        flightController?.set(verticalSpeed: Int(remoteControllerSticksCommand.leftStick.y * 100))
        flightController?.set(yawRotationSpeed: Int(remoteControllerSticksCommand.leftStick.x * 100))
    }

    public func startGoHome(finished: CommandFinished?) {
        guard let returnHomeController = returnHomeController else {
            finished?("ParrotDroneAdapter.startGoHome.unavailable".localized)
            return
        }

        finished?(returnHomeController.activate() ? nil : "ParrotDroneAdapter.startGoHome.failed")
    }

    public func startLanding(finished: CommandFinished?) {
        guard let flightController = flightController else {
            finished?("ParrotDroneAdapter.startLanding.unavailable".localized)
            return
        }

        flightController.land()
        finished?(nil)
    }
    
    public func sendResetVelocityCommand() {
        flightController?.hover()
    }
}

public class ParrotCameraAdapter: CameraAdapter {
    public let camera: Camera
    public let model: String?
    
    public init(camera: Camera, model: String?) {
        self.camera = camera
        self.model = model
    }
    
    public var index: UInt { 0 }
}


extension ParrotCameraAdapter: CameraStateAdapter {
    public var isBusy: Bool { false }
    public var isCapturing: Bool { isCapturingVideo || isCapturingPhotoInterval }
    public var isCapturingPhotoInterval: Bool {
        switch camera.modeSetting.mode {
        case .recording: return false
        case .photo:
            switch camera.photoState.functionState {
            case .unavailable, .stopped, .errorInsufficientStorageSpace, .errorInternal: return false
            case .started, .stopping: return true
            @unknown default: return false
            }
            
        @unknown default: return false
        }
    }
    public var isCapturingVideo: Bool {
        switch camera.modeSetting.mode {
        case .recording:
            switch camera.recordingState.functionState {
            case .unavailable, .stopped, .stoppedForReconfiguration, .errorInsufficientStorageSpace, .errorInsufficientStorageSpeed, .errorInternal: return false
            case .starting, .started, .stopping: return true
            @unknown default: return false
            }
            
        case .photo: return false
        @unknown default: return false
        }
    }
    public var isCapturingContinuous: Bool { isCapturingVideo || isCapturingPhotoInterval }
    public var isSDCardInserted: Bool { return true }
    public var mode: Kernel.CameraMode { camera.modeSetting.mode.kernelValue }
    public var photoMode: Kernel.CameraPhotoMode? { camera.photoSettings.mode.kernelValue }
    public var burstCount: Kernel.CameraBurstCount? { camera.photoSettings.burstValue.kernelValue }
    public var aebCount: Kernel.CameraAEBCount? { camera.photoSettings.bracketingValue.kernelValue }
    public var photoInterval: Int? { Int(camera.photoSettings.timelapseCaptureInterval) }
    public var currentVideoTime: Double? { camera.recordingState.functionState == .started ? camera.recordingState.getDuration() : nil }
    public var exposureCompensation: Kernel.CameraExposureCompensation { camera.exposureCompensationSetting.value.kernelValue }
    public var iso: Kernel.CameraISO { camera.exposureSettings.manualIsoSensitivity.kernelValue }
    public var shutterSpeed: Kernel.CameraShutterSpeed { camera.exposureSettings.manualShutterSpeed.kernelValue }
    public var aperture: Kernel.CameraAperture { .unknown }
    public var whiteBalancePreset: Kernel.CameraWhiteBalancePreset { camera.whiteBalanceSettings.mode.kernelValue }
    public var lensDetails: String? { nil }
}

public class ParrotGimbalAdapter: GimbalAdapter {
    private var telemetry: DatedValue<ParrotTelemetry>? { DronelinkParrot.telemetryProvider?.telemetry }
    
    public let gimbal: Gimbal
    
    public init(gimbal: Gimbal) {
        self.gimbal = gimbal
    }
    
    public var index: UInt { 0 }
    
    public func send(velocityCommand: Kernel.VelocityGimbalCommand, mode: Kernel.GimbalMode) {
        gimbal.control(
            mode: .velocity,
            yaw: max(-1, min(1, velocityCommand.velocity.yaw.convertRadiansToDegrees / (gimbal.maxSpeedSettings[GimbalAxis.yaw]?.value ?? 1))),
            pitch: max(-1, min(1, velocityCommand.velocity.pitch.convertRadiansToDegrees / (gimbal.maxSpeedSettings[GimbalAxis.pitch]?.value ?? 1))),
            roll: max(-1, min(1, velocityCommand.velocity.roll.convertRadiansToDegrees / (gimbal.maxSpeedSettings[GimbalAxis.roll]?.value ?? 1))))
    }
    
    public func reset() {
        gimbal.control(mode: .position, yaw: 0, pitch: 0, roll: 0)
    }
    
    public func fineTune(roll: Double) {}
}

extension ParrotGimbalAdapter: GimbalStateAdapter {
    public var mode: Kernel.GimbalMode { .yawFollow }
    
    public var orientation: Kernel.Orientation3 {
        let gimbalMissionOrientation = telemetry?.value.gimbalMissionOrientation
        return gimbalMissionOrientation ?? Kernel.Orientation3()
    }
}
