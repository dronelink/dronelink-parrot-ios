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
        case TakeoffStart
        case TakeoffAttempting
        case FlightControllerActivateStart
        case FlightControllerActivateComplete
        case Deactivated
    }
    
    private let droneSession: ParrotDroneSession
    
    private var state = State.TakeoffStart
    private var attemptDisengageReason: Kernel.Message?
    
    public init(droneSession: ParrotDroneSession) {
        self.droneSession = droneSession
    }
    
    public var disengageReason: Kernel.Message? {
        if let attemptDisengageReason = attemptDisengageReason {
            return attemptDisengageReason
        }
        
        let state = droneSession.adapter.flightController?.state ?? .unavailable
        if self.state == .FlightControllerActivateComplete && state != .active {
            return Kernel.Message(title: "MissionDisengageReason.drone.control.override.title".localized)
        }
        
        return nil
    }
    
    public func activate() -> Bool? {
        guard let flightController = droneSession.adapter.flightController else {
            deactivate()
            return false
        }
        
        switch state {
        case .TakeoffStart:
            if droneSession.state?.value.isFlying ?? false {
                state = .FlightControllerActivateStart
                return activate()
            }
            
            if !flightController.canTakeOff {
                self.attemptDisengageReason = Kernel.Message(title: "MissionDisengageReason.take.off.failed.title".localized)
                self.deactivate()
                return false
            }
            
            state = .TakeoffAttempting
            os_log(.info, log: log, "Attempting takeoff")
            flightController.takeOff()
            DispatchQueue.global().asyncAfter(deadline: .now() + 5.0) {
                if self.droneSession.state?.value.isFlying ?? false {
                    os_log(.info, log: self.log, "Takeoff succeeded")
                    self.state = .FlightControllerActivateStart
                }
                else {
                    self.attemptDisengageReason = Kernel.Message(title: "MissionDisengageReason.take.off.failed.title".localized)
                    self.deactivate()
                }
            }
            return nil
            
        case .TakeoffAttempting:
            return nil
            
        case .FlightControllerActivateStart:
            droneSession.adapter.copilotController?.setting.source = .application
        
            if flightController.state == .active {
                state = .FlightControllerActivateComplete
                return activate()
            }
            
            os_log(.info, log: log, "Attempting flight controller activation")
            if flightController.activate() {
                state = .FlightControllerActivateComplete
                return activate()
            }
            attemptDisengageReason = Kernel.Message(title: "MissionDisengageReason.take.control.failed.title".localized)
            deactivate()
            return false

        case .FlightControllerActivateComplete:
            return true
            
        case .Deactivated:
            return false
        }
    }
    
    public func deactivate() {
        droneSession.adapter.copilotController?.setting.source = .remoteControl
        droneSession.sendResetVelocityCommand()
        state = .Deactivated
    }
}
