//
//  ParrotControlSession.swift
//  DronelinkParrot
//
//  Created by Jim McAndrew on 11/20/19.
//  Copyright © 2019 Dronelink. All rights reserved.
//
import DronelinkCore
import Foundation
import os
import GroundSdk
import JavaScriptCore

public class ParrotControlSession: DroneControlSession {
    private let log = OSLog(subsystem: "DronelinkParrot", category: "ParrotControlSession")
    
    private enum State {
        case TakeControlStart
        case TakeoffStart
        case TakeoffAttempting
        case TakeoffComplete
        case Deactivated
    }
    
    private let droneSession: ParrotDroneSession
    
    private var state = State.TakeoffStart
    private var attemptDisengageReason: Mission.Message?
    
    public init(droneSession: ParrotDroneSession) {
        self.droneSession = droneSession
    }
    
    public var disengageReason: Mission.Message? {
        if let attemptDisengageReason = attemptDisengageReason {
            return attemptDisengageReason
        }
        
        return nil
    }
    
    public func activate() -> Bool {
        guard let flightController = droneSession.adapter.flightController else {
            return false
        }
        
        switch state {
        case .TakeControlStart:
            if flightController.activate() {
                state = .TakeControlStart
                return activate()
            }
            attemptDisengageReason = Mission.Message(title: "MissionDisengageReason.take.control.failed.title".localized)
            deactivate()
            return false
            
        case .TakeoffStart:
            if droneSession.state?.value.isFlying ?? false {
                state = .TakeoffComplete
                return activate()
            }
            
            if !flightController.canTakeOff {
                self.attemptDisengageReason = Mission.Message(title: "MissionDisengageReason.take.off.failed.title".localized)
                self.deactivate()
            }
            
            state = .TakeoffAttempting
            os_log(.info, log: log, "Attempting takeoff")
            flightController.takeOff()
            DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) {
                if self.droneSession.state?.value.isFlying ?? false {
                    os_log(.info, log: self.log, "Takeoff succeeded")
                    self.state = .TakeoffComplete
                }
                else {
                    self.attemptDisengageReason = Mission.Message(title: "MissionDisengageReason.take.off.failed.title".localized)
                    self.deactivate()
                }
            }
            return false
            
        case .TakeoffAttempting:
            return false
            
        case .TakeoffComplete:
            return true
            
        case .Deactivated:
            return false
        }
    }
    
    public func deactivate() {
        droneSession.sendResetVelocityCommand()
        droneSession.sendResetGimbalCommands()
        droneSession.sendResetCameraCommands()
        
        state = .Deactivated
    }
}
