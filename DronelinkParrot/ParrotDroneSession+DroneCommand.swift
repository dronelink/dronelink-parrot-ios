//
//  ParrotDroneSession+DroneCommand.swift
//  DronelinkParrot
//
//  Created by Jim McAndrew on 11/20/19.
//  Copyright © 2019 Dronelink. All rights reserved.
//
import DronelinkCore

extension ParrotDroneSession {
    func execute(droneCommand: MissionDroneCommand, finished: @escaping CommandFinished) -> Error? {
        if droneCommand is MissionDroneLightbridgeCommand {
            return "MissionDisengageReason.command.type.unsupported".localized
        }
        
        if droneCommand is MissionDroneOcuSyncCommand {
            return "MissionDisengageReason.command.type.unsupported".localized
        }
        
        guard
            let returnHomController = adapter.returnHomeController,
            let geoFence = adapter.geoFence
        else {
            return "MissionDisengageReason.drone.control.unavailable.title".localized
        }
        
        if droneCommand is Mission.ConnectionFailSafeBehaviorDroneCommand {
            return "MissionDisengageReason.command.type.unsupported".localized
        }
        
        if droneCommand is Mission.LowBatteryWarningThresholdDroneCommand {
            return "MissionDisengageReason.command.type.unsupported".localized
        }

        if let command = droneCommand as? Mission.MaxAltitudeDroneCommand {
            geoFence.maxAltitude.value = command.maxAltitude
            finished(nil)
            return nil
        }

        if let command = droneCommand as? Mission.MaxDistanceDroneCommand {
            geoFence.maxDistance.value = command.maxDistance
            finished(nil)
            return nil
        }

        if let command = droneCommand as? Mission.ReturnHomeAltitudeDroneCommand {
            returnHomController.minAltitude?.value = command.returnHomeAltitude
            finished(nil)
            return nil
        }
        
        return "MissionDisengageReason.command.type.unhandled".localized
    }
}
