//
//  DronelinkParrot.swift
//  DronelinkParrot
//
//  Created by Jim McAndrew on 11/20/19.
//  Copyright © 2019 Dronelink. All rights reserved.
//

import Foundation
import GroundSdk
import DronelinkCore

extension DronelinkParrot {
    internal static let bundle = Bundle.init(for: DronelinkParrot.self)
}

public class DronelinkParrot {}

extension FlyingIndicators {
    var isFlying: Bool {
        switch state {
        case .landed: return false
        case .flying: return true
        case .emergencyLanding: return true
        case .emergency: return true
        @unknown default: return false
        }
    }
    
    var areMotorsOn: Bool {
        switch state {
        case .landed:
            switch landedState {
            case .none: return false
            case .initializing: return false
            case .idle: return false
            case .motorRamping: return true
            case .waitingUserAction: return true
            @unknown default: return false
            }
            
        case .flying: return true
        case .emergencyLanding: return true
        case .emergency: return true
        @unknown default: return false
        }
    }
}

extension Speedometer {
    public var verticalSpeed: Double { -downSpeed }
    public var course: Double { Double(atan2(northSpeed, eastSpeed)) }
}

extension AttitudeIndicator {
    public var missionOrientation: Mission.Orientation3 {
        Mission.Orientation3(
            x: pitch.convertDegreesToRadians,
            y: roll.convertDegreesToRadians,
            z: 0
        )
    }
}

extension Mission.CameraAEBCount {
    var parrotValue: CameraBracketingValue {
        switch self {
        case ._3: return .preset1ev
        case ._5: return .preset1ev2ev
        case ._7: return .preset1ev2ev3ev
        case .unknown: return .preset1ev
        @unknown default: return .preset1ev
        }
    }
}

extension Mission.CameraColor {
    var parrotValue: CameraStyle {
        switch self {
        case .none: return .standard
        case .art: return .pastel
        case .blackAndWhite: return .standard
        case .bright: return .intense
        case .dCinelike: return .standard
        case .portrait: return .standard
        case .m31: return .standard
        case .kDX: return .standard
        case .prismo: return .standard
        case .jugo: return .standard
        case .dLog: return .plog
        case .trueColor: return .standard
        case .inverse: return .standard
        case .reminiscence: return .standard
        case .solarize: return .standard
        case .posterize: return .standard
        case .whiteboard: return .standard
        case .blackboard: return .standard
        case .aqua: return .standard
        case .delta: return .standard
        case .dk79: return .standard
        case .vision4: return .standard
        case .vision6: return .standard
        case .trueColorExt: return .standard
        case .filmA: return .standard
        case .filmB: return .standard
        case .filmC: return .standard
        case .filmD: return .standard
        case .filmE: return .standard
        case .filmF: return .standard
        case .filmG: return .standard
        case .filmH: return .standard
        case .filmI: return .standard
        case .hlg: return .standard
        case .unknown: return .standard
        @unknown default: return .standard
        }
    }
}

extension Mission.CameraExposureCompensation {
    var parrotValue: CameraEvCompensation {
        switch self {
        case .n50: return .evMinus3_00
        case .n47: return .evMinus3_00
        case .n43: return .evMinus3_00
        case .n40: return .evMinus3_00
        case .n37: return .evMinus3_00
        case .n33: return .evMinus3_00
        case .n30: return .evMinus3_00
        case .n27: return .evMinus2_67
        case .n23: return .evMinus2_33
        case .n20: return .evMinus2_00
        case .n17: return .evMinus1_67
        case .n13: return .evMinus1_33
        case .n10: return .evMinus1_00
        case .n07: return .evMinus0_67
        case .n03: return .evMinus0_33
        case .n00: return .ev0_00
        case .p03: return .ev0_33
        case .p07: return .ev0_67
        case .p10: return .ev1_00
        case .p13: return .ev1_33
        case .p17: return .ev1_67
        case .p20: return .ev2_00
        case .p23: return .ev2_33
        case .p27: return .ev2_67
        case .p30: return .ev3_00
        case .p33: return .ev3_00
        case .p37: return .ev3_00
        case .p40: return .ev3_00
        case .p43: return .ev3_00
        case .p47: return .ev3_00
        case .p50: return .ev3_00
        case .fixed: return .ev0_00
        case .unknown: return .ev0_00
        @unknown default: return .ev0_00
        }
    }
}

extension Mission.CameraExposureMode {
    var parrotValue: CameraExposureMode {
        switch self {
        case .program: return .automatic
        case .shutterPriority: return .automaticPreferShutterSpeed
        case .aperturePriority: return .automaticPreferIsoSensitivity
        case .manual: return .manual
        case .unknown: return .automatic
        @unknown default: return .automatic
        }
    }
}

extension Mission.CameraISO {
    var parrotValue: CameraIso {
        switch self {
        case .auto: return .iso100
        case ._100: return .iso100
        case ._200: return .iso200
        case ._400: return .iso400
        case ._800: return .iso800
        case ._1600: return .iso1600
        case ._3200: return .iso3200
        case ._6400: return .iso3200
        case ._12800: return .iso3200
        case ._25600: return .iso3200
        case .unknown: return .iso100
        @unknown default: return .iso100
        }
    }
}

extension Mission.CameraMode {
    var parrotValue: CameraMode {
        switch self {
        case .photo: return .photo
        case .video: return .recording
        case .playback: return .photo
        case .download: return .photo
        case .broadcast: return .photo
        case .unknown: return .photo
        @unknown default: return .photo
        }
    }
}

extension Mission.CameraPhotoFileFormat {
    var parrotValue: CameraPhotoFileFormat {
        switch self {
        case .raw: return .dng
        case .jpeg: return .jpeg
        case .rawAndJpeg: return .dngAndJpeg
        case .tiff14bit: return .jpeg
        case .radiometricJpeg: return .jpeg
        case .tiff14bitLinearLowTempResolution: return .jpeg
        case .tiff14bitLinearHighTempResolution: return .jpeg
        case .unknown: return .jpeg
        @unknown default: return .jpeg
        }
    }
}

extension Mission.CameraPhotoMode {
    var parrotValue: CameraPhotoMode {
        switch self {
        case .single: return .single
        case .hdr: return .single
        case .burst: return .burst
        case .aeb: return .bracketing
        case .interval: return .timeLapse
        case .timeLapse: return .timeLapse
        case .rawBurst: return .burst
        case .shallowFocus: return .single
        case .panorama: return .single
        case .ehdr: return .single
        case .hyperLight: return .single
        case .unknown: return .single
        @unknown default: return .single
        }
    }
}

extension Mission.CameraShutterSpeed {
    var parrotValue: CameraShutterSpeed {
        switch self {
        case ._1_8000: return .oneOver8000
        case ._1_6400: return .oneOver6400
        case ._1_6000: return .oneOver6400
        case ._1_5000: return .oneOver5000
        case ._1_4000: return .oneOver4000
        case ._1_3200: return .oneOver3200
        case ._1_3000: return .oneOver3200
        case ._1_2500: return .oneOver2500
        case ._1_2000: return .oneOver2000
        case ._1_1600: return .oneOver1600
        case ._1_1500: return .oneOver1600
        case ._1_1250: return .oneOver1250
        case ._1_1000: return .oneOver1000
        case ._1_800: return .oneOver800
        case ._1_750: return .oneOver800
        case ._1_725: return .oneOver800
        case ._1_640: return .oneOver640
        case ._1_500: return .oneOver500
        case ._1_400: return .oneOver400
        case ._1_350: return .oneOver320
        case ._1_320: return .oneOver320
        case ._1_250: return .oneOver240
        case ._1_240: return .oneOver240
        case ._1_200: return .oneOver200
        case ._1_180: return .oneOver160
        case ._1_160: return .oneOver160
        case ._1_125: return .oneOver120
        case ._1_120: return .oneOver120
        case ._1_100: return .oneOver100
        case ._1_90: return .oneOver100
        case ._1_80: return .oneOver60
        case ._1_60: return .oneOver60
        case ._1_50: return .oneOver50
        case ._1_45: return .oneOver40
        case ._1_40: return .oneOver40
        case ._1_30: return .oneOver30
        case ._1_25: return .oneOver25
        case ._1_20: return .oneOver15
        case ._1_15: return .oneOver15
        case ._1_12dot5: return .oneOver10
        case ._1_10: return .oneOver10
        case ._1_8: return .oneOver8
        case ._1_6dot25: return .oneOver6
        case ._1_6: return .oneOver6
        case ._1_5: return .oneOver4
        case ._1_4: return .oneOver4
        case ._1_3: return .oneOver3
        case ._1_2dot5: return .oneOver2
        case ._0dot3: return .oneOver2
        case ._1_2: return .oneOver2
        case ._1_1dot67: return .oneOver1_5
        case ._1_1dot25: return .oneOver1_5
        case ._0dot7: return .oneOver2
        case ._1: return .one
        case ._1dot3: return .one
        case ._1dot4: return .one
        case ._1dot6: return .one
        case ._2: return .one
        case ._2dot5: return .one
        case ._3: return .one
        case ._3dot2: return .one
        case ._4: return .one
        case ._5: return .one
        case ._6: return .one
        case ._7: return .one
        case ._8: return .one
        case ._9: return .one
        case ._10: return .one
        case ._11: return .one
        case ._13: return .one
        case ._15: return .one
        case ._16: return .one
        case ._20: return .one
        case ._23: return .one
        case ._25: return .one
        case ._30: return .one
        case .unknown: return .one
        @unknown default: return .one
        }
    }
}

extension Mission.CameraVideoFrameRate {
    var parrotValue: CameraRecordingFramerate {
        switch self {
        case ._23dot976: return .fps24
        case ._24: return .fps24
        case ._25: return .fps25
        case ._29dot970: return .fps30
        case ._30: return .fps30
        case ._47dot950: return .fps48
        case ._48: return .fps48
        case ._50: return .fps50
        case ._59dot940: return .fps60
        case ._60: return .fps60
        case ._90: return .fps96
        case ._96: return .fps96
        case ._100: return .fps100
        case ._120: return .fps120
        case ._8dot7: return .fps9
        case .unknown: return .fps24
        @unknown default: return .fps24
        }
    }
}

extension Mission.CameraVideoResolution {
    var parrotValue: CameraRecordingResolution {
        switch self {
        case ._336x256: return .res480p
        case ._640x360: return .res480p
        case ._640x480: return .res480p
        case ._640x512: return .res480p
        case ._1280x720: return .res720p
        case ._1920x1080: return .res1080p
        case ._2048x1080: return .res1080p
        case ._2688x1512: return .res2_7k
        case ._2704x1520: return .res2_7k
        case ._2720x1530: return .res2_7k
        case ._3712x2088: return .resDci4k
        case ._3840x1572: return .resDci4k
        case ._3840x2160: return .resDci4k
        case ._3944x2088: return .resDci4k
        case ._4096x2160: return .resUhd4k
        case ._4608x2160: return .resUhd4k
        case ._4608x2592: return .resUhd4k
        case ._5280x2160: return .resUhd4k
        case ._5280x2972: return .resUhd4k
        case ._5760x3240: return .resUhd4k
        case ._6016x3200: return .resUhd4k
        case .max: return .resUhd4k
        case .noSSDVideo: return .resUhd4k
        case .unknown: return .resUhd4k
        @unknown default: return .resUhd4k
        }
    }
}

extension Mission.CameraWhiteBalancePreset {
    var parrotValue: CameraWhiteBalanceMode {
        switch self {
        case .auto: return .automatic
        case .sunny: return .sunny
        case .cloudy: return .cloudy
        case .waterSurface: return .automatic
        case .indoorIncandescent: return .halogen
        case .indoorFluorescent: return .fluorescent
        case .custom: return .custom
        case .neutral: return .daylight
        case .unknown: return .automatic
        @unknown default: return .automatic
        }
    }
}
