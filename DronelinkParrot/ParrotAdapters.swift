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
    public let drone: Drone
    
    private var flightControllerRef: Ref<ManualCopterPilotingItf>?
    private var returnHomeControllerRef: Ref<ReturnHomePilotingItf>?
    private var geoFenceRef: Ref<GeofenceDesc.ApiProtocol>?
    private var mainCameraRef: Ref<MainCameraDesc.ApiProtocol>?
    private var thermalCameraRef: Ref<ThermalCameraDesc.ApiProtocol>?
    private var gimbalRef: Ref<GimbalDesc.ApiProtocol>?
    
    private var _flightController: ManualCopterPilotingItf?
    private var _returnHomeController: ReturnHomePilotingItf?
    private var _geoFence: Geofence?
    private var mainCamera: ParrotCameraAdapter?
    private var thermalCamera: ParrotCameraAdapter?
    private var gimbal: ParrotGimbalAdapter?
    
    public var flightController: ManualCopterPilotingItf? { _flightController }
    public var returnHomeController: ReturnHomePilotingItf? { _returnHomeController }
    public var geoFence: Geofence? { _geoFence }

    public init(drone: Drone) {
        self.drone = drone
        
        flightControllerRef = drone.getPilotingItf(PilotingItfs.manualCopter) { [weak self] itf in
            self?._flightController = itf
        }
        
        returnHomeControllerRef = drone.getPilotingItf(PilotingItfs.returnHome) { [weak self] itf in
            self?._returnHomeController = itf
        }
        
        geoFenceRef = drone.getPeripheral(Peripherals.geofence) { [weak self] itf in
            self?._geoFence = itf
        }
        
        mainCameraRef = drone.getPeripheral(Peripherals.mainCamera) { [weak self] mainCamera in
            if let mainCamera = mainCamera {
                self?.mainCamera = ParrotCameraAdapter(camera: mainCamera)
            }
            else {
                self?.mainCamera = nil
            }
        }
        
        thermalCameraRef = drone.getPeripheral(Peripherals.thermalCamera) { [weak self] thermalCamera in
            if let thermalCamera = thermalCamera {
                self?.thermalCamera = ParrotCameraAdapter(camera: thermalCamera)
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

    public var cameras: [CameraAdapter]? {
        if let mainCamera = mainCamera {
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

    public func send(velocityCommand: Mission.VelocityDroneCommand?) {
        guard let velocityCommand = velocityCommand else {
            sendResetVelocityCommand()
            return
        }

        guard let flightController = flightController else { return }
        
        //FIXME need velocity control for pitch and roll
        flightController.set(pitch: Int(velocityCommand.velocity.horizontal.x))
        flightController.set(roll: Int(velocityCommand.velocity.horizontal.y))
        flightController.set(verticalSpeed: Int(velocityCommand.velocity.vertical))
        if let _ = velocityCommand.heading {
            //FIXME need absolute angle for heading
            //Float(velocityCommand.heading!.angleDifferenceSigned(angle: 0).convertRadiansToDegrees
        }
        else {
            flightController.set(yawRotationSpeed: Int(velocityCommand.velocity.rotational.convertRadiansToDegrees))
        }
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

public class ParrotCameraAdapter: CameraAdapter, CameraStateAdapter {
    public let camera: Camera
    
    public init(camera: Camera) {
        self.camera = camera
    }
    
    public var index: UInt { 0 }
    
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
    
    public var isCapturing: Bool { isCapturingVideo || isCapturingPhotoInterval }
    
    public var missionMode: Mission.CameraMode {
        switch camera.modeSetting.mode {
        case .recording: return .video
        case .photo: return .photo
        @unknown default: return .unknown
        }
    }
}

public class ParrotGimbalAdapter: GimbalAdapter, GimbalStateAdapter {
    public let gimbal: Gimbal
    
    public init(gimbal: Gimbal) {
        self.gimbal = gimbal
    }
    
    public var index: UInt { 0 }
    
    public func send(velocityCommand: Mission.VelocityGimbalCommand, mode: Mission.GimbalMode) {
        gimbal.control(
            mode: .velocity,
            yaw: velocityCommand.velocity.yaw.convertRadiansToDegrees,
            pitch: velocityCommand.velocity.pitch.convertRadiansToDegrees,
            roll: velocityCommand.velocity.roll.convertRadiansToDegrees)
    }
    
    public var missionMode: Mission.GimbalMode { .yawFollow }
    
    public var missionOrientation: Mission.Orientation3 {
        return Mission.Orientation3(
            x: (gimbal.currentAttitude[GimbalAxis.pitch] ?? 0).convertDegreesToRadians,
            y: (gimbal.currentAttitude[GimbalAxis.roll] ?? 0).convertDegreesToRadians,
            z: (gimbal.currentAttitude[GimbalAxis.yaw] ?? 0).convertDegreesToRadians)
    }
}
