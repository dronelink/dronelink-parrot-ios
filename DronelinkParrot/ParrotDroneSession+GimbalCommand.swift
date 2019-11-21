//
//  ParrotDroneSession+GimbalCommand.swift
//  DronelinkParrot
//
//  Created by Jim McAndrew on 11/20/19.
//  Copyright © 2019 Dronelink. All rights reserved.
//
import DronelinkCore

extension ParrotDroneSession {
    func execute(gimbalCommand: MissionGimbalCommand, finished: @escaping CommandFinished) -> Error? {
        guard let adapter = (adapter.gimbal(channel: gimbalCommand.channel) as? ParrotGimbalAdapter) else {
            return "MissionDisengageReason.drone.gimbal.unavailable.title".localized
        }
        
        if gimbalCommand is Mission.ModeGimbalCommand {
            return "MissionDisengageReason.command.type.unsupported".localized
        }
        
        if let command = gimbalCommand as? Mission.OrientationGimbalCommand {
            if (command.orientation.pitch == nil && command.orientation.roll == nil && command.orientation.yaw == nil) {
                finished(nil)
                return nil
            }
            
            adapter.gimbal.control(
                mode: .position,
                yaw: command.orientation.yaw ?? 0,
                pitch: command.orientation.pitch?.convertRadiansToDegrees ?? 0,
                roll: command.orientation.roll ?? 0)
            finished(nil)
            return nil
        }
        
        return "MissionDisengageReason.command.type.unhandled".localized
    }
}
