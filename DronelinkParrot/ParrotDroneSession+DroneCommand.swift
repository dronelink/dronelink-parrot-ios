//
//  ParrotDroneSession+DroneCommand.swift
//  DronelinkParrot
//
//  Created by Jim McAndrew on 11/20/19.
//  Copyright © 2019 Dronelink. All rights reserved.
//
import DronelinkCore
import GroundSdk
import CoreLocation

extension ParrotDroneSession {
    func execute(droneCommand: KernelDroneCommand, finished: @escaping CommandFinished) -> Error? {
        if droneCommand is KernelDroneLightbridgeCommand {
            return "MissionDisengageReason.command.type.unsupported".localized
        }
        
        if droneCommand is KernelDroneOcuSyncCommand {
            return "MissionDisengageReason.command.type.unsupported".localized
        }
        
        guard
            let returnHomeController = adapter.returnHomeController,
            let geoFence = adapter.geoFence
        else {
            return "MissionDisengageReason.drone.control.unavailable.title".localized
        }
        
        if droneCommand is Kernel.ConnectionFailSafeBehaviorDroneCommand {
            return "MissionDisengageReason.command.type.unsupported".localized
        }
        
        if let command = droneCommand as? Kernel.HomeLocationDroneCommand {
            returnHomeController.setCustomLocation(latitude: command.coordinate.latitude, longitude: command.coordinate.longitude, altitude: 0)
            finished(nil)
            return nil
        }
        
        if droneCommand is Kernel.LowBatteryWarningThresholdDroneCommand {
            return "MissionDisengageReason.command.type.unsupported".localized
        }

        if let command = droneCommand as? Kernel.MaxAltitudeDroneCommand {
            geoFence.maxAltitude.value = command.maxAltitude
            finished(nil)
            return nil
        }

        if let command = droneCommand as? Kernel.MaxDistanceDroneCommand {
            geoFence.maxDistance.value = command.maxDistance
            finished(nil)
            return nil
        }

        if let command = droneCommand as? Kernel.ReturnHomeAltitudeDroneCommand {
            returnHomeController.minAltitude?.value = command.returnHomeAltitude
            finished(nil)
            return nil
        }
        
        return "MissionDisengageReason.command.type.unhandled".localized
    }
}
