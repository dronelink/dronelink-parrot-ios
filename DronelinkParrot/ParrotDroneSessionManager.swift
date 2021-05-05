//
//  ParrotDroneSessionManager.swift
//  DronelinkParrot
//
//  Created by Jim McAndrew on 11/20/19.
//  Copyright © 2019 Dronelink. All rights reserved.
//
import Foundation
import os
import DronelinkCore
import GroundSdk

public class ParrotDroneSessionManager: NSObject {
    private static let log = OSLog(subsystem: "DronelinkParrot", category: "ParrotDroneSessionManager")
    
    private let delegates = MulticastDelegate<DroneSessionManagerDelegate>()
    private let groundSdk = GroundSdk()
    private var autoConnectionRef: Ref<AutoConnection>?
    private var _session: ParrotDroneSession?
    
    public override init() {
        super.init()
        
        autoConnectionRef = groundSdk.getFacility(Facilities.autoConnection) { [weak self] autoConnection in
            if let self = self, let autoConnection = autoConnection {
                if (autoConnection.state != AutoConnectionState.started) {
                    autoConnection.start()
                }
                
                if (self._session?.serialNumber != autoConnection.drone?.uid) {
                    if let session = self._session {
                        session.close()
                        self._session = nil
                        self.delegates.invoke { $0.onClosed(session: session) }
                    }

                    if let drone = autoConnection.drone {
                        self._session = ParrotDroneSession(drone: drone, remoteControl: autoConnection.remoteControl)
                        self.delegates.invoke { $0.onOpened(session: self._session!) }
                    }
                }
                
                if (self._session?.adapter.remoteControl?.uid != autoConnection.remoteControl?.uid) {
                    self._session?.adapter.remoteControl = autoConnection.remoteControl
                }
            }
        }
    }
}


extension ParrotDroneSessionManager: DroneSessionManager {
    public func add(delegate: DroneSessionManagerDelegate) {
        delegates.add(delegate)
        if let session = _session {
            delegate.onOpened(session: session)
        }
    }
    
    public func closeSession() {
        if let session = _session {
            session.close()
            _session = nil
            delegates.invoke { $0.onClosed(session: session) }
        }
    }
    
    public func remove(delegate: DroneSessionManagerDelegate) {
        delegates.remove(delegate)
    }
    
    public var session: DroneSession? { _session }
    
    public var statusMessages: [Kernel.Message]? {
        session?.state?.value.statusMessages
    }
}
