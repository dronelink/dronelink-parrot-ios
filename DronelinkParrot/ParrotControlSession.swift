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
    private static let log = OSLog(subsystem: "DronelinkParrot", category: "ParrotControlSession")
    
    private enum State {
        case TakeoffStart
        case TakeoffAttempting
        case FlightControllerActivateStart
        case FlightControllerActivateComplete
        case Deactivated
    }
    
    private static let motionEnabled = true
    
    public let executionEngine = Kernel.ExecutionEngine.dronelinkKernel
    public let reengaging: Bool = false
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
        
        if ParrotControlSession.motionEnabled {
            let state = droneSession.adapter.manualFlightController?.state ?? .unavailable
            if self.state == .FlightControllerActivateComplete && state != .active {
                return Kernel.Message(title: "MissionDisengageReason.drone.control.override.title".localized, details: "MissionDisengageReason.drone.control.override.details".localized)
            }
        }
        
        return nil
    }
    
    public func activate() -> Bool? {
        guard let manualFlightController = droneSession.adapter.manualFlightController else {
            deactivate()
            return false
        }
        
        switch state {
        case .TakeoffStart:
            if !ParrotControlSession.motionEnabled {
                state = .FlightControllerActivateComplete
                return activate()
            }
            
            if droneSession.state?.value.isFlying ?? false {
                state = .FlightControllerActivateStart
                return activate()
            }
            
            if !manualFlightController.canTakeOff {
                self.attemptDisengageReason = Kernel.Message(title: "MissionDisengageReason.take.off.failed.title".localized)
                self.deactivate()
                return false
            }
            
            state = .TakeoffAttempting
            os_log(.info, log: ParrotControlSession.log, "Attempting takeoff")
            manualFlightController.takeOff()
            DispatchQueue.global().asyncAfter(deadline: .now() + 5.0) { [weak self] in
                if self?.droneSession.state?.value.isFlying ?? false {
                    os_log(.info, log: ParrotControlSession.log, "Takeoff succeeded")
                    self?.state = .FlightControllerActivateStart
                }
                else {
                    self?.attemptDisengageReason = Kernel.Message(title: "MissionDisengageReason.take.off.failed.title".localized)
                    self?.deactivate()
                }
            }
            return nil
            
        case .TakeoffAttempting:
            return nil
            
        case .FlightControllerActivateStart:
            droneSession.adapter.copilot?.setting.source = .application
        
            if manualFlightController.state == .active {
                state = .FlightControllerActivateComplete
                return activate()
            }
            
            if manualFlightController.activate() {
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
        droneSession.adapter.copilot?.setting.source = .remoteControl
        droneSession.sendResetVelocityCommands()
        droneSession.adapter.manualFlightController?.deactivate()
        state = .Deactivated
    }
}
