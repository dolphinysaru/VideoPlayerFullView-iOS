//
//  ViewController.swift
//  VideoPlayerSample
//
//  Created by ckmin on 2017. 3. 17..
//  Copyright © 2017년 ckmin. All rights reserved.
//

import UIKit
import VIMVideoPlayer

class ViewController: UIViewController, VIMVideoPlayerViewDelegate {
    
    var videoPlayerView: VIMVideoPlayerView!
    var videoURL = URL(string: "https://prefetch-video-sample.storage.googleapis.com/gbike.mp4")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let width = Int(self.view.frame.size.width)
        let height = Int(self.view.frame.size.width / 560 * 320) // sample video size width: 560, height: 320
        
        self.videoPlayerView = VIMVideoPlayerView()
        self.videoPlayerView.backgroundColor = UIColor.black
        self.videoPlayerView.frame = CGRect(x: 0, y: 50, width: width, height: height)
        self.videoPlayerView.player.isLooping = true
        self.videoPlayerView.player.isMuted = true
        self.videoPlayerView.player.disableAirplay()
        self.videoPlayerView.setVideoFillMode(AVLayerVideoGravityResizeAspectFill)
        self.videoPlayerView.delegate = self
        self.view.addSubview(self.videoPlayerView)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.didTap))
        self.videoPlayerView.addGestureRecognizer(tapGesture)
        
        if let videoURL = self.videoURL {
            self.videoPlayerView.player.setURL(videoURL)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func didTap() {
        
    }
    
    // MARK: VIMVideoPlayerViewDelegate
    func videoPlayerViewIsReady(toPlayVideo videoPlayerView: VIMVideoPlayerView!) {
        videoPlayerView.player.play()
    }
    
    func videoPlayerViewDidReachEnd(_ videoPlayerView: VIMVideoPlayerView!) {

    }
}

