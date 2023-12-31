# SwiftUI Capture

**Taking a picture or recording a video has never been that easy.**

SwiftUI makes UI development more efficient. Although `PhotosPicker` brings access to the Photo Library to SwiftUI, the framework was still lacking the tool to manipulate the camera. This package intends to make it easy to use `AVCaptureSession` from SwiftUI to take pictures or record videos (supporting custom audio/video settings).

## Example

### Taking a picture 📸

```
import Capture

struct ContentView: View {
    @State private var outputPhoto: UIImage?
    var body: some View {
        CameraView(outputImage: $outputPhoto) { authorizationStatus in
            if case .authorized = authorizationStatus { 
                TakePictureOverlay()
            }
        }
    }
}
```

```
struct TakePictureOverlay: View {
    @Environment(\.takePicture) var takePicture

    var body: some View {
        Button(action: { takePicture() }) {
            Text("Take a picture")
        }
    }
}
```


### Recording a video 🎬
```
struct ContentView: View {
    @State private var outputFile: URL?
    var body: some View {
        CameraView(outputVideo: $outputFile) { authorizationStatus in
            if case .authorized = autorizationStatus {
                RecordVideoOverlay()
            }
        }
    }
}
```

```
struct RecordVideoOverlay: View {
    @Environment(\.recordVideo) private var recordVideo
    @State private var isRecording: Bool = false

    var body: some View {
        Button(action: { toggleRecording() }) {
            Image(systemName: isRecording ? "stop.circle" : "record.circle")
        }
    }
    
    func toggleRecording() {
        if isRecording {
            recordVideo.stopRecording()
        } else {
            recordVideo.startRecording()
        }
        isRecording.toggle()
    }
}
```

## Interface


### CameraView

`CameraView` takes the minimum number of parameters to provide the most :

- `camera`: an optional camera object, with a default value set to _Camera.default_. This parameter is only useful to bring control over the camera object outside the camera overlay.

- `outputImage`: an optional binding to an image if the camera view is used to take a picture

- `outputVideo`: an optional binding to a file URL if the camera view is used to record video

> Both `outputImage` and `outputVideo` can be used together if the camera view needs to perform both actions. None can be used if only the camera preview is necessary.

- `options`: a few options that are described below.

- `overlay`: a View Builder closure to build a **camera overlay** that may vary according to the current camera authorization. `CameraView` will automatically request the camera authorization for video when appearing. This behavior can be modified by setting the option `automaticallyRequestsAuthorization` to false, if the camera authorization should be handled separately.


### Environment Values

Provides two actions through environment values **available to the Camera Overlay**

- **@Environment(\.takePicture)** will take a picture and output it to `outputImage`.

- **@Environment(\.recordVideo)** exposes the two following methods: *startRecording()* and *stopRecording()*. When stopped, the recorded video will be saved and the temporary file URL output to `outputVideo`.

- **@EnvironmentObject var camera: Camera** is also available to access fine control over the preview stream (resume/pause the preview) or the camera devices.

### Default behaviors

`CameraView` automatically starts or resumes the `AVCaptureSession` when the view appears, and automatically stops it when the view disappears. This behavior can be modified by setting the option `automaticallyRequestsAuthorization` to false.

When taking a picture, `CameraView` triggers a visual feedback, this behavior can be disabled by settings the option `isTakePictureFeedbackEnabled` to false.


#### Under the hood

`AVCaptureVideoPreviewLayer` is used for the video output

> It seems that `AVCaptureVideoPreviewLayer` is still more efficient than passing `Image(cvImageBuffer: CVImageBuffer)` to SwiftUI from an AsyncStream, which you can see in use in [this example from Apple](https://developer.apple.com/tutorials/sample-apps/capturingphotos-camerapreview).

### Coming soon...

- Support for Flash, Torch, Focus & Exposure
- Support for custom photo settings
