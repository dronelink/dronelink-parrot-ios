//
//  ParrotAdapters.swift
//  DronelinkParrot
//
//  Created by Jim McAndrew on 11/20/19.
//  Copyright © 2019 Dronelink. All rights reserved.
//
import DronelinkCore
import GroundSdk
import os

public class ParrotDroneAdapter: DroneAdapter {
    private static let log = OSLog(subsystem: "DronelinkParrot", category: "ParrotDroneAdapter")
    
    public let drone: Drone
    public let remoteControl: RemoteControl
    public weak var session: ParrotDroneSession?
    
    private var copilotControllerRef: Ref<CopilotDesc.ApiProtocol>?
    private var manualFlightControllerRef: Ref<ManualCopterPilotingItf>?
    private var guidedFlightControllerRef: Ref<GuidedPilotingItf>?
    private var returnHomeControllerRef: Ref<ReturnHomePilotingItf>?
    private var geoFenceRef: Ref<GeofenceDesc.ApiProtocol>?
    private var mainCamera2Ref: Ref<MainCamera2Desc.ApiProtocol>?
    private var gimbalRef: Ref<GimbalDesc.ApiProtocol>?
    
    private var _copilot: Copilot?
    private var _manualFlightController: ManualCopterPilotingItf?
    private var _guidedFlightController: GuidedPilotingItf?
    private var _returnHomeController: ReturnHomePilotingItf?
    private var _geoFence: Geofence?
    private var mainCamera: ParrotCameraAdapter?
    private var gimbal: ParrotGimbalAdapter?
    
    public var copilot: Copilot? { _copilot }
    public var manualFlightController: ManualCopterPilotingItf? { _manualFlightController }
    public var guidedFlightController: GuidedPilotingItf? { _guidedFlightController }
    public var returnHomeController: ReturnHomePilotingItf? { _returnHomeController }
    public var geoFence: Geofence? { _geoFence }
    
    public init(drone: Drone, remoteControl: RemoteControl) {
        self.drone = drone
        self.remoteControl = remoteControl
        
        copilotControllerRef = remoteControl.getPeripheral(Peripherals.copilot)  { [weak self] copilot in
            self?._copilot = copilot
        }
        
        manualFlightControllerRef = drone.getPilotingItf(PilotingItfs.manualCopter) { [weak self] itf in
            self?._manualFlightController = itf
        }
        
        guidedFlightControllerRef = drone.getPilotingItf(PilotingItfs.guided) { [weak self] itf in
            self?._guidedFlightController = itf
        }
        
        returnHomeControllerRef = drone.getPilotingItf(PilotingItfs.returnHome) { [weak self] itf in
            self?._returnHomeController = itf
        }
        
        geoFenceRef = drone.getPeripheral(Peripherals.geofence) { [weak self] geoFence in
            self?._geoFence = geoFence
        }
        
        
        mainCamera2Ref = drone.getPeripheral(Peripherals.mainCamera2) { [weak self] mainCamera in
            if let mainCamera = mainCamera {
                self?.mainCamera = ParrotCameraAdapter(camera: mainCamera, model: drone.model.description)
            }
            else {
                self?.mainCamera = nil
            }
        }
        
        gimbalRef = drone.getPeripheral(Peripherals.gimbal) { [weak self] gimbal in
            if let gimbal = gimbal {
                self?.gimbal = ParrotGimbalAdapter(gimbal: gimbal) { self?.session?.state?.value.orientation.z }
            }
            else {
                self?.gimbal = nil
            }
        }
    }
    
    public var remoteControllers: [RemoteControllerAdapter]? { [ParrotRemoteControllerAdapter(remoteControl: remoteControl)] }
    
    public func remoteController(channel: UInt) -> RemoteControllerAdapter? {
        if channel == 0 {
            return ParrotRemoteControllerAdapter(remoteControl: remoteControl)
        }
        return nil
    }
    
    public var cameras: [CameraAdapter]? {
        if let mainCamera = mainCamera {
            return [mainCamera]
        }
        return nil
    }
    
    public func cameraChannel(videoFeedChannel: UInt?) -> UInt? { nil }
    
    public func camera(channel: UInt) -> CameraAdapter? { cameras?[safeIndex: Int(channel)] }
    
    public var gimbals: [GimbalAdapter]? {
        if let gimbal = gimbal {
            return [gimbal]
        }
        return nil
    }
    
    public var batteries: [DronelinkCore.BatteryAdapter]? { nil }
    
    public func gimbal(channel: UInt) -> GimbalAdapter? { gimbals?[safeIndex: Int(channel)] }
    
    public func battery(channel: UInt) -> DronelinkCore.BatteryAdapter? { nil }
    
    public var rtk: DronelinkCore.RTKAdapter? { nil }
    
    public var liveStreaming: DronelinkCore.LiveStreamingAdapter? { nil }

    public func send(velocityCommand: Kernel.VelocityDroneCommand?) {
        guard let velocityCommand = velocityCommand else {
            sendResetVelocityDroneCommand()
            return
        }
        
        guard
            let manualFlightController = manualFlightController,
            let orientation = session?.state?.value.orientation
        else {
            return
        }
        
        //offset the velocity vector by the heading of the drone
        //var horizontalVelocity = velocityCommand.velocity.horizontal
        //horizontalVelocity = Kernel.Vector2(direction: horizontalVelocity.direction - orientation.yaw, magnitude: horizontalVelocity.magnitude)
        //let pitch = Int(max(-1, min(1, -horizontalVelocity.x / DronelinkParrot.maxVelocityHorizontal)) * 100)
        //let roll = Int(max(-1, min(1, horizontalVelocity.y / DronelinkParrot.maxVelocityHorizontal)) * 100)
        //let horizontalVelocity = velocityCommand.velocity.horizontal
        //var horizontalVelocityNormalized = Kernel.Vector2(direction: horizontalVelocity.direction.angleDifferenceSigned(angle: orientation.yaw), magnitude: min(horizontalVelocity.magnitude, DronelinkParrot.maxVelocityHorizontal) / DronelinkParrot.maxVelocityHorizontal)
        //let maxMagnitude = abs(sin(horizontalVelocityNormalized.direction)) + abs(cos(horizontalVelocityNormalized.direction))
        //horizontalVelocityNormalized = Kernel.Vector2(direction: horizontalVelocityNormalized.direction, magnitude: horizontalVelocityNormalized.magnitude * maxMagnitude)
        //let pitch = Int(max(-1, min(1, -horizontalVelocityNormalized.x)) * 100)
        //let roll = Int(max(-1, min(1, horizontalVelocityNormalized.y)) * 100)
        let horizontalVelocity = velocityCommand.velocity.horizontal
        let horizontalVelocityNormalized = Kernel.Vector2(
            direction: horizontalVelocity.direction.angleDifferenceSigned(angle: orientation.yaw),
            magnitude: horizontalVelocity.magnitude / DronelinkParrot.maxVelocityHorizontal)
        let pitch = Int(max(-1, min(1, -horizontalVelocityNormalized.x)) * 100)
        let roll = Int(max(-1, min(1, horizontalVelocityNormalized.y)) * 100)
        //os_log(.debug, log: ParrotDroneAdapter.log, "FIXME m=%{public}s p=%{public}s r=%{public}s", "\(horizontalVelocityNormalized.magnitude)", "\(pitch)", "\(roll)")
        let verticalSpeed = Int(max(-1, min(1, velocityCommand.velocity.vertical / manualFlightController.maxVerticalSpeed.value)) * 100)
        var rotationalSpeed = 0.0
        if let heading = velocityCommand.heading {
            rotationalSpeed = heading.angleDifferenceSigned(angle: orientation.yaw).convertRadiansToDegrees
        }
        else {
            rotationalSpeed = velocityCommand.velocity.rotational.convertRadiansToDegrees
        }
        rotationalSpeed = max(-1, min(1, rotationalSpeed / manualFlightController.maxYawRotationSpeed.value)) * 100
        
        manualFlightController.set(pitch: pitch)
        manualFlightController.set(roll: roll)
        manualFlightController.set(verticalSpeed: verticalSpeed)
        manualFlightController.set(yawRotationSpeed: Int(rotationalSpeed))
        
        //can't use this right now because horizontal has no direction?
//        guidedFlightController.move(
//            directive: GuidedDirective(
//                guidedType: GuidedType.relativeMove,
//                speed: GuidedPilotingSpeed(
//                    horizontalSpeed: horizontal.magnitude,
//                    verticalSpeed: velocityCommand.velocity.vertical,
//                    yawRotationSpeed: rotationalSpeed)))
    }
    
    public func send(remoteControllerSticksCommand: Kernel.RemoteControllerSticksDroneCommand?) {
        guard let remoteControllerSticksCommand = remoteControllerSticksCommand else {
            sendResetVelocityDroneCommand()
            return
        }
        
        manualFlightController?.set(pitch: -Int(remoteControllerSticksCommand.rightStick.y * 100))
        manualFlightController?.set(roll: Int(remoteControllerSticksCommand.rightStick.x * 100))
        manualFlightController?.set(verticalSpeed: Int(remoteControllerSticksCommand.leftStick.y * 100))
        manualFlightController?.set(yawRotationSpeed: Int(remoteControllerSticksCommand.leftStick.x * 100))
    }
    
    public func startTakeoff(finished: CommandFinished?) {
        guard let flightController = manualFlightController else {
            finished?("ParrotDroneAdapter.startTakeoff.unavailable".localized)
            return
        }

        flightController.takeOff()
        finished?(nil)
    }

    public func startReturnHome(finished: CommandFinished?) {
        guard let returnHomeController = returnHomeController else {
            finished?("ParrotDroneAdapter.startReturnHome.unavailable".localized)
            return
        }

        finished?(returnHomeController.activate() ? nil : "ParrotDroneAdapter.startReturnHome.failed")
    }
    
    public func stopReturnHome(finished: CommandFinished?) {
        guard let returnHomeController = returnHomeController else {
            finished?("ParrotDroneAdapter.startReturnHome.unavailable".localized)
            return
        }

        finished?(returnHomeController.deactivate() ? nil : "ParrotDroneAdapter.startReturnHome.failed")
    }

    public func startLand(finished: CommandFinished?) {
        guard let manualFlightController = manualFlightController else {
            finished?("ParrotDroneAdapter.startLand.unavailable".localized)
            return
        }

        manualFlightController.land()
        finished?(nil)
    }
    
    public func stopLand(finished: CommandFinished?) {
        finished?("ParrotDroneAdapter.stopLand.unavailable".localized)
    }
    
    public func startCompassCalibration(finished: CommandFinished?) {
        finished?("ParrotDroneAdapter.startCompassCalibration.unavailable".localized)
    }
    
    public func stopCompassCalibration(finished: CommandFinished?) {
        finished?("ParrotDroneAdapter.stopCompassCalibration.unavailable".localized)
    }
    
    public func sendResetVelocityDroneCommand() {
        manualFlightController?.hover()
    }
    
    public func sendResetVelocityGimbalCommand() {
        gimbals?.forEach({ adapter in
            if let adapter = adapter as? ParrotGimbalAdapter {
                adapter.gimbal.control(mode: .velocity, yaw: 0, pitch: 0, roll: 0)
            }
        })
    }
    
    public func sendResetGimbalCommands() {
        gimbals?.forEach {
            if let adapter = $0 as? ParrotGimbalAdapter {
                adapter.reset()
            }
        }
    }
    
    public func sendResetCameraCommands() {
        cameras?.forEach {
            if let adapter = $0 as? ParrotCameraAdapter {
                adapter.reset()
            }
        }
    }
    
    public func enumElements(parameter: String) -> [EnumElement]? {
        return nil
    }
}

public class ParrotCameraAdapter: CameraAdapter {
    public let camera: Camera2
    public let model: String?
    
    private var exposureIndicatorRef: Ref<Camera2ExposureIndicator>?
    private var exposureLockRef: Ref<Camera2ExposureLock>?
    private var whiteBalanceLockRef: Ref<Camera2WhiteBalanceLock>?
    private var mediaMetadataRef: Ref<Camera2MediaMetadata>?
    private var recordingRef: Ref<Camera2Recording>?
    private var photoCaptureRef: Ref<Camera2PhotoCapture>?
    private var photoProgressIndicatorRef: Ref<Camera2PhotoProgressIndicator>?
    private var zoomRef: Ref<Camera2Zoom>?
    
    private var exposureIndicator: Camera2ExposureIndicator?
    private var exposureLock: Camera2ExposureLock?
    private var whiteBalanceLock: Camera2WhiteBalanceLock?
    private var mediaMetadata: Camera2MediaMetadata?
    public var recording: Camera2Recording?
    public var photoCapture: Camera2PhotoCapture?
    private var photoProgressIndicator: Camera2PhotoProgressIndicator?
    private var zoom: Camera2Zoom?
    
    public init(camera: Camera2, model: String?) {
        self.camera = camera
        self.model = model
        
        exposureIndicatorRef = camera.getComponent(Camera2Components.exposureIndicator) { [weak self] value in
            self?.exposureIndicator = value
        }

        exposureLockRef = camera.getComponent(Camera2Components.exposureLock) { [weak self] value in
            self?.exposureLock = value
        }

        whiteBalanceLockRef = camera.getComponent(Camera2Components.whiteBalanceLock) { [weak self] value in
            self?.whiteBalanceLock = value
        }

        mediaMetadataRef = camera.getComponent(Camera2Components.mediaMetadata) { [weak self] value in
            self?.mediaMetadata = value
        }

        recordingRef = camera.getComponent(Camera2Components.recording) { [weak self] value in
            self?.recording = value
        }

        photoCaptureRef = camera.getComponent(Camera2Components.photoCapture) { [weak self] value in
            self?.photoCapture = value
        }

        photoProgressIndicatorRef = camera.getComponent(Camera2Components.photoProgressIndicator) { [weak self] value in
            self?.photoProgressIndicator = value
        }

        zoomRef = camera.getComponent(Camera2Components.zoom) { [weak self] value in
            self?.zoom = value
        }
    }
    
    public var index: UInt { 0 }
    
    public func lensIndex(videoStreamSource: Kernel.CameraVideoStreamSource) -> UInt { 0 }
    
    public func format(storageLocation: Kernel.CameraStorageLocation, finished: CommandFinished?) {
        finished?("ParrotCameraAdapter.format.unavailable".localized)
    }
    
    public func histogram(enabled: Bool, finished: DronelinkCore.CommandFinished?) {
        finished?("ParrotCameraAdapter.histogram.unavailable".localized)
    }
    
    public func enumElements(parameter: String) -> [EnumElement]? {
        switch parameter {
        case "CameraPhotoInterval":
            return (2...10).map {
                EnumElement(display: "\($0) s", value: $0)
            }
        default:
            break
        }
        
        guard let enumDefinition = Dronelink.shared.enumDefinition(name: parameter) else {
            return nil
        }
        
        var range: [String?]?
        
        switch parameter {
        case "CameraMode":
            range =  [
                Kernel.CameraMode.photo.rawValue,
                Kernel.CameraMode.video.rawValue,
            ]
            break
        case "CameraPhotoMode":
            range = [
                Kernel.CameraPhotoMode.single.rawValue,
                Kernel.CameraPhotoMode.interval.rawValue,
                Kernel.CameraPhotoMode.aeb.rawValue,
                Kernel.CameraPhotoMode.burst.rawValue
            ]
            break
        default:
            return nil
        }
        
        var enumElements: [EnumElement] = []
        range?.forEach { value in
            if let value = value, value != "unknown", let display = enumDefinition[value] {
                enumElements.append(EnumElement(display: display, value: value))
            }
        }
        
        return enumElements.isEmpty ? nil : enumElements
    }
    
    public func reset() {
        if photoCapture?.state.canStop ?? false {
            photoCapture?.stop()
        }
        else if recording?.state.canStop ?? false {
            recording?.stop()
        }
    }
}

extension ParrotCameraAdapter: CameraStateAdapter {
    public var isBusy: Bool { false }
    public var isCapturing: Bool { (recording?.state.canStop ?? false) || (photoCapture?.state.canStop ?? false) }
    public var isCapturingPhoto: Bool { isCapturing && mode == .photo }
    public var isCapturingPhotoInterval: Bool { isCapturingPhoto && (camera.config[Camera2Params.photoMode]?.value == Camera2PhotoMode.timeLapse || camera.config[Camera2Params.photoMode]?.value == Camera2PhotoMode.gpsLapse) }
    public var isCapturingVideo: Bool { isCapturing && mode == .video }
    public var isCapturingContinuous: Bool { isCapturingVideo || isCapturingPhotoInterval }
    public var isSDCardInserted: Bool { true }
    public var videoStreamSource: Kernel.CameraVideoStreamSource { .unknown }
    public var storageLocation: Kernel.CameraStorageLocation { .sdCard }
    public var storageRemainingSpace: Int? { nil }
    public var storageRemainingPhotos: Int? { nil }
    public var mode: Kernel.CameraMode { camera.config[Camera2Params.mode]?.value.kernelValue ?? .unknown }
    public var photoMode: Kernel.CameraPhotoMode? { camera.config[Camera2Params.photoMode]?.value.kernelValue ?? .unknown }
    public var burstCount: Kernel.CameraBurstCount? { camera.config[Camera2Params.photoBurst]?.value.kernelValue ?? .unknown }
    public var aebCount: Kernel.CameraAEBCount? { camera.config[Camera2Params.photoBracketing]?.value.kernelValue ?? .unknown }
    public var photoInterval: Int? { Int(camera.config[Camera2Params.photoTimelapseInterval]?.value.magnitude ?? 0) } //FIXME confirm
    public var photoFileFormat: Kernel.CameraPhotoFileFormat { camera.config[Camera2Params.photoFileFormat]?.value.kernelValue ?? .unknown  }
    public var videoFileFormat: Kernel.CameraVideoFileFormat { .mp4 }
    public var videoFrameRate: Kernel.CameraVideoFrameRate { camera.config[Camera2Params.videoRecordingFramerate]?.value.kernelValue ?? .unknown }
    public var videoResolution: Kernel.CameraVideoResolution { camera.config[Camera2Params.videoRecordingResolution]?.value.kernelValue ?? .unknown }
    public var currentVideoTime: Double? { nil } //TODO
    public var exposureMode: Kernel.CameraExposureMode { camera.config[Camera2Params.exposureMode]?.value.kernelValue ?? .unknown }
    public var exposureCompensation: Kernel.CameraExposureCompensation { camera.config[Camera2Params.exposureCompensation]?.value.kernelValue ?? .unknown  }
    public var iso: Kernel.CameraISO { camera.config[Camera2Params.isoSensitivity]?.value.kernelValue ?? .unknown }
    public var isoActual: Int? { nil } //TODO
    public var shutterSpeed: Kernel.CameraShutterSpeed { .unknown } //TODO
    public var shutterSpeedActual: Kernel.CameraShutterSpeed? { shutterSpeed }
    public var aperture: Kernel.CameraAperture { .unknown } //TODO
    public var apertureActual: DronelinkCore.Kernel.CameraAperture { .unknown } //TODO
    public var whiteBalancePreset: Kernel.CameraWhiteBalancePreset { .unknown } //TODO
    public var whiteBalanceColorTemperature: Int? { nil } //TODO
    public var histogram: [UInt]? { nil }
    public var lensIndex: UInt { 0 }
    public var lensDetails: String? { nil }
    public var focusMode: DronelinkCore.Kernel.CameraFocusMode { return .unknown }
    public var focusRingValue: Double? { nil }
    public var focusRingMax: Double? { nil }
    public var isPercentZoomSupported: Bool { false }
    public var isRatioZoomSupported: Bool { false }
    public var defaultZoomSpecification: DronelinkCore.Kernel.PercentZoomSpecification? { nil }
    public var meteringMode: DronelinkCore.Kernel.CameraMeteringMode { return .unknown }
    public var isAutoExposureLockEnabled: Bool { return false }
    public var aspectRatio: Kernel.CameraPhotoAspectRatio { ._16x9 }
}

public class ParrotGimbalAdapter: GimbalAdapter {
    private static let log = OSLog(subsystem: "DronelinkParrot", category: "ParrotGimbalAdapter")
    
    public let gimbal: Gimbal
    private let heading: () -> Double?
    
    public init(gimbal: Gimbal, heading: @escaping () -> Double?) {
        self.gimbal = gimbal
        self.heading = heading
        gimbal.stabilizationSettings[.pitch]?.value = true
        gimbal.maxSpeedSettings[.pitch]?.value = 90
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
        if abs(orientation.pitch) < 0.1.convertDegreesToRadians {
            gimbal.control(mode: .position, yaw: 0, pitch: -90, roll: 0)
        }
        else {
            gimbal.resetAttitude()
        }
    }
    
    public func fineTune(roll: Double) {}
    
    public func enumElements(parameter: String) -> [EnumElement]? {
        guard let enumDefinition = Dronelink.shared.enumDefinition(name: parameter) else {
            return nil
        }
        
        var range: [String?]?
        
        switch parameter {
        case "GimbalMode":
            range = []
            range?.append(Kernel.GimbalMode.yawFollow.rawValue)
            break
        default:
            return nil
        }
        
        guard let rangeValid = range, !rangeValid.isEmpty else {
            return nil
        }
        
        var enumElements: [EnumElement] = []
        rangeValid.forEach { value in
            if let value = value, let display = enumDefinition[value] {
                enumElements.append(EnumElement(display: display, value: value))
            }
        }
        
        return enumElements.isEmpty ? nil : enumElements
    }
}

extension ParrotGimbalAdapter: GimbalStateAdapter {
    public var mode: Kernel.GimbalMode { .yawFollow }
    
    public var orientation: Kernel.Orientation3 {
        let orientation = gimbal.kernelOrientation
        return Kernel.Orientation3(x: orientation.x, y: orientation.y, z: heading() ?? orientation.z)
    }
}

public class ParrotRemoteControllerAdapter: RemoteControllerAdapter {
    public let remoteControl: RemoteControl
    
    public init(remoteControl: RemoteControl) {
        self.remoteControl = remoteControl
    }
    
    public func startDeviceCharging(finished: CommandFinished?) {
        finished?("ParrotRemoteControllerAdapter.DeviceCharging.unavailable".localized)
    }
    
    public func stopDeviceCharging(finished: CommandFinished?) {
        finished?("ParrotRemoteControllerAdapter.DeviceCharging.unavailable".localized)
    }
    
    public var index: UInt { 0 }
}
