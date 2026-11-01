import AVFoundation
import Foundation
import Onboarding

/// The one permission attachments need: the camera. Photos and Files pickers run out of process
/// and need none. Put it in an onboarding permission primer only when the camera is the app's
/// point; otherwise the Camera entry asks on the first tap, as Apple advises.
public struct CameraPermission: PermissionRequesting {
    public init() {}

    /// The system's current answer without prompting.
    public static var status: PermissionOutcome? {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .granted
        case .denied: .denied
        case .restricted: .unavailable
        case .notDetermined: nil
        @unknown default: nil
        }
    }

    public func request() async -> PermissionOutcome {
        if let status = Self.status { return status }
        return await AVCaptureDevice.requestAccess(for: .video) ? .granted : .denied
    }
}
