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
    func execute(cameraCommand: KernelCameraCommand, finished: @escaping CommandFinished) -> Error? {
        guard let adapter = (adapter.camera(channel: cameraCommand.channel) as? ParrotCameraAdapter) else {
            return "MissionDisengageReason.drone.camera.unavailable.title".localized
        }
        
        //FIXME
//        if let command = cameraCommand as? Kernel.AEBCountCameraCommand {
//            adapter.camera.photoSettings.bracketingValue = command.aebCount.parrotValue
//            finished(nil)
//            return nil
//        }

        if cameraCommand is Kernel.ApertureCameraCommand {
            return "MissionDisengageReason.command.type.unsupported".localized
        }

//        if let command = cameraCommand as? Kernel.AutoExposureLockCameraCommand {
//            if let exposureLock = adapter.camera.exposureLock {
//                if (command.enabled) {
//                    exposureLock.lockOnCurrentValues()
//                }
//                else {
//                    exposureLock.unlock()
//                }
//            }
//            return "MissionDisengageReason.command.type.unsupported".localized
//        }
//
//        if let command = cameraCommand as? Kernel.ColorCameraCommand {
//            adapter.camera.styleSettings.activeStyle = command.color.parrotValue
//            finished(nil)
//            return nil
//        }
//
//        if let command = cameraCommand as? Kernel.ContrastCameraCommand {
//            adapter.camera.styleSettings.contrast.value = Int(command.contrast)
//            finished(nil)
//            return nil
//        }
//
//        if let command = cameraCommand as? Kernel.ExposureCompensationCameraCommand {
//            adapter.camera.exposureCompensationSetting.value = command.exposureCompensation.parrotValue
//            finished(nil)
//            return nil
//        }
//
//        if let command = cameraCommand as? Kernel.ExposureModeCameraCommand {
//            adapter.camera.exposureSettings.set(mode: command.exposureMode.parrotValue, manualShutterSpeed: nil, manualIsoSensitivity: nil, maximumIsoSensitivity: nil)
//            finished(nil)
//            return nil
//        }

        if cameraCommand is Kernel.FileIndexModeCameraCommand {
            return "MissionDisengageReason.command.type.unsupported".localized
        }

        if cameraCommand is Kernel.FocusModeCameraCommand {
            return "MissionDisengageReason.command.type.unsupported".localized
        }

        if cameraCommand is Kernel.FocusDistanceCameraCommand {
            return "MissionDisengageReason.command.type.unsupported".localized
        }

        if cameraCommand is Kernel.FocusRingCameraCommand {
            return "MissionDisengageReason.command.type.unsupported".localized
        }

//        if let command = cameraCommand as? Kernel.ISOCameraCommand {
//            adapter.camera.exposureSettings.set(mode: .manualIsoSensitivity, manualShutterSpeed: nil, manualIsoSensitivity: command.iso.parrotValue, maximumIsoSensitivity: nil)
//            finished(nil)
//            return nil
//        }

        if let command = cameraCommand as? Kernel.ModeCameraCommand {
            let editor = adapter.camera.config.edit(fromScratch: false)
            cameraEditorStart(adapter: adapter, cameraCommand: command, editor: editor, configParam: editor[Camera2Params.mode], value: command.mode.parrotValue, finished: finished)
            return nil
        }

//        if cameraCommand is Kernel.PhotoAspectRatioCameraCommand {
//            return "MissionDisengageReason.command.type.unsupported".localized
//        }
//
//        if let command = cameraCommand as? Kernel.PhotoFileFormatCameraCommand {
//            adapter.camera.photoSettings.fileFormat = command.photoFileFormat.parrotValue
//            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { finished(nil) }
//            return nil
//        }
//
//        if let command = cameraCommand as? Kernel.PhotoIntervalCameraCommand {
//            adapter.camera.photoSettings.timelapseCaptureInterval = Double(command.photoInterval)
//            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { finished(nil) }
//            return nil
//        }

        if let command = cameraCommand as? Kernel.PhotoModeCameraCommand {
            let editor = adapter.camera.config.edit(fromScratch: false)
            cameraEditorStart(adapter: adapter, cameraCommand: command, editor: editor, configParam: editor[Camera2Params.photoMode], value: command.photoMode.parrotValue, finished: finished)
            return nil
        }

//        if let command = cameraCommand as? Kernel.SaturationCameraCommand {
//            adapter.camera.styleSettings.saturation.value = Int(command.saturation)
//            finished(nil)
//            return nil
//        }
//
//        if let command = cameraCommand as? Kernel.SharpnessCameraCommand {
//            adapter.camera.styleSettings.sharpness.value = Int(command.sharpness)
//            finished(nil)
//            return nil
//        }
//
//        if let command = cameraCommand as? Kernel.ShutterSpeedCameraCommand {
//            adapter.camera.exposureSettings.set(mode: .manualShutterSpeed, manualShutterSpeed: command.shutterSpeed.parrotValue, manualIsoSensitivity: nil, maximumIsoSensitivity: nil)
//            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { finished(nil) }
//            return nil
//        }

        if cameraCommand is Kernel.StartCaptureCameraCommand {
            switch adapter.mode {
            case .photo:
                if adapter.isCapturingPhotoInterval {
                    os_log(.debug, log: ParrotDroneSession.log, "Camera start capture skipped, already shooting interval photos")
                    finished(nil)
                }
                else if adapter.photoCapture?.state.canStart ?? false {
                    os_log(.debug, log: ParrotDroneSession.log, "Camera start capture photo")
                    adapter.photoCapture?.start()
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
                    os_log(.debug, log: ParrotDroneSession.log, "Camera start capture skipped, already recording video")
                    finished(nil)
                }
                else if adapter.recording?.state.canStart ?? false {
                    os_log(.debug, log: ParrotDroneSession.log, "Camera start capture video")
                    adapter.recording?.start()
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                        finished(nil)
                    }
                }
                else {
                    return "MissionDisengageReason.drone.camera.start.video.failed.title".localized
                }
                break

            default:
                os_log(.info, log: ParrotDroneSession.log, "Camera start capture invalid mode: %d", adapter.mode.parrotValue.rawValue)
                return "MissionDisengageReason.drone.camera.mode.invalid.title".localized
            }
            return nil
        }

        if cameraCommand is Kernel.StopCaptureCameraCommand {
            switch adapter.mode {
            case .photo:
                if adapter.isCapturingPhotoInterval {
                    if adapter.photoCapture?.state.canStop ?? false {
                        os_log(.debug, log: ParrotDroneSession.log, "Camera stop capture interval photo")
                        adapter.photoCapture?.stop()
                        finished(nil)
                    }
                    else {
                        return "MissionDisengageReason.drone.camera.stop.photo.failed.title".localized
                    }
                }
                else {
                    os_log(.debug, log: ParrotDroneSession.log, "Camera stop capture skipped, not shooting interval photos")
                    finished(nil)
                }
                break

            case .video:
                if adapter.isCapturingVideo {
                    if adapter.recording?.state.canStop ?? false {
                        os_log(.debug, log: ParrotDroneSession.log, "Camera stop capture video")
                        adapter.recording?.stop()
                        finished(nil)
                    }
                    else {
                        return "MissionDisengageReason.drone.camera.stop.video.failed.title".localized
                    }
                }
                else {
                    os_log(.debug, log: ParrotDroneSession.log, "Camera stop capture skipped, not recording video")
                    finished(nil)
                }
                break

            default:
                os_log(.info, log: ParrotDroneSession.log, "Camera stop capture skipped, invalid mode: %d", adapter.mode.parrotValue.rawValue)
                finished(nil)
                break
            }
            return nil
        }

        if cameraCommand is Kernel.StorageLocationCameraCommand {
            return "MissionDisengageReason.command.type.unsupported".localized
        }

        if cameraCommand is Kernel.VideoFileCompressionStandardCameraCommand {
            return "MissionDisengageReason.command.type.unsupported".localized
        }

        if cameraCommand is Kernel.VideoFileFormatCameraCommand {
            return "MissionDisengageReason.command.type.unsupported".localized
        }

//        if let command = cameraCommand as? Kernel.VideoResolutionFrameRateCameraCommand {
//            adapter.camera.recordingSettings.framerate = command.videoFrameRate.parrotValue
//            adapter.camera.recordingSettings.resolution = command.videoResolution.parrotValue
//            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { finished(nil) }
//            return nil
//        }
//
//        if cameraCommand is Kernel.VideoStandardCameraCommand {
//            return "MissionDisengageReason.command.type.unsupported".localized
//        }
//
//        if let command = cameraCommand as? Kernel.WhiteBalanceCustomCameraCommand {
//            adapter.camera.whiteBalanceSettings.mode = .custom
//            adapter.camera.whiteBalanceSettings.customTemperature = CameraWhiteBalanceTemperature(rawValue: Int(command.whiteBalanceCustom)) ?? .k10000
//            finished(nil)
//            return nil
//        }
//
//        if let command = cameraCommand as? Kernel.WhiteBalancePresetCameraCommand {
//            adapter.camera.whiteBalanceSettings.mode = command.whiteBalancePreset.parrotValue
//            finished(nil)
//            return nil
//        }
        
        return "MissionDisengageReason.command.type.unhandled".localized
    }
    
    func cameraEditorStart<V>(adapter: ParrotCameraAdapter, cameraCommand: KernelCameraCommand, editor: Camera2Editor, configParam: Camera2EditableParam<V>?, value: V, finished: @escaping CommandFinished) {
        guard let configParam = configParam else {
            finished("MissionDisengageReason.command.type.unsupported".localized)
            return
        }
        
        configParam.value = value
        editor.autoComplete().commit()
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.cameraEditorFinish(cameraCommand: cameraCommand, editor: editor, finished: finished)
        }
    }
    
    func cameraEditorFinish(cameraCommand: KernelCameraCommand, editor: Camera2Editor, attempt: Int = 0, maxAttempts: Int = 20, finished: @escaping CommandFinished) {
        if editor.complete {
            finished(nil)
            return
        }
        
        if attempt >= maxAttempts {
            finished(nil)
            return
        }
        
        os_log(.debug, log: ParrotDroneSession.log, "Waiting for camera editor to complete (%{public}d)... (%{public}s)", attempt, cameraCommand.id)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.cameraEditorFinish(cameraCommand: cameraCommand, editor: editor, attempt: attempt + 1, maxAttempts: maxAttempts, finished: finished)
        }
    }
}
