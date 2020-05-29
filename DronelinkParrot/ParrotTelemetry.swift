//
//  ParrotTelemetry.swift
//  DronelinkParrot
//
//  Created by Jim McAndrew on 5/25/20.
//  Copyright © 2020 Dronelink. All rights reserved.
//

import Foundation
import os
import DronelinkCore
import GroundSdk
import CoreLocation

public struct ParrotTelemetry {
    let location: CLLocation
    let altitude: Double
    let takeoffAltitude: Double
    let droneQuatX: Double
    let droneQuatY: Double
    let droneQuatZ: Double
    let droneQuatW: Double
    let speedNorth: Double
    let speedEast: Double
    let speedDown: Double
    let frameQuatX: Double
    let frameQuatY: Double
    let frameQuatZ: Double
    let frameQuatW: Double
    
    public init(latitude: Double, longitude: Double, altitude: Double, takeoffAltitude: Double, droneQuatX: Double, droneQuatY: Double, droneQuatZ: Double, droneQuatW: Double, speedNorth: Double, speedEast: Double, speedDown: Double, frameQuatX: Double, frameQuatY: Double, frameQuatZ: Double, frameQuatW: Double) {
        self.location = CLLocation(latitude: latitude, longitude: longitude)
        self.altitude = altitude
        self.takeoffAltitude = takeoffAltitude
        self.droneQuatX = droneQuatX
        self.droneQuatY = droneQuatY
        self.droneQuatZ = droneQuatZ
        self.droneQuatW = droneQuatW
        self.speedNorth = speedNorth
        self.speedEast = speedEast
        self.speedDown = speedDown
        self.frameQuatX = frameQuatX
        self.frameQuatY = frameQuatY
        self.frameQuatZ = frameQuatZ
        self.frameQuatW = frameQuatW
    }
    
    var droneMissionOrientation: Mission.Orientation3 {
        return Mission.Orientation3.fromQuaternion(x: droneQuatX, y: droneQuatY, z: droneQuatZ, w: droneQuatW)
    }
    
    var gimbalMissionOrientation: Mission.Orientation3 {
        return Mission.Orientation3.fromQuaternion(x: frameQuatX, y: frameQuatY, z: frameQuatZ, w: frameQuatW)
    }
}

public protocol ParrotTelemetryProvider {
    var telemetry: DatedValue<ParrotTelemetry>? { get }
}
