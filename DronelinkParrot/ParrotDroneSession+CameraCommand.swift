//
//  ParrotDroneSession+CameraCommand.swift
//  DronelinkParrot
//
//  Created by Jim McAndrew on 11/20/19.
//  Copyright © 2019 Dronelink. All rights reserved.
//
import Foundation
import DronelinkCore
import GroundSdk
import os

extension ParrotDroneSession {
    func execute(cameraCommand: MissionCameraCommand, finished: @escaping CommandFinished) -> Error? {
        guard let adapter = (adapter.camera(channel: cameraCommand.channel) as? ParrotCameraAdapter) else {
            return "MissionDisengageReason.drone.camera.unavailable.title".localized
        }
        
        if let command = cameraCommand as? Mission.AEBCountCameraCommand {
            adapter.camera.photoSettings.bracketingValue = command.aebCount.parrotValue
            finished(nil)
            return nil
        }
        
        if cameraCommand is Mission.ApertureCameraCommand {
            return "MissionDisengageReason.command.type.unsupported".localized
        }

        if let command = cameraCommand as? Mission.AutoExposureLockCameraCommand {
            if let exposureLock = adapter.camera.exposureLock {
                if (command.enabled) {
                    exposureLock.lockOnCurrentValues()
                }
                else {
                    exposureLock.unlock()
                }
            }
            return "MissionDisengageReason.command.type.unsupported".localized
        }

        if let command = cameraCommand as? Mission.ColorCameraCommand {
            adapter.camera.styleSettings.activeStyle = command.color.parrotValue
            finished(nil)
            return nil
        }

        if let command = cameraCommand as? Mission.ContrastCameraCommand {
            adapter.camera.styleSettings.contrast.value = Int(command.contrast)
            finished(nil)
            return nil
        }

        if let command = cameraCommand as? Mission.ExposureCompensationCameraCommand {
            adapter.camera.exposureCompensationSetting.value = command.exposureCompensation.parrotValue
            finished(nil)
            return nil
        }

        if let command = cameraCommand as? Mission.ExposureModeCameraCommand {
            adapter.camera.exposureSettings.set(mode: command.exposureMode.parrotValue, manualShutterSpeed: nil, manualIsoSensitivity: nil, maximumIsoSensitivity: nil)
            finished(nil)
            return nil
        }
        
        if cameraCommand is Mission.FileIndexModeCameraCommand {
            return "MissionDisengageReason.command.type.unsupported".localized
        }

        if cameraCommand is Mission.FocusModeCameraCommand {
            return "MissionDisengageReason.command.type.unsupported".localized
        }

        if let command = cameraCommand as? Mission.ISOCameraCommand {
            adapter.camera.exposureSettings.set(mode: .manualIsoSensitivity, manualShutterSpeed: nil, manualIsoSensitivity: command.iso.parrotValue, maximumIsoSensitivity: nil)
            finished(nil)
            return nil
        }

        if let command = cameraCommand as? Mission.ModeCameraCommand {
            adapter.camera.modeSetting.mode = command.mode.parrotValue
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { finished(nil) }
            return nil
        }
        

        if cameraCommand is Mission.PhotoAspectRatioCameraCommand {
            return "MissionDisengageReason.command.type.unsupported".localized
        }

        if let command = cameraCommand as? Mission.PhotoFileFormatCameraCommand {
            adapter.camera.photoSettings.fileFormat = command.photoFileFormat.parrotValue
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { finished(nil) }
            return nil
        }

        if let command = cameraCommand as? Mission.PhotoIntervalCameraCommand {
            adapter.camera.photoSettings.timelapseCaptureInterval = Double(command.photoInterval)
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { finished(nil) }
            return nil
        }

        if let command = cameraCommand as? Mission.PhotoModeCameraCommand {
            adapter.camera.photoSettings.mode = command.photoMode.parrotValue
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { finished(nil) }
            return nil
        }

        if let command = cameraCommand as? Mission.SaturationCameraCommand {
            adapter.camera.styleSettings.saturation.value = Int(command.saturation)
            finished(nil)
            return nil
        }

        if let command = cameraCommand as? Mission.SharpnessCameraCommand {
            adapter.camera.styleSettings.sharpness.value = Int(command.sharpness)
            finished(nil)
            return nil
        }

        if let command = cameraCommand as? Mission.ShutterSpeedCameraCommand {
            adapter.camera.exposureSettings.set(mode: .manualShutterSpeed, manualShutterSpeed: command.shutterSpeed.parrotValue, manualIsoSensitivity: nil, maximumIsoSensitivity: nil)
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { finished(nil) }
            return nil
        }

        if cameraCommand is Mission.StartCaptureCameraCommand {
            switch adapter.missionMode {
            case .photo:
                if adapter.isCapturingPhotoInterval {
                    os_log(.debug, log: log, "Camera start capture skipped, already shooting interval photos")
                    finished(nil)
                }
                else if adapter.camera.canStartPhotoCapture {
                    os_log(.debug, log: log, "Camera start capture photo")
                    adapter.camera.startPhotoCapture()
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                        finished(nil)
                    }
                }
                else {
                    return "MissionDisengageReason.drone.camera.start.photo.failed.title".localized
                }
                break

            case .video:
                if adapter.isCapturingVideo {
                    os_log(.debug, log: log, "Camera start capture skipped, already recording video")
                    finished(nil)
                }
                else if adapter.camera.canStartRecord {
                    os_log(.debug, log: log, "Camera start capture video")
                    adapter.camera.startRecording()
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                        finished(nil)
                    }
                }
                else {
                    return "MissionDisengageReason.drone.camera.start.video.failed.title".localized
                }
                break

            default:
                os_log(.info, log: log, "Camera start capture invalid mode: %d", adapter.missionMode.parrotValue.rawValue)
                return "MissionDisengageReason.drone.camera.mode.invalid.title".localized
            }
            return nil
        }

        if cameraCommand is Mission.StopCaptureCameraCommand {
            switch adapter.missionMode {
            case .photo:
                if adapter.isCapturingPhotoInterval {
                    if adapter.camera.canStopPhotoCapture {
                        os_log(.debug, log: log, "Camera stop capture interval photo")
                        adapter.camera.stopPhotoCapture()
                        finished(nil)
                    }
                    else {
                        return "MissionDisengageReason.drone.camera.stop.photo.failed.title".localized
                    }
                }
                else {
                    os_log(.debug, log: log, "Camera stop capture skipped, not shooting interval photos")
                    finished(nil)
                }
                break

            case .video:
                if adapter.isCapturingVideo {
                    if adapter.camera.canStopRecord {
                        os_log(.debug, log: log, "Camera stop capture video")
                        adapter.camera.stopRecording()
                        finished(nil)
                    }
                    else {
                        return "MissionDisengageReason.drone.camera.stop.video.failed.title".localized
                    }
                }
                else {
                    os_log(.debug, log: log, "Camera stop capture skipped, not recording video")
                    finished(nil)
                }
                break

            default:
                os_log(.info, log: log, "Camera stop capture skipped, invalid mode: %d", adapter.missionMode.parrotValue.rawValue)
                finished(nil)
                break
            }
            return nil
        }

        if cameraCommand is Mission.StorageLocationCameraCommand {
            return "MissionDisengageReason.command.type.unsupported".localized
        }

        if cameraCommand is Mission.VideoFileCompressionStandardCameraCommand {
            return "MissionDisengageReason.command.type.unsupported".localized
        }

        if cameraCommand is Mission.VideoFileFormatCameraCommand {
            return "MissionDisengageReason.command.type.unsupported".localized
        }

        if let command = cameraCommand as? Mission.VideoResolutionFrameRateCameraCommand {
            adapter.camera.recordingSettings.framerate = command.videoFrameRate.parrotValue
            adapter.camera.recordingSettings.resolution = command.videoResolution.parrotValue
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { finished(nil) }
            return nil
        }

        if cameraCommand is Mission.VideoStandardCameraCommand {
            return "MissionDisengageReason.command.type.unsupported".localized
        }

        if let command = cameraCommand as? Mission.WhiteBalanceCustomCameraCommand {
            adapter.camera.whiteBalanceSettings.mode = .custom
            adapter.camera.whiteBalanceSettings.customTemperature = CameraWhiteBalanceTemperature(rawValue: Int(command.whiteBalanceCustom)) ?? .k10000
            finished(nil)
            return nil
        }

        if let command = cameraCommand as? Mission.WhiteBalancePresetCameraCommand {
            adapter.camera.whiteBalanceSettings.mode = command.whiteBalancePreset.parrotValue
            finished(nil)
            return nil
        }
        
        return "MissionDisengageReason.command.type.unhandled".localized
    }
}
