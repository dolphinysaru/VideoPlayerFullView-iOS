//
//  VideoViewer.swift
//  VideoPlayerSample
//
//  Created by ckmin on 2017. 3. 17..
//  Copyright © 2017년 ckmin. All rights reserved.
//

import UIKit
import VIMVideoPlayer

let kMinBlackMaskAlpha: CGFloat = 0.3

class VideoViewer: UIViewController, VIMVideoPlayerViewDelegate, UIGestureRecognizerDelegate {
    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var videoControllerView: UIView!
    @IBOutlet weak var totalTimeLabel: UILabel!
    @IBOutlet weak var seekSlider: UISlider!
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var playTimeLabel: UILabel!
    @IBOutlet weak var controlBottomSpacing: NSLayoutConstraint!
    @IBOutlet weak var bottomControlView: UIView!
    
    private(set) weak var superDelegate: VIMVideoPlayerViewDelegate?
    private(set) weak var senderView: VIMVideoPlayerView!
    private(set) weak var superView: UIView!
    private(set) weak var rootViewController: UIViewController!
    
    private(set) var originalFrameRelativeToScreen: CGRect!
    private(set) var originalFrame: CGRect!
    private(set) var sliderValueChanging: Bool = false
    private(set) var willPlay: Bool = false
    private(set) var panOrigin: CGPoint = CGPoint(x: 0, y: 0)
    private(set) var panGesture: UIPanGestureRecognizer!
    private(set) var isAnimating: Bool = false
    
    init(videoPlayerView: VIMVideoPlayerView!, view: UIView!, delegate: VIMVideoPlayerViewDelegate?) {
        super.init(nibName: "VideoViewer", bundle: nil)
        
        self.superDelegate = delegate
        self.senderView = videoPlayerView
        self.superView = view
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, with: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            
        }

        // UI
        self.view.frame = UIScreen.main.bounds
        self.view.backgroundColor = UIColor.clear
        self.backgroundView.backgroundColor = UIColor.black
        self.backgroundView.alpha = 0.0
        
        let windowBounds = UIScreen.main.bounds
        self.originalFrame = senderView.frame
        var newFrame = senderView.convert(windowBounds, to: nil)
        newFrame.origin = CGPoint(x: newFrame.origin.x, y: newFrame.origin.y)
        newFrame.size = senderView.frame.size
        self.originalFrameRelativeToScreen = newFrame
        self.senderView.frame = self.originalFrameRelativeToScreen
        self.view.insertSubview(self.senderView, at: 1)
        
        totalTimeLabel.layer.shadowColor = UIColor.black.cgColor
        totalTimeLabel.layer.shadowOffset = CGSize(width: 0, height: 0)
        totalTimeLabel.layer.shadowRadius = 1.5
        totalTimeLabel.layer.shadowOpacity = 0.5
        
        playTimeLabel.layer.shadowColor = UIColor.black.cgColor
        playTimeLabel.layer.shadowOffset = CGSize(width: 0, height: 0)
        playTimeLabel.layer.shadowRadius = 1.5
        playTimeLabel.layer.shadowOpacity = 0.5
        
        seekSlider.layer.shadowColor = UIColor.black.cgColor
        seekSlider.layer.shadowOffset = CGSize(width: 0,height: 0)
        seekSlider.layer.shadowRadius = 1.5
        seekSlider.layer.shadowOpacity = 0.5
        
        playPauseButton.setImage(UIImage(named: "videoBtnPauseSmall"), for: .normal)
        
        // Action
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.toggleShowVideoControllerView))
        self.videoControllerView.addGestureRecognizer(tapGesture)
        self.videoControllerView.isUserInteractionEnabled = true
        
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(self.gestureRecognizerDidPan))
        panGesture.cancelsTouchesInView = false
        panGesture.delegate = self
        self.view.addGestureRecognizer(panGesture)
        
        seekSlider.addTarget(self, action: #selector(self.sliderTouchDownAction(sender:)), for: .touchDown)
        seekSlider.addTarget(self, action: #selector(self.sliderTouchUpAction(sender:)), for: .touchUpInside)
        seekSlider.addTarget(self, action: #selector(self.sliderTouchUpAction(sender:)), for: .touchUpOutside)

        NotificationCenter.default.addObserver(self, selector: #selector(self.didRotate(notification:)), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
        
        // Duration
        if let duration = self.senderView.player.player.currentItem?.duration {
            let durationInSeconds = Int(Float(CMTimeGetSeconds(duration)))
            
            let seconds: Int = durationInSeconds % 60
            let minutes: Int = (durationInSeconds / 60) % 60
            totalTimeLabel.text = String(format: "%02d:%02d", minutes, seconds)
        }
        
        self.senderView.delegate = self
        self.toggleVideoControllerView(hidden: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIApplication.shared.setStatusBarHidden(true, with: .fade)
        UIView.animate(withDuration: 0.4, animations: {
            self.backgroundView.alpha = 1.0
            self.adjustViewFrame()
            }) { (completion) in
                
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //MARK: Private Method
    func didRotate(notification: NSNotification) {
        self.adjustViewFrame()
    }
    
    func adjustViewFrame() {
        guard let size = self.senderView.player.player.currentItem?.presentationSize else {
            return
        }
        let videoRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        self.senderView.frame = self.aspectFittedVideoRect(inRect: videoRect, max: UIScreen.main.bounds)
        self.controlBottomSpacing.constant = UIScreen.main.bounds.height - self.senderView.frame.origin.y - self.senderView.frame.size.height
    }
    
    func aspectFittedVideoRect(inRect: CGRect, max maxRect: CGRect) -> CGRect {
        let originalAspectRatio: CGFloat = inRect.size.width / inRect.size.height
        let maxAspectRatio: CGFloat = maxRect.size.width / maxRect.size.height
        var newRect = maxRect
        if originalAspectRatio > maxAspectRatio {
            newRect.size.height = maxRect.size.width * inRect.size.height / inRect.size.width
            newRect.origin.y += (maxRect.size.height - newRect.size.height) / 2.0
        }
        else {
            newRect.size.width = maxRect.size.height * inRect.size.width / inRect.size.height
            newRect.origin.x += (maxRect.size.width - newRect.size.width) / 2.0
        }
        return newRect.integral
    }
    
    func animateHiddenControlView() {
        UIView.animate(withDuration: 0.3) {
            self.toggleVideoControllerView(hidden: true)
        }
    }
    
    func toggleShowVideoControllerView() {
        UIView.animate(withDuration: 0.3) {
            self.toggleVideoControllerView(hidden: self.closeButton.alpha != 0)
        }
    }
    
    func toggleVideoControllerView(hidden: Bool) {
        self.closeButton.alpha = hidden ? 0.0 : 1.0
        self.bottomControlView.alpha = hidden ? 0.0 : 1.0
        
        if !hidden {
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.animateHiddenControlView), object: nil)
            self.perform(#selector(self.animateHiddenControlView), with: nil, afterDelay: 3.0)
        }
    }
    
    func presentFromRootViewController() {
        if let rootViewController = UIApplication.shared.keyWindow?.rootViewController {
            self.presentFromViewController(viewController: rootViewController)
        }
    }
    
    func presentFromViewController(viewController: UIViewController) {
        self.rootViewController = viewController
        UIApplication.shared.keyWindow?.addSubview(self.view)
        viewController.addChildViewController(self)
        self.didMove(toParentViewController: viewController)
    }
    
    func rollbackViewController() {
        self.isAnimating = true
        
        UIView.animate(withDuration: 0.4,
                                   animations: {
                                    self.adjustViewFrame()
                                    self.backgroundView.alpha = 1
        }) { (finished: Bool) in
            if finished {
                self.isAnimating = false
            }
        }
    }
    
    func dismissViewController() {
        self.senderView.player.isMuted = true
        UIApplication.shared.setStatusBarHidden(false, with: .fade)
        if UIDeviceOrientationIsLandscape(UIDevice.current.orientation) {
            let value = UIInterfaceOrientation.portrait.rawValue
            UIDevice.current.setValue(value, forKey: "orientation")
        }
        
        self.senderView.delegate = superDelegate
        
        UIView.animate(withDuration: 0.3, animations: {
            self.senderView.setVideoFillMode(AVLayerVideoGravityResizeAspectFill)
            self.senderView.frame = self.originalFrameRelativeToScreen
            self.backgroundView.alpha = 0.0
            self.toggleVideoControllerView(hidden: true)
        }) { (finished: Bool) in
            if finished {
                self.senderView.frame = self.originalFrame
                self.senderView.removeFromSuperview()
                self.superView.insertSubview(self.senderView, at: 1)
                self.view.removeFromSuperview()
                self.removeFromParentViewController()
                
                DispatchQueue.main.async {
                    do {
                        try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, with: .mixWithOthers)
                    } catch {
                        
                    }
                }
            }
        }
    }
    
    //MARK: Button actions
    @IBAction func closeButtonAction(sender: AnyObject) {
        self.dismissViewController()
    }
    
    @IBAction func playPauseButtonAction(sender: UIButton) {
        if self.senderView.player.isPlaying {
            self.senderView.player.pause()
            sender.setImage(UIImage(named: "videoBtnPlaySmall"), for: .normal)
        } else {
            self.senderView.player.play()
            sender.setImage(UIImage(named: "videoBtnPauseSmall"), for: .normal)
        }
    }
    
    //MARK: Slider actions
    @IBAction func sliderValueChangedAction(sender: AnyObject) {
        guard let duration = self.senderView.player.player.currentItem?.duration else {
            return
        }
        
        let slider = sender as! UISlider
        let seekTime = Float(CMTimeGetSeconds(duration)) * slider.value
        self.senderView.player.seek(toTime: seekTime)
    }
    
    func sliderTouchDownAction(sender: AnyObject) {
        sliderValueChanging = true
        if self.senderView.player.isPlaying {
            self.senderView.player.pause()
            self.willPlay = true
        }
    }
    
    func sliderTouchUpAction(sender: AnyObject) {
        sliderValueChanging = false
        
        if self.willPlay {
            self.willPlay = false
            self.senderView.player.play()
        }
    }
    
    //MARK: Gesture recognizer
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let panGestureRecognizer = gestureRecognizer as! UIPanGestureRecognizer
        let translation = panGestureRecognizer.translation(in: self.view)
        return fabs(translation.y) > fabs(translation.x)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        self.panOrigin = senderView.frame.origin
        gestureRecognizer.isEnabled = true
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == panGesture {
            return true
        }
        return false
    }
    
    func gestureRecognizerDidPan(panGesture: UIPanGestureRecognizer) {
        self.toggleVideoControllerView(hidden: true)
        let windowSize = backgroundView.bounds.size
        let currentPoint = panGesture.translation(in: self.view)
        let y: CGFloat = currentPoint.y + panOrigin.y
        var frame = senderView.frame
        frame.origin.y = y
        self.senderView.frame = frame
        let yDiff: CGFloat = abs((y + senderView.frame.size.height / 2) - windowSize.height / 2)
        self.backgroundView.alpha = max(1 - yDiff / (windowSize.height / 0.5), kMinBlackMaskAlpha)
        if (panGesture.state == .ended || panGesture.state == .cancelled) {
            if backgroundView.alpha < 0.95 {
                self.dismissViewController()
            }
            else {
                self.rollbackViewController()
            }
        }
    }
    
    //MARK: VIMVideoPlayerViewDelegate
    func videoPlayerView(_ videoPlayerView: VIMVideoPlayerView!, timeDidChange cmTime: CMTime) {
        guard let duration = self.senderView.player.player.currentItem?.duration else {
            return
        }
        
        let durationInSeconds = Float(CMTimeGetSeconds(duration))
        let timeInSeconds = Float(CMTimeGetSeconds(cmTime))
        
        if !sliderValueChanging {
            self.seekSlider.value = timeInSeconds / durationInSeconds
        }
        
        
        let seconds: Int = Int(timeInSeconds) % 60
        let minutes: Int = (Int(timeInSeconds) / 60) % 60
        playTimeLabel.text = String(format: "%02d:%02d", minutes, seconds)
    }
    
    func videoPlayerViewDidReachEnd(_ videoPlayerView: VIMVideoPlayerView!) {
        dismissViewController()
    }
}
