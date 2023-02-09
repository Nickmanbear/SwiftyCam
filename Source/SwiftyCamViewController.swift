/*Copyright (c) 2016, Andrew Walz.

Redistribution and use in source and binary forms, with or without modification,are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS
BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import UIKit
import AVFoundation

// MARK: View Controller Declaration

/// A UIViewController Camera View Subclass
@objcMembers open class SwiftyCamViewController: UIViewController {

	// MARK: Enumeration Declaration

	/// Enumeration for Camera Selection

	@objc public enum CameraSelection: Int {

		/// Camera on the back of the device
		case rear

		/// Camera on the front of the device
		case front
	}

	/// Enumeration for video quality of the capture session. Corresponds to a AVCaptureSessionPreset


	@objc public enum VideoQuality: Int {
        
		/// AVCaptureSessionPresetHigh
		case high

		/// AVCaptureSessionPresetMedium
		case medium

		/// AVCaptureSessionPresetLow
		case low

		/// AVCaptureSessionPreset352x288
		case resolution352x288

		/// AVCaptureSessionPreset640x480
		case resolution640x480

		/// AVCaptureSessionPreset1280x720
		case resolution1280x720

		/// AVCaptureSessionPreset1920x1080
		case resolution1920x1080

		/// AVCaptureSessionPreset3840x2160
		case resolution3840x2160

		/// AVCaptureSessionPresetiFrame960x540
		case iframe960x540

		/// AVCaptureSessionPresetiFrame1280x720
		case iframe1280x720
        
        /// AVCaptureSessionPresetPhoto
        case photo
	}

	/**

	Result from the AVCaptureSession Setup

	- success: success
	- notAuthorized: User denied access to Camera of Microphone
	- configurationFailed: Unknown error
	*/

	@objc public enum SessionSetupResult: Int {
		case success
		case notAuthorized
		case configurationFailed
	}

	// MARK: Public Variable Declarations

	/// Public Camera Delegate for the Custom View Controller Subclass

	public weak var cameraDelegate: SwiftyCamViewControllerDelegate?

	/// Maxiumum video duration if SwiftyCamButton is used

	public var maximumVideoDuration : Double     = 0.0

	/// Video capture quality

	public var videoQuality : VideoQuality       = .high

	/// Disable audio
	public var disableAudio											 = false

	/// Sets whether flash is enabled for photo and video capture

	public var flashEnabled                      = false

	/// Sets whether Pinch to Zoom is enabled for the capture session

	public var pinchToZoom                       = true

	/// Sets the maximum zoom scale allowed during gestures gesture

	public var maxZoomScale				         = CGFloat.greatestFiniteMagnitude

	/// Sets whether Tap to Focus and Tap to Adjust Exposure is enabled for the capture session

	public var tapToFocus                        = true

	/// Sets whether the capture session should adjust to low light conditions automatically
	///
	/// Only supported on iPhone 5 and 5C

	public var lowLightBoost                     = true

	/// Set whether SwiftyCam should allow background audio from other applications

	public var allowBackgroundAudio              = true

	/// Sets whether a double tap to switch cameras is supported

	public var doubleTapCameraSwitch            = true

    /// Sets whether swipe vertically to zoom is supported

    public var swipeToZoom                     = true

    /// Sets whether swipe vertically gestures should be inverted

    public var swipeToZoomInverted             = false

	/// Set default launch camera

	public var defaultCamera                   = CameraSelection.rear

	/// Sets wether the taken photo or video should be oriented according to the device orientation

    public var shouldUseDeviceOrientation      = false {
        didSet {
            orientation.shouldUseDeviceOrientation = shouldUseDeviceOrientation
        }
    }

    /// Sets whether or not View Controller supports auto rotation

    public var allowAutoRotate                = false

    /// Specifies the [videoGravity](https://developer.apple.com/reference/avfoundation/avcapturevideopreviewlayer/1386708-videogravity) for the preview layer.
    public var videoGravity                   : SwiftyCamVideoGravity = .resizeAspectFill {
        didSet {
            previewLayer.gravity = videoGravity
        }
    }

    /// Sets whether or not video recordings will record audio
    /// Setting to true will prompt user for access to microphone on View Controller launch.
    public var audioEnabled                   = true

    /// Sets whether or not app should display prompt to app settings if audio/video permission is denied
    /// If set to false, delegate function will be called to handle exception
    public var shouldPrompToAppSettings       = true

    /// Video will be recorded to this folder
    public var outputFolder: String           = NSTemporaryDirectory()
    
    /// Public access to Pinch Gesture
    fileprivate(set) public var pinchGesture  : UIPinchGestureRecognizer!

    /// Public access to Pan Gesture
    fileprivate(set) public var panGesture    : UIPanGestureRecognizer!


	// MARK: Public Get-only Variable Declarations

	/// Returns true if video is currently being recorded

	private(set) public var isVideoRecording      = false

	/// Returns true if the capture session is currently running

	private(set) public var isSessionRunning     = false

	/// Returns the CameraSelection corresponding to the currently utilized camera

	private(set) public var currentCamera        = CameraSelection.rear

	// MARK: Private Constant Declarations

	/// Current Capture Session

	public let session                           = AVCaptureSession()

	/// Serial queue used for setting up session

	public let sessionQueue                 = DispatchQueue(label: "session queue", attributes: [])

	// MARK: Private Variable Declarations

	/// Variable for storing current zoom scale

	public var zoomScale                    = CGFloat(1.0)

	/// Variable for storing initial zoom scale before Pinch to Zoom begins

	public var beginZoomScale               = CGFloat(1.0)

	/// Returns true if the torch (flash) is currently enabled

	public var isCameraTorchOn              = false

	/// Variable to store result of capture session setup

	public var setupResult                  = SessionSetupResult.success

	/// BackgroundID variable for video recording

	public var backgroundRecordingID        : UIBackgroundTaskIdentifier? = nil

	/// Video Input variable

	public var videoDeviceInput             : AVCaptureDeviceInput!

	/// Movie File Output variable

	public var movieFileOutput              : AVCaptureMovieFileOutput?

	/// Photo File Output variable

	public var photoFileOutput              : AVCaptureStillImageOutput?

	/// Video Device variable

	public var videoDevice                  : AVCaptureDevice?

	/// PreviewView for the capture session

	public var previewLayer                 : PreviewView!

	/// UIView for front facing flash

	public var flashView                    : UIView?

    /// Pan Translation

    public var previousPanTranslation       : CGFloat = 0.0

	/// Last changed orientation

    public var orientation                  : Orientation = Orientation()

    /// Boolean to store when View Controller is notified session is running

    public var sessionRunning               = false

	/// Disable view autorotation for forced portrait recorindg

	override open var shouldAutorotate: Bool {
		return allowAutoRotate
	}

	public var videoCodecType: AVVideoCodecType? = nil

	// MARK: ViewDidLoad

	/// ViewDidLoad Implementation

	override open func viewDidLoad() {
		super.viewDidLoad()
        previewLayer = PreviewView(frame: view.frame, videoGravity: videoGravity)
        previewLayer.center = view.center
        view.addSubview(previewLayer)
        view.sendSubviewToBack(previewLayer)

		// Add Gesture Recognizers

        addGestureRecognizers()

		previewLayer.session = session

		// Test authorization status for Camera and Micophone

		switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
		case .authorized:

			// already authorized
			break
		case .notDetermined:

			// not yet determined
			sessionQueue.suspend()
			AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { [unowned self] granted in
				if !granted {
					self.setupResult = .notAuthorized
				}
				self.sessionQueue.resume()
			})
		default:

			// already been asked. Denied access
			setupResult = .notAuthorized
		}
		sessionQueue.async { [unowned self] in
			self.configureSession()
		}
	}

    // MARK: ViewDidLayoutSubviews

    /// ViewDidLayoutSubviews() Implementation
    private func updatePreviewLayer(layer: AVCaptureConnection, orientation: AVCaptureVideoOrientation) {

        layer.videoOrientation = orientation

        previewLayer.frame = self.view.bounds

    }
    
    
    private func updatePreviewLayer() {
           if let connection =  self.previewLayer?.videoPreviewLayer.connection  {

               let currentDevice: UIDevice = UIDevice.current

               let orientation: UIDeviceOrientation = currentDevice.orientation

               let previewLayerConnection : AVCaptureConnection = connection

               if previewLayerConnection.isVideoOrientationSupported {

                   switch (orientation) {
                   case .portrait: updatePreviewLayer(layer: previewLayerConnection, orientation: .portrait)

                       break

                   case .landscapeRight: updatePreviewLayer(layer: previewLayerConnection, orientation: .landscapeLeft)

                       break

                   case .landscapeLeft: updatePreviewLayer(layer: previewLayerConnection, orientation: .landscapeRight)

                       break

                   case .portraitUpsideDown: updatePreviewLayer(layer: previewLayerConnection, orientation: .portraitUpsideDown)

                       break

                   default: updatePreviewLayer(layer: previewLayerConnection, orientation: .portrait)

                       break
                   }
               }
           }
       }


    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updatePreviewLayer()
    }

    // MARK: ViewWillAppear

    /// ViewWillAppear(_ animated:) Implementation

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(captureSessionDidStartRunning), name: .AVCaptureSessionDidStartRunning, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(captureSessionDidStopRunning),  name: .AVCaptureSessionDidStopRunning,  object: nil)
    }

	// MARK: ViewDidAppear

	/// ViewDidAppear(_ animated:) Implementation
	override open func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		// Subscribe to device rotation notifications

		if shouldUseDeviceOrientation {
			orientation.start()
		}

		// Set background audio preference

		setBackgroundAudioPreference()

		sessionQueue.async {
			switch self.setupResult {
			case .success:
				// Begin Session
				self.session.startRunning()
				self.isSessionRunning = self.session.isRunning

                // Preview layer video orientation can be set only after the connection is created
                DispatchQueue.main.async {
                    self.previewLayer.videoPreviewLayer.connection?.videoOrientation = self.orientation.getPreviewLayerOrientation()
                    self.updatePreviewLayer()
                }

			case .notAuthorized:
                if self.shouldPrompToAppSettings == true {
                    self.promptToAppSettings()
                } else {
                    self.cameraDelegate?.swiftyCamNotAuthorized(self)
                }
			case .configurationFailed:
				// Unknown Error
                DispatchQueue.main.async {
                    self.cameraDelegate?.swiftyCamDidFailToConfigure(self)
                }
			}
		}
	}

	// MARK: ViewDidDisappear

	/// ViewDidDisappear(_ animated:) Implementation


	override open func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)

        NotificationCenter.default.removeObserver(self)
        sessionRunning = false

		// If session is running, stop the session
		if self.isSessionRunning == true {
			self.session.stopRunning()
			self.isSessionRunning = false
		}

		//Disble flash if it is currently enabled
		disableFlash()

		// Unsubscribe from device rotation notifications
		if shouldUseDeviceOrientation {
			orientation.stop()
		}
	}

	// MARK: Public Functions

	/**

	Capture photo from current session

	UIImage will be returned with the SwiftyCamViewControllerDelegate function SwiftyCamDidTakePhoto(photo:)

	*/

	public func takePhoto() {

		guard let device = videoDevice else {
			return
		}


		if device.hasFlash == true && flashEnabled == true /* TODO: Add Support for Retina Flash and add front flash */ {
			changeFlashSettings(device: device, mode: .on)
			capturePhotoAsyncronously(completionHandler: { (_) in })

		} else if device.hasFlash == false && flashEnabled == true && currentCamera == .front {
			flashView = UIView(frame: view.frame)
			flashView?.alpha = 0.0
			flashView?.backgroundColor = UIColor.white
			previewLayer.addSubview(flashView!)

			UIView.animate(withDuration: 0.1, delay: 0.0, options: .curveEaseInOut, animations: {
				self.flashView?.alpha = 1.0

			}, completion: { (_) in
				self.capturePhotoAsyncronously(completionHandler: { (success) in
					UIView.animate(withDuration: 0.1, delay: 0.0, options: .curveEaseInOut, animations: {
						self.flashView?.alpha = 0.0
					}, completion: { (_) in
						self.flashView?.removeFromSuperview()
					})
				})
			})
		} else {
			if device.isFlashActive == true {
				changeFlashSettings(device: device, mode: .off)
			}
			capturePhotoAsyncronously(completionHandler: { (_) in })
		}
	}

	/**

	Begin recording video of current session

	SwiftyCamViewControllerDelegate function SwiftyCamDidBeginRecordingVideo() will be called

	*/

	public func startVideoRecording() {

        guard sessionRunning == true else {
            print("[SwiftyCam]: Cannot start video recoding. Capture session is not running")
            return
        }
		guard let movieFileOutput = self.movieFileOutput else {
			return
		}

		if currentCamera == .rear && flashEnabled == true {
			enableFlash()
		}

		if currentCamera == .front && flashEnabled == true {
			flashView = UIView(frame: view.frame)
			flashView?.backgroundColor = UIColor.white
			flashView?.alpha = 0.85
			previewLayer.addSubview(flashView!)
		}

        //Must be fetched before on main thread
        let previewOrientation = previewLayer.videoPreviewLayer.connection!.videoOrientation

		updateVideoPreset()

		sessionQueue.async { [unowned self] in
			if !movieFileOutput.isRecording {
				if UIDevice.current.isMultitaskingSupported {
					self.backgroundRecordingID = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
				}

				// Update the orientation on the movie file output video connection before starting recording.
				let movieFileOutputConnection = self.movieFileOutput?.connection(with: AVMediaType.video)


				//flip video output if front facing camera is selected
				if self.currentCamera == .front {
					movieFileOutputConnection?.isVideoMirrored = true
				}

				movieFileOutputConnection?.videoOrientation = self.orientation.getVideoOrientation() ?? previewOrientation

				// Start recording to a temporary file.
				let outputFileName = UUID().uuidString
				let outputFilePath = (self.outputFolder as NSString).appendingPathComponent((outputFileName as NSString).appendingPathExtension("mov")!)
				movieFileOutput.startRecording(to: URL(fileURLWithPath: outputFilePath), recordingDelegate: self)
				self.isVideoRecording = true
				DispatchQueue.main.async {
					self.cameraDelegate?.swiftyCam(self, didBeginRecordingVideo: self.currentCamera)
				}
			}
			else {
				movieFileOutput.stopRecording()
			}
		}
	}

	/**

	Stop video recording video of current session

	SwiftyCamViewControllerDelegate function SwiftyCamDidFinishRecordingVideo() will be called

	When video has finished processing, the URL to the video location will be returned by SwiftyCamDidFinishProcessingVideoAt(url:)

	*/

	public func stopVideoRecording() {
		if self.isVideoRecording == true {
			self.isVideoRecording = false
			movieFileOutput!.stopRecording()
			disableFlash()

			if currentCamera == .front && flashEnabled == true && flashView != nil {
				UIView.animate(withDuration: 0.1, delay: 0.0, options: .curveEaseInOut, animations: {
					self.flashView?.alpha = 0.0
				}, completion: { (_) in
					self.flashView?.removeFromSuperview()
				})
			}
			DispatchQueue.main.async {
				self.cameraDelegate?.swiftyCam(self, didFinishRecordingVideo: self.currentCamera)
			}
		}
	}

	/**

	Switch between front and rear camera

	SwiftyCamViewControllerDelegate function SwiftyCamDidSwitchCameras(camera:  will be return the current camera selection

	*/


	public func switchCamera() {
		guard isVideoRecording != true else {
			//TODO: Look into switching camera during video recording
			print("[SwiftyCam]: Switching between cameras while recording video is not supported")
			return
		}

        guard session.isRunning == true else {
            return
        }

		switch currentCamera {
		case .front:
			currentCamera = .rear
		case .rear:
			currentCamera = .front
		}

		session.stopRunning()

		sessionQueue.async { [unowned self] in

			// remove and re-add inputs and outputs

			for input in self.session.inputs {
				self.session.removeInput(input )
			}

			self.addInputs()
			DispatchQueue.main.async {
				self.cameraDelegate?.swiftyCam(self, didSwitchCameras: self.currentCamera)
			}

			self.session.startRunning()
		}

		// If flash is enabled, disable it as the torch is needed for front facing camera
		disableFlash()
	}

	// MARK: Private Functions

	/// Configure session, add inputs and outputs

	fileprivate func configureSession() {
		guard setupResult == .success else {
			return
		}

		// Set default camera

		currentCamera = defaultCamera

		// begin configuring session

		session.beginConfiguration()
		configureVideoPreset()
		addVideoInput()
		if disableAudio == false {
			addAudioInput()
		}
		configureVideoOutput()
		configurePhotoOutput()

		session.commitConfiguration()
	}

	/// Add inputs after changing camera()

	fileprivate func addInputs() {
		session.beginConfiguration()
		configureVideoPreset()
		addVideoInput()
		if disableAudio == false {
			addAudioInput()
		}
		session.commitConfiguration()
	}


	private func updateVideoPreset() {
		session.beginConfiguration()
		configureVideoPreset()
		session.commitConfiguration()
	}

	// If set video quality is not supported, videoQuality variable will be set to 480p
	/// Configure image quality preset

	fileprivate func configureVideoPreset() {
		if session.canSetSessionPreset(AVCaptureSession.Preset(rawValue: videoInputPresetFromVideoQuality(quality: videoQuality))) {
			session.sessionPreset = AVCaptureSession.Preset(rawValue: videoInputPresetFromVideoQuality(quality: videoQuality))
		} else {
			session.sessionPreset = AVCaptureSession.Preset(rawValue: videoInputPresetFromVideoQuality(quality: .resolution640x480))
		}
	}
    
    public func getAvailablePictureSizes(_ ratio: String) -> [String]{
        cachedPictureRatioSizeMap[ratio]?.map({ (dim) -> String in
            return String(dim.width) + "x" + String(dim.height)
        }) ?? []
    }
    
    private var cachedPictureRatioSizeMap: [String:[CMVideoDimensions]] = [:]
    
    var pictureSize = "0x0"
	/// Add Video Inputs
	fileprivate func addVideoInput() {
		switch currentCamera {
		case .front:
			videoDevice = SwiftyCamViewController.deviceWithMediaType(AVMediaType.video.rawValue, preferringPosition: .front)
		case .rear:
			videoDevice = SwiftyCamViewController.deviceWithMediaType(AVMediaType.video.rawValue, preferringPosition: .back)
		}
        cachedPictureRatioSizeMap.removeAll()
        var pictureSizes: [CMVideoDimensions] = []
        if var formats = videoDevice?.formats {
            formats.sort{
                let dimA = $0.highResolutionStillImageDimensions
                let dimB = $1.highResolutionStillImageDimensions
                return dimA.width > dimB.width && dimA.height > dimB.height
            }
            for format  in formats {
                if(!pictureSizes.contains { (dim) -> Bool in
                    return dim.height == format.highResolutionStillImageDimensions.height && dim.width == format.highResolutionStillImageDimensions.width
                }){
                    let dim = format.highResolutionStillImageDimensions
                    pictureSizes.append(dim)
                    let ratio = Double(dim.width) / Double(dim.height)
                    var key: String? = nil
                    switch ratio {
                    case 1.0:
                       key = "1.0"
                    case 1.2...1.2222222:
                        key = "6:5"
                    case 1.3...1.3333334:
                        key = "4:3"
                    case 1.77...1.7777778:
                        key = "16:9"
                    case 1.5:
                        key = "3:2"
                    default: break
                    }
                    if key != nil {
                        var list = cachedPictureRatioSizeMap[key!]
                        if list == nil {
                            list = []
                        }
                        list?.append(dim)
                        cachedPictureRatioSizeMap[key!] = list
                    }
                }
            }
        }

		if let device = videoDevice {
			do {
				try device.lockForConfiguration()
				if device.isFocusModeSupported(.continuousAutoFocus) {
					device.focusMode = .continuousAutoFocus
					if device.isSmoothAutoFocusSupported {
						device.isSmoothAutoFocusEnabled = true
					}
				}

				if device.isExposureModeSupported(.continuousAutoExposure) {
					device.exposureMode = .continuousAutoExposure
				}

				if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
					device.whiteBalanceMode = .continuousAutoWhiteBalance
				}

				if device.isLowLightBoostSupported && lowLightBoost == true {
					device.automaticallyEnablesLowLightBoostWhenAvailable = true
				}

				device.unlockForConfiguration()
			} catch {
				print("[SwiftyCam]: Error locking configuration")
			}
		}

		do {
            if let videoDevice = videoDevice {
                let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
                if session.canAddInput(videoDeviceInput) {
                    session.addInput(videoDeviceInput)
                    self.videoDeviceInput = videoDeviceInput
                } else {
                    print("[SwiftyCam]: Could not add video device input to the session")
                    print(session.canSetSessionPreset(AVCaptureSession.Preset(rawValue: videoInputPresetFromVideoQuality(quality: videoQuality))))
                    setupResult = .configurationFailed
                    session.commitConfiguration()
                    return
                }
            }
			
		} catch {
			print("[SwiftyCam]: Could not create video device input: \(error)")
			setupResult = .configurationFailed
			return
		}
	}

	/// Add Audio Inputs

	fileprivate func addAudioInput() {
        guard audioEnabled == true else {
            return
        }
		do {
            if let audioDevice = AVCaptureDevice.default(for: AVMediaType.audio){
                let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
                if session.canAddInput(audioDeviceInput) {
                    session.addInput(audioDeviceInput)
                } else {
                    print("[SwiftyCam]: Could not add audio device input to the session")
                }
                
            } else {
                print("[SwiftyCam]: Could not find an audio device")
            }
            
		} catch {
			print("[SwiftyCam]: Could not create audio device input: \(error)")
		}
	}

	/// Configure Movie Output

	fileprivate func configureVideoOutput() {
		let movieFileOutput = AVCaptureMovieFileOutput()

		if self.session.canAddOutput(movieFileOutput) {
			self.session.addOutput(movieFileOutput)
			if let connection = movieFileOutput.connection(with: AVMediaType.video) {
				if connection.isVideoStabilizationSupported {
					connection.preferredVideoStabilizationMode = .auto
				}

				if #available(iOS 11.0, *) {
					if let videoCodecType = videoCodecType {
						if movieFileOutput.availableVideoCodecTypes.contains(videoCodecType) == true {
							movieFileOutput.setOutputSettings([AVVideoCodecKey: videoCodecType], for: connection)
						}
					}
				}

			}
			self.movieFileOutput = movieFileOutput
		}
	}

	/// Configure Photo Output

	fileprivate func configurePhotoOutput() {
        if #available(iOS 10.0, *){
            let output = AVCapturePhotoOutput()
            if self.session.canAddOutput(output){
                if(enableHighResolutionOutput){
                    output.isHighResolutionCaptureEnabled = true
                }
                self.session.addOutput(output)
                self.capturePhotoOutput = output
            }
            
        }else {
            let photoFileOutput = AVCaptureStillImageOutput()
            if(enableHighResolutionOutput){
                photoFileOutput.isHighResolutionStillImageOutputEnabled = true
            }
            if self.session.canAddOutput(photoFileOutput) {
                photoFileOutput.outputSettings  = [AVVideoCodecKey: AVVideoCodecJPEG]
                self.session.addOutput(photoFileOutput)
                self.photoFileOutput = photoFileOutput
            }
        }
	}
    
    public var cropByPreview = false
    
    
    private func calculateAspectRatioCrop(_ imageWidth: Int, _ imageHeight: Int) -> CGRect? {
        if(cropByPreview) {
            var previewSize: CGSize
            if (UIApplication.shared.statusBarOrientation.isPortrait) {
                previewSize = CGSize(width: self.previewLayer.frame.size.height, height: self.previewLayer.frame.size.width)
              } else {
                previewSize = CGSize(width: self.previewLayer.frame.size.width, height: self.previewLayer.frame.size.height)
              }
            return AVMakeRect(aspectRatio: previewSize, insideRect: CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
        }else {
            let values = pictureSize.split(separator: "x")
            let width = Int(values.first ?? "") ?? 0
            let height = Int(values.last ?? "") ?? 0
            if(width > 0 && height > 0){
                return AVMakeRect(aspectRatio: CGSize(width: width, height: height), insideRect: CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
            }
        }
        return nil
    }


	/// Orientation management

	// @objc public func subscribeToDeviceOrientationChangeNotifications() {
	// 	self.deviceOrientation = UIDevice.current.orientation
	// 	NotificationCenter.default.addObserver(self, selector: #selector(deviceDidRotate), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
	// }

	// @objc public func unsubscribeFromDeviceOrientationChangeNotifications() {
	// 	NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
	// 	self.deviceOrientation = nil
	// }

	// @objc public func deviceDidRotate() {
	// 	if !UIDevice.current.orientation.isFlat {
	// 		self.deviceOrientation = UIDevice.current.orientation
	// 	}
	// }
    
  //   @objc public func getPreviewLayerOrientation() -> AVCaptureVideoOrientation {
  //       // Depends on layout orientation, not device orientation
  //       switch UIApplication.shared.statusBarOrientation {
  //       case .portrait, .unknown:
  //           return AVCaptureVideoOrientation.portrait
  //       case .landscapeLeft:
  //           return AVCaptureVideoOrientation.landscapeLeft
  //       case .landscapeRight:
  //           return AVCaptureVideoOrientation.landscapeRight
  //       case .portraitUpsideDown:
  //           return AVCaptureVideoOrientation.portraitUpsideDown
  //       }
  //   }

	// @objc public func getVideoOrientation() -> AVCaptureVideoOrientation {
	// 	guard shouldUseDeviceOrientation, let deviceOrientation = self.deviceOrientation else { return previewLayer!.videoPreviewLayer.connection.videoOrientation }

	// 	switch deviceOrientation {
	// 	case .landscapeLeft:
	// 		// keep the same if using front camera
	// 		return self.currentCamera == .rear ? .landscapeRight : .landscapeLeft;
	// 	case .landscapeRight:
	// 		// keep the same if using front camera
	// 		return self.currentCamera == .rear ? .landscapeLeft : .landscapeRight;
	// 	case .portraitUpsideDown:
	// 		return .portraitUpsideDown
	// 	default:
	// 		return .portrait
	// 	}
	// }

	// @objc public func getImageOrientation(forCamera: CameraSelection) -> UIImageOrientation {
	// 	guard shouldUseDeviceOrientation, let deviceOrientation = self.deviceOrientation else { return forCamera == .rear ? .right : .leftMirrored }

	// 	switch deviceOrientation {
	// 	case .landscapeLeft:
	// 		return forCamera == .rear ? .up : .downMirrored
	// 	case .landscapeRight:
	// 		return forCamera == .rear ? .down : .upMirrored
	// 	case .portraitUpsideDown:
	// 		return forCamera == .rear ? .left : .rightMirrored
	// 	default:
	// 		return forCamera == .rear ? .right : .leftMirrored
	// 	}
	// }

	/**
	Returns a UIImage from Image Data.

	- Parameter imageData: Image Data returned from capturing photo from the capture session.

	- Returns: UIImage from the image data, adjusted for proper orientation.
	*/

	@objc public func processPhoto(_ imageData: Data) -> UIImage {
		let dataProvider = CGDataProvider(data: imageData as CFData)
		let cgImageRef = CGImage(jpegDataProviderSource: dataProvider!, decode: nil, shouldInterpolate: true, intent: CGColorRenderingIntent.defaultIntent)

		// Set proper orientation for photo
		// If camera is currently set to front camera, flip image
        
        
        var image: UIImage
        let rectToCrop = self.calculateAspectRatioCrop(cgImageRef!.width, cgImageRef!.height)
        if(rectToCrop != nil){
            image = UIImage(cgImage: cgImageRef!.cropping(to: rectToCrop!)!, scale: 1, orientation: self.orientation.getImageOrientation(forCamera: self.currentCamera))
        }else {
            image = UIImage(cgImage: cgImageRef!, scale: 1, orientation: self.orientation.getImageOrientation(forCamera: self.currentCamera))
        }

		return image
	}

	@objc public func capturePhotoAsyncronously(completionHandler: @escaping(Bool) -> ()) {
        guard sessionRunning == true else {
            print("[SwiftyCam]: Cannot take photo. Capture session is not running")
            return
        }
        
        if #available(iOS 10.0, *){
            self.capturePhotoOutputDelegate = AVCapturePhotoCaptureDelegateImpl(controller: self, completionHandler: completionHandler)
            capturePhoto()
        }else {
            legacyCapturePhoto(completionHandler: completionHandler)
        }

	}
    
    private func legacyCapturePhoto(completionHandler: @escaping(Bool) -> ()){
        if let videoConnection = photoFileOutput?.connection(with: AVMediaType.video) {

            photoFileOutput?.captureStillImageAsynchronously(from: videoConnection, completionHandler: {(sampleBuffer, error) in
                if (sampleBuffer != nil) {
                    let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer!)
                    let image = self.processPhoto(imageData!)

                    // Call delegate and return new image
                    DispatchQueue.main.async {
                        self.cameraDelegate?.swiftyCam(self, didTake: image)
                    }
                    completionHandler(true)
                } else {
                    completionHandler(false)
                }
            })
        } else {
            completionHandler(false)
        }
    }
    
    
    private var capturePhotoOutput: Any?
    
    private var capturePhotoOutputDelegate: Any?
    
    
    @available(iOS 10.0, *)
    class AVCapturePhotoCaptureDelegateImpl: NSObject, AVCapturePhotoCaptureDelegate {
        var controller: SwiftyCamViewController
        var completionHandler: (Bool) -> ()
        init(controller: SwiftyCamViewController, completionHandler: @escaping(Bool) -> ()) {
            self.controller = controller
            self.completionHandler = completionHandler
        }
        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
            if(photoSampleBuffer != nil){
                let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(photoSampleBuffer!)
                let image = controller.processPhoto(imageData!)

                // Call delegate and return new image
                DispatchQueue.main.async {
                    self.controller.cameraDelegate?.swiftyCam(self.controller, didTake: image)
                }
                completionHandler(true)
            }else {
                completionHandler(false)
            }
        }
        
        
        @available(iOS 11.0, *)
        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            let cgImage: CGImage?
            #if compiler(>=5.5)
            cgImage = photo.cgImageRepresentation()
            #else
            cgImage = photo.cgImageRepresentation()?.takeUnretainedValue()
            #endif
            if let cgImage = cgImage {
                var image: UIImage
                let rectToCrop = self.controller.calculateAspectRatioCrop(cgImage.width, cgImage.height)
                if(rectToCrop != nil){
                    image = UIImage(cgImage: cgImage.cropping(to: rectToCrop!)!, scale: 1, orientation: self.controller.orientation.getImageOrientation(forCamera: self.controller.currentCamera))
                }else {
                    image = UIImage(cgImage: cgImage, scale: 1, orientation: self.controller.orientation.getImageOrientation(forCamera: self.controller.currentCamera))
                }
                // Call delegate and return new image
                DispatchQueue.main.async {
                    self.controller.cameraDelegate?.swiftyCam(self.controller, didTake: image)
                }
            }else {
                completionHandler(false)
            }
        }
        
    }
    
    var enableHighResolutionOutput: Bool = false
    
    @available(iOS 10.0, *)
    private func capturePhoto(){
        let options = AVCapturePhotoSettings()
		if(flashEnabled){
            options.flashMode = .on
        }else {
            options.flashMode = .off
        }
        if(enableHighResolutionOutput){
            options.isHighResolutionPhotoEnabled = true
        }
        if let capturePhotoOutput =  self.capturePhotoOutput as? AVCapturePhotoOutput {
            if let delegate = self.capturePhotoOutputDelegate as? AVCapturePhotoCaptureDelegateImpl {
                capturePhotoOutput.capturePhoto(with: options, delegate: delegate)
            }
        }
    }

	/// Handle Denied App Privacy Settings

	@objc public func promptToAppSettings() {
		// prompt User with UIAlertView

		DispatchQueue.main.async(execute: { [unowned self] in
			let message = NSLocalizedString("AVCam doesn't have permission to use the camera, please change privacy settings", comment: "Alert message when the user has denied access to the camera")
			let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
			alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil))
			alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"), style: .default, handler: { action in
				if #available(iOS 10.0, *) {
                    UIApplication.shared.openURL(URL(string: UIApplication.openSettingsURLString)!)
				} else {
                    if let appSettings = URL(string: UIApplication.openSettingsURLString) {
						UIApplication.shared.openURL(appSettings)
					}
				}
			}))
			self.present(alertController, animated: true, completion: nil)
		})
	}

	/**
	Returns an AVCapturePreset from VideoQuality Enumeration

	- Parameter quality: ViewQuality enum

	- Returns: String representing a AVCapturePreset
	*/

	@objc public func videoInputPresetFromVideoQuality(quality: VideoQuality) -> String {
		switch quality {
		case .high: return AVCaptureSession.Preset.high.rawValue
		case .medium: return AVCaptureSession.Preset.medium.rawValue
		case .low: return AVCaptureSession.Preset.low.rawValue
		case .resolution352x288: return AVCaptureSession.Preset.cif352x288.rawValue
		case .resolution640x480: return AVCaptureSession.Preset.vga640x480.rawValue
		case .resolution1280x720: return AVCaptureSession.Preset.hd1280x720.rawValue
		case .resolution1920x1080: return AVCaptureSession.Preset.hd1920x1080.rawValue
		case .iframe960x540: return AVCaptureSession.Preset.iFrame960x540.rawValue
		case .iframe1280x720: return AVCaptureSession.Preset.iFrame1280x720.rawValue
        case .photo: return AVCaptureSession.Preset.photo.rawValue
		case .resolution3840x2160:
			if #available(iOS 9.0, *) {
				return AVCaptureSession.Preset.hd4K3840x2160.rawValue
			}
			else {
				print("[SwiftyCam]: Resolution 3840x2160 not supported")
				return AVCaptureSession.Preset.high.rawValue
			}
		}
	}

	/// Get Devices

	@objc public class func deviceWithMediaType(_ mediaType: String, preferringPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
		if #available(iOS 13.0, *) {
			let deviceTypes: [AVCaptureDevice.DeviceType] = [
				.builtInTripleCamera,
				.builtInDualWideCamera,
				.builtInDualCamera,
				.builtInWideAngleCamera,
				.builtInTelephotoCamera,
			]
			let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: AVMediaType(rawValue: mediaType), position: position)
			let selectedDevice = discoverySession.devices.first
			return selectedDevice
		} else {
			// Fallback on earlier versions
			let avDevice = AVCaptureDevice.devices(for: AVMediaType(rawValue: mediaType))
			for device in avDevice {
				if device.position == position {
					return device
				}
			}

			return avDevice[0]
		}
	}

	/// Enable or disable flash for photo

	@objc public func changeFlashSettings(device: AVCaptureDevice, mode: AVCaptureDevice.FlashMode) {
		do {
			try device.lockForConfiguration()
			device.flashMode = mode
			device.unlockForConfiguration()
		} catch {
			print("[SwiftyCam]: \(error)")
		}
	}

	/// Enable flash

	public func enableFlash() {
		if self.isCameraTorchOn == false {
			toggleFlash()
		}
	}

	/// Disable flash

	public func disableFlash() {
		if self.isCameraTorchOn == true {
			toggleFlash()
		}
	}

	/// Toggles between enabling and disabling flash

	public func toggleFlash() {
		guard self.currentCamera == .rear else {
			// Flash is not supported for front facing camera
			return
		}

		let device = AVCaptureDevice.default(for: AVMediaType.video)
		// Check if device has a flash
		if (device?.hasTorch)! {
			do {
				try device?.lockForConfiguration()
				if (device?.torchMode == AVCaptureDevice.TorchMode.on) {
					device?.torchMode = AVCaptureDevice.TorchMode.off
					self.isCameraTorchOn = false
				} else {
					do {
						try device?.setTorchModeOn(level: 1.0)
						self.isCameraTorchOn = true
					} catch {
						print("[SwiftyCam]: \(error)")
					}
				}
				device?.unlockForConfiguration()
			} catch {
				print("[SwiftyCam]: \(error)")
			}
		}
	}

	/// Sets whether SwiftyCam should enable background audio from other applications or sources

	@objc public func setBackgroundAudioPreference() {
		guard allowBackgroundAudio == true else {
			return
		}

        guard audioEnabled == true else {
            return
        }

		do{
            if #available(iOS 10.0, *) {
                try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playAndRecord, mode: AVAudioSession.Mode.default, options: [.mixWithOthers, .allowBluetooth, .allowAirPlay, .allowBluetoothA2DP])
            } else {
                let options: [AVAudioSession.CategoryOptions] = [.mixWithOthers, .allowBluetooth]
                let category = AVAudioSession.Category.playAndRecord
                let selector = NSSelectorFromString("setCategory:withOptions:error:")
                AVAudioSession.sharedInstance().perform(selector, with: category, with: options)
            }
            try AVAudioSession.sharedInstance().setActive(true)
			session.automaticallyConfiguresApplicationAudioSession = false
		}
		catch {
			print("[SwiftyCam]: Failed to set background audio preference")

		}
	}

    /// Called when Notification Center registers session starts running

    @objc private func captureSessionDidStartRunning() {
        sessionRunning = true
        DispatchQueue.main.async {
            self.cameraDelegate?.swiftyCamSessionDidStartRunning(self)
        }
    }

    /// Called when Notification Center registers session stops running

    @objc private func captureSessionDidStopRunning() {
        sessionRunning = false
        DispatchQueue.main.async {
            self.cameraDelegate?.swiftyCamSessionDidStopRunning(self)
        }
    }
}

extension SwiftyCamViewController : SwiftyCamButtonDelegate {

	/// Sets the maximum duration of the SwiftyCamButton

	public func setMaxiumVideoDuration() -> Double {
		return maximumVideoDuration
	}

	/// Set UITapGesture to take photo

	public func buttonWasTapped() {
		takePhoto()
	}

	/// Set UILongPressGesture start to begin video

	public func buttonDidBeginLongPress() {
		startVideoRecording()
	}

	/// Set UILongPressGesture begin to begin end video


	public func buttonDidEndLongPress() {
		stopVideoRecording()
	}

	/// Called if maximum duration is reached

	public func longPressDidReachMaximumDuration() {
		stopVideoRecording()
	}
}

// MARK: AVCaptureFileOutputRecordingDelegate

extension SwiftyCamViewController : AVCaptureFileOutputRecordingDelegate {

	/// Process newly captured video and write it to temporary directory

    public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let currentBackgroundRecordingID = backgroundRecordingID {
            backgroundRecordingID = UIBackgroundTaskIdentifier.invalid

            if currentBackgroundRecordingID != UIBackgroundTaskIdentifier.invalid {
                UIApplication.shared.endBackgroundTask(currentBackgroundRecordingID)
            }
        }

        if let currentError = error {
            print("[SwiftyCam]: Movie file finishing error: \(currentError)")
            DispatchQueue.main.async {
                self.cameraDelegate?.swiftyCam(self, didFailToRecordVideo: currentError)
            }
        } else {
            //Call delegate function with the URL of the outputfile
            DispatchQueue.main.async {
                self.cameraDelegate?.swiftyCam(self, didFinishProcessVideoAt: outputFileURL)
            }
        }
    }
}

// Mark: UIGestureRecognizer Declarations

extension SwiftyCamViewController {

	/// Handle pinch gesture

	@objc fileprivate func zoomGesture(pinch: UIPinchGestureRecognizer) {
		guard pinchToZoom == true && self.currentCamera == .rear else {
			//ignore pinch
			return
		}
		do {

			let captureDevice = SwiftyCamViewController.deviceWithMediaType(AVMediaType.video.rawValue, preferringPosition: .back)
			try captureDevice?.lockForConfiguration()

			zoomScale = min(maxZoomScale, max(1.0, min(beginZoomScale * pinch.scale,  captureDevice!.activeFormat.videoMaxZoomFactor)))

			captureDevice?.videoZoomFactor = zoomScale

			// Call Delegate function with current zoom scale
			DispatchQueue.main.async {
				self.cameraDelegate?.swiftyCam(self, didChangeZoomLevel: self.zoomScale)
			}

			captureDevice?.unlockForConfiguration()

		} catch {
			print("[SwiftyCam]: Error locking configuration")
		}
	}

	/// Handle single tap gesture

	@objc fileprivate func singleTapGesture(tap: UITapGestureRecognizer) {
		guard tapToFocus == true else {
			// Ignore taps
			return
		}

		let screenSize = previewLayer!.bounds.size
		let tapPoint = tap.location(in: previewLayer!)
		let x = tapPoint.y / screenSize.height
		let y = 1.0 - tapPoint.x / screenSize.width
		let focusPoint = CGPoint(x: x, y: y)
        
		if let device = videoDevice {
			do {
				try device.lockForConfiguration()

				if device.isFocusPointOfInterestSupported == true {
					device.focusPointOfInterest = focusPoint
					device.focusMode = .autoFocus
				}
				device.exposurePointOfInterest = focusPoint
				device.exposureMode = AVCaptureDevice.ExposureMode.continuousAutoExposure
				device.unlockForConfiguration()
				//Call delegate function and pass in the location of the touch

				DispatchQueue.main.async {
					self.cameraDelegate?.swiftyCam(self, didFocusAtPoint: tapPoint)
				}
			}
			catch {
				// just ignore
			}
		}
	}

	/// Handle double tap gesture

	@objc fileprivate func doubleTapGesture(tap: UITapGestureRecognizer) {
		guard doubleTapCameraSwitch == true else {
			return
		}
		switchCamera()
	}

    @objc private func panGesture(pan: UIPanGestureRecognizer) {

        guard swipeToZoom == true && self.currentCamera == .rear else {
            //ignore pan
            return
        }
        let currentTranslation    = pan.translation(in: view).y
        let translationDifference = currentTranslation - previousPanTranslation

        do {
			let captureDevice = SwiftyCamViewController.deviceWithMediaType(AVMediaType.video.rawValue, preferringPosition: .back)
            try captureDevice?.lockForConfiguration()

            let currentZoom = captureDevice?.videoZoomFactor ?? 0.0

            if swipeToZoomInverted == true {
                zoomScale = min(maxZoomScale, max(1.0, min(currentZoom - (translationDifference / 75),  captureDevice!.activeFormat.videoMaxZoomFactor)))
            } else {
                zoomScale = min(maxZoomScale, max(1.0, min(currentZoom + (translationDifference / 75),  captureDevice!.activeFormat.videoMaxZoomFactor)))

            }

            captureDevice?.videoZoomFactor = zoomScale

            // Call Delegate function with current zoom scale
            DispatchQueue.main.async {
                self.cameraDelegate?.swiftyCam(self, didChangeZoomLevel: self.zoomScale)
            }

            captureDevice?.unlockForConfiguration()

        } catch {
            print("[SwiftyCam]: Error locking configuration")
        }

        if pan.state == .ended || pan.state == .failed || pan.state == .cancelled {
            previousPanTranslation = 0.0
        } else {
            previousPanTranslation = currentTranslation
        }
    }

	/**
	Add pinch gesture recognizer and double tap gesture recognizer to currentView

	- Parameter view: View to add gesture recognzier

	*/

	fileprivate func addGestureRecognizers() {
		pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(zoomGesture(pinch:)))
		pinchGesture.delegate = self
		previewLayer.addGestureRecognizer(pinchGesture)

		let singleTapGesture = UITapGestureRecognizer(target: self, action: #selector(singleTapGesture(tap:)))
		singleTapGesture.numberOfTapsRequired = 1
		singleTapGesture.delegate = self
		previewLayer.addGestureRecognizer(singleTapGesture)

		let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(doubleTapGesture(tap:)))
		doubleTapGesture.numberOfTapsRequired = 2
		doubleTapGesture.delegate = self
		previewLayer.addGestureRecognizer(doubleTapGesture)

        panGesture = UIPanGestureRecognizer(target: self, action: #selector(panGesture(pan:)))
        panGesture.delegate = self
        previewLayer.addGestureRecognizer(panGesture)
	}
}


// MARK: UIGestureRecognizerDelegate

extension SwiftyCamViewController : UIGestureRecognizerDelegate {

	/// Set beginZoomScale when pinch begins

	public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
		if gestureRecognizer.isKind(of: UIPinchGestureRecognizer.self) {
			beginZoomScale = zoomScale;
		}
		return true
	}
}
