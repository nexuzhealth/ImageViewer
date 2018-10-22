//
//  ImageViewController.swift
//  ImageViewer
//
//  Created by Kristian Angyal on 01/08/2016.
//  Copyright © 2016 MailOnline. All rights reserved.
//

import UIKit
import AVFoundation


extension VideoView: ItemView {}

class VideoViewController: ItemBaseController<VideoView> {

    fileprivate let swipeToDismissFadeOutAccelerationFactor: CGFloat = 6

    var fetchVideoBlock: FetchVideoBlock
    var image: UIImage?
    
    var videoURL: URL? {
        didSet {
            guard let videoURL = videoURL else { return }
            
            player = AVPlayer(url: videoURL)
            finishedFetching()
        }
    }
    var player: AVPlayer? {
        didSet {
            scrubber.player = player
            
            guard let player = player else { return }

            observingPlayer = true
        }
    }
    
    var isPlaying: Bool {
        return player?.isPlaying() ?? false
    }
    
    unowned let scrubber: VideoScrubber

    let fullHDScreenSizeLandscape = CGSize(width: 1920, height: 1080)
    let fullHDScreenSizePortrait = CGSize(width: 1080, height: 1920)
    let embeddedPlayButton = UIButton.circlePlayButton(70)
    
    private var autoPlayStarted: Bool = false
    private var autoPlayEnabled: Bool = false

    init(index: Int, itemCount: Int, fetchImageBlock: @escaping FetchImageBlock, fetchVideoBlock: @escaping FetchVideoBlock, scrubber: VideoScrubber, configuration: GalleryConfiguration, isInitialController: Bool = false) {

        self.scrubber = scrubber
        
        ///Only those options relevant to the paging VideoViewController are explicitly handled here, the rest is handled by ItemViewControllers
        for item in configuration {
            
            switch item {
                
            case .videoAutoPlay(let enabled):
                autoPlayEnabled = enabled
                
            default: break
            }
        }
        
        self.fetchVideoBlock = fetchVideoBlock
        super.init(index: index, itemCount: itemCount, fetchImageBlock: fetchImageBlock, configuration: configuration, isInitialController: isInitialController)
        
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        embeddedPlayButton.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleBottomMargin, .flexibleRightMargin]
        self.view.addSubview(embeddedPlayButton)
        embeddedPlayButton.center = self.view.boundsCenter
        embeddedPlayButton.addTarget(self, action: #selector(playVideoInitially), for: UIControlEvents.touchUpInside)
        
        itemView.isHidden = true
        embeddedPlayButton.isHidden = true
        scrubber.isHidden = true
        
        fetchVideoBlock { [weak self] (url) in
            DispatchQueue.main.async {
                self?.videoURL = url
                
                self?.finishedFetching()
            }
        }
    }
    
    func finishedFetching() {
        guard let _ = self.player else { return }
        
        scrubber.isHidden = false
        embeddedPlayButton.isHidden = false
        itemView.isHidden = false
        
        itemView.image = image
        itemView.player = player
        itemView.contentMode = .scaleAspectFill
        
        view.setNeedsLayout()
        view.layoutIfNeeded()
        
        self.activityIndicatorView.stopAnimating()
        performAutoPlay()
    }
    
    public override func fetchImage() {
        fetchImageBlock { [weak self] image in
            DispatchQueue.main.async {
                self?.image = image
            }
        }
    }
    
    private var _observingPlayer = false
    var observingPlayer: Bool {
        get {
            return _observingPlayer
        }
        set(shouldObserve) {
            guard let player = player, shouldObserve != observingPlayer else {
                return
            }
            
            let statusKey = "status"
            let rateKey = "rate"
            
            _observingPlayer = shouldObserve
            if shouldObserve {
                player.addObserver(self, forKeyPath: statusKey, options: NSKeyValueObservingOptions.new, context: nil)
                player.addObserver(self, forKeyPath: rateKey, options: NSKeyValueObservingOptions.new, context: nil)
                
                UIApplication.shared.beginReceivingRemoteControlEvents()
            } else {
                player.removeObserver(self, forKeyPath: statusKey)
                player.removeObserver(self, forKeyPath: rateKey)
                
                UIApplication.shared.endReceivingRemoteControlEvents()
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        observingPlayer = true
        super.viewWillAppear(animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        observingPlayer = false
        super.viewWillDisappear(animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        self.player?.pause()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let isLandscape = itemView.bounds.width >= itemView.bounds.height
        itemView.bounds.size = aspectFitSize(forContentOfSize: isLandscape ? fullHDScreenSizeLandscape : fullHDScreenSizePortrait, inBounds: self.scrollView.bounds.size)
        itemView.center = scrollView.boundsCenter
    }

    @objc func playVideoInitially() {

        self.player?.play()


        UIView.animate(withDuration: 0.25, animations: { [weak self] in

            self?.embeddedPlayButton.alpha = 0

        }, completion: { [weak self] _ in

            self?.embeddedPlayButton.isHidden = true
        })
    }

    override func closeDecorationViews(_ duration: TimeInterval) {

        UIView.animate(withDuration: duration, animations: { [weak self] in

            self?.embeddedPlayButton.alpha = 0
            self?.itemView.previewImageView.alpha = 1
        })
    }

    override func presentItem(alongsideAnimation: () -> Void, completion: @escaping () -> Void) {

        let circleButtonAnimation = {

            UIView.animate(withDuration: 0.15, animations: { [weak self] in
                self?.embeddedPlayButton.alpha = 1
            })
        }

        super.presentItem(alongsideAnimation: alongsideAnimation) {

            circleButtonAnimation()
            completion()
        }
    }

    override func displacementTargetSize(forSize size: CGSize) -> CGSize {

        let isLandscape = itemView.bounds.width >= itemView.bounds.height
        return aspectFitSize(forContentOfSize: isLandscape ? fullHDScreenSizeLandscape : fullHDScreenSizePortrait, inBounds: rotationAdjustedBounds().size)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {

        if keyPath == "rate" || keyPath == "status" {

            fadeOutEmbeddedPlayButton()
        }

        else if keyPath == "contentOffset" {

            handleSwipeToDismissTransition()
        }

        super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
    }

    func handleSwipeToDismissTransition() {

        guard let _ = swipingToDismiss else { return }

        embeddedPlayButton.center.y = view.center.y - scrollView.contentOffset.y
    }

    func fadeOutEmbeddedPlayButton() {
        if isPlaying && embeddedPlayButton.alpha != 0  {

            UIView.animate(withDuration: 0.3, animations: { [weak self] in

                self?.embeddedPlayButton.alpha = 0
            })
        }
    }

    override func remoteControlReceived(with event: UIEvent?) {

        if let event = event {

            if event.type == UIEventType.remoteControl {

                switch event.subtype {

                case .remoteControlTogglePlayPause:

                    if isPlaying {
                        self.player?.pause()
                    } else {
                        self.player?.play()
                    }

                case .remoteControlPause:

                    self.player?.pause()

                case .remoteControlPlay:

                    self.player?.play()

                case .remoteControlPreviousTrack:

                    self.player?.pause()
                    self.player?.seek(to: CMTime(value: 0, timescale: 1))
                    self.player?.play()

                default:

                    break
                }
            }
        }
    }
    
    private func performAutoPlay() {
        guard autoPlayEnabled else { return }
        guard autoPlayStarted == false else { return }
        
        autoPlayStarted = true
        embeddedPlayButton.isHidden = true
        scrubber.play()
    }
}
