//
//  BoomAudioPlayer.swift
//  BoomAudioPlayer
//
//  Created by jianghongbao on 2021/4/13.
//

import UIKit
import AVFoundation
import Foundation

class BoomAudioPlayerManager: NSObject,AVAudioPlayerDelegate {
    
    typealias BoomProgressHandler = ((_ progress: Double)->())
    typealias BoomPlayerStatusHandler = ((_ playerStatus: BoomAudioPlayerStatusType)->())
    typealias BoomAudioTimeHandler = ((_ minute: Int,_ seconds:Int)->())
    typealias BoomFileManagerStatusHandler = ((_ fileManagerStatus: BoomFileManagerStatusType)->())
    
    //MARK:(jianghongbao)Parameters
    
    /// 文件管理者
    private let fileManager = FileManager.default
    /// 文件索引字典
    private var fileIndexDictionary = NSMutableDictionary()
    private let defaultDirectory = "BoomTempAudioPath"
    /// 音频组文件夹名
    private var audioArrayDirectory: String {
        get {
            if let _directory = self.setAudioArrayDirectory,
               !_directory.isEmpty {
                return _directory
            } else {
                return defaultDirectory
            }
        }
    }
    public var setAudioArrayDirectory: String?
    
    /// 音频文件名
    private var audioName = String()
    /// 当前文管理者状态类型
    private var fileManagerStatus: BoomFileManagerStatusType = BoomFileManagerStatusType.BoomFileManagerStatusTypeReady
    /// 文件管理者状态回调
    private var fileManagerStatusHandler: BoomFileManagerStatusHandler?
    /// 沙盒存储模式(默认tmp)
    private var cacheCategory: BoomCacheCategoryType = BoomCacheCategoryType.BoomCacheCategoryTypeTemporary
    /// 播放器
    private var localPlayer: AVAudioPlayer? = nil
    /// 下载任务
    private var task: URLSessionDataTask?
    /// 已收到数据长度
    private var _receivedLength: Float = 0
    /// 期望收到数据长度
    private var _expectedLength: Float = 0
    /// 音频数据
    private var audioData = Data()
    /// 当前播放模式
    private var playType = BoomAudioPlayType.BoomAudioPlayTypeLocal
    /// 播放器
    private var player: AVPlayer? = nil
    /// 定时器
    private var timer: Timer? = nil
    /// 传入时长
    private var time: Int = 0
    /// 当前分
    private var minute: Int = 0
    /// 当前秒
    private var seconds: Int = 0
    /// 总时长
    private var totalDuration: Double = 0
    /// 音频路径
    private var audioUrlString = String()
    /// 是否循环
    private var kIfLooped: Bool = false
    /// 进度值回调
    private var progressHandler: BoomProgressHandler?
    /// 播放器状态回调
    private var playerStatusHandler: BoomPlayerStatusHandler?
    /// 时长回调
    private var audioTimeHandler: BoomAudioTimeHandler?
    /// 当前播放器状态类型
    private var playerStatus: BoomAudioPlayerStatusType = BoomAudioPlayerStatusType.BoomAudioPlayerStatusTypeReady
    /// 当前对外提供可得的播放器状态
    public var currentPlayerStatus: BoomAudioPlayerStatusType{
        get{
            return self.playerStatus
        }
    }
    /// 判断是否添加过监听者
    private var kIfHaveAddObserver: Bool = false
    
    //MARK: - 单例
    
    public static let sharedPlayerManager = BoomAudioPlayerManager()
    
    /// playWithNetwork
    private func playWithNetwork(audioUrlString:String,
                                 time:Int,
                                 kIfLooped:Bool,
                                 progressHandler: BoomProgressHandler?,
                                 playerStatusHandler: BoomPlayerStatusHandler?,
                                 audioTimeHandler: BoomAudioTimeHandler?) {
        
        ///@本地查找无果,开启下载器,并继续开启在线播放
        let path = boomCreateDirectory(name: audioArrayDirectory).appending("/"+"\(audioName)"+".mp3")
        
        if !fileManager.fileExists(atPath: path, isDirectory: nil) {
            self.setDownLoader()
        }
        
        self.playType = BoomAudioPlayType.BoomAudioPlayTypeNetwork
        boomPlayerLoadingStatus()
        
        setConfigsWith(audioUrlString: audioUrlString,
                       time:time,
                       kIfLooped: kIfLooped,
                       progressHandler: progressHandler,
                       playerStatusHandler: playerStatusHandler,
                       audioTimeHandler: audioTimeHandler)
    }
    
    /// playWithLocal
    private func playWithLocal(audioUrlString:String,
                               time:Int,
                               kIfLooped:Bool,
                               progressHandler: BoomProgressHandler?,
                               playerStatusHandler: BoomPlayerStatusHandler?,
                               audioTimeHandler: BoomAudioTimeHandler?) {
        
        // 尝试播放本地音频
        guard let _fileIndexDictionary = NSMutableDictionary.init(contentsOfFile: boomCreateIndexPlist(name: audioArrayDirectory)) else { return }
        self.fileIndexDictionary = _fileIndexDictionary
        
        let value = fileIndexDictionary.value(forKey: audioUrlString) as? String
        boomFileManagerReadingStatus()
        
        print("value: --> "+"\(String(describing: value))")
        if (value == nil) {
            // 在索引plist文件中为当前音频路径设置索引文件名
            setNewIndexNameForCurrentAudioUrlInDirectory(audioUrlString: audioUrlString)
            
            playWithNetwork(audioUrlString: audioUrlString,
                            time:time,
                            kIfLooped: kIfLooped,
                            progressHandler: progressHandler,
                            playerStatusHandler: playerStatusHandler,
                            audioTimeHandler: audioTimeHandler)
        }else{
            // 播放本地音频
            do {
                guard let _value = value else { return }
                let path = boomCreateDirectory(name: audioArrayDirectory).appending("/" + "\(_value)")
                
                if fileManager.fileExists(atPath: path, isDirectory: nil) {
                    boomFileManagerReadSuccessfulStatus()
                    try localPlayer = AVAudioPlayer.init(contentsOf: URL.init(fileURLWithPath: path))
                    let audioAsset = AVURLAsset.init(url: URL.init(fileURLWithPath: path), options: nil)
                    // 检测文件的真实时长,并以此获取准确的分秒信息
                    getRealTimeAboutMinuteAndSecondsWith(duration: audioAsset.duration.seconds,time:time)
                    self.progressHandler?(Double(truncating: true))
                    innerPlay()
                }else{
                    // 在索引plist文件中为当前音频路径设置索引文件名
                    setNewIndexNameForCurrentAudioUrlInDirectory(audioUrlString: audioUrlString)
                    playWithNetwork(audioUrlString: audioUrlString,
                                    time:time,
                                    kIfLooped: kIfLooped,
                                    progressHandler: progressHandler,
                                    playerStatusHandler: playerStatusHandler,
                                    audioTimeHandler: audioTimeHandler)
                }
            } catch  {
                boomPlayerUnknowStatus()
            }
            return
        }
    }
    
    /// setConfigs
    private func setConfigsWith(audioUrlString:String,
                                time:Int,
                                kIfLooped:Bool,
                                progressHandler: BoomProgressHandler?,
                                playerStatusHandler: BoomPlayerStatusHandler?,
                                audioTimeHandler: BoomAudioTimeHandler?) {
        if audioUrlString.isEmpty {
            assert(false, "Audio-UrlString can not be nil !")
            return
        }
        if let url = NSURL.init(string: audioUrlString) {
            let item = AVPlayerItem.init(url: url as URL)
            self.player = AVPlayer.init(playerItem: item)
            self.addObserver()
        }
    }
    
    /// play
    private func innerPlay() {
        switch self.playType {
        case .BoomAudioPlayTypeLocal:
            localPlayer?.delegate = self
            boomPlayerReadyStatus()
            localPlayer?.play()
            boomPlayerPlayingStatus()
            startTimer()
            break
        case .BoomAudioPlayTypeNetwork:
            boomPlayerReadyStatus()
            player?.play()
            startTimer()
            boomPlayerPlayingStatus()
            break
        }
    }
    
    /// timerUpdate
    @objc private func timerUpdate() {
        if self.time >= 0 {
            seconds -= 1
            
            if seconds < 0 {
                if minute <= 0 {// 无分
                    // 停止播放
                    clearTimer()
                }else{// 有分
                    seconds = 59
                    minute -= 1
                }
            }
            
            if !(minute < 0 || seconds < 0) {
                self.audioTimeHandler?(minute, seconds)
            }
        }
    }
    
    /// TimerStart
    private func startTimer() {
        // 启动定时器
        self.timer = Timer.init(timeInterval: 1.0,
                                target: self,
                                selector: #selector(timerUpdate),
                                userInfo: nil,
                                repeats: true)
        if let _timer = self.timer {
            RunLoop.current.add(_timer, forMode: RunLoop.Mode.default)
            _timer.fire()
        }
    }
    
    /// TimerPause
    private func pauseTimer() {
        // 暂停定时器
        self.timer?.fireDate = NSDate.distantPast
        self.timer?.invalidate()
    }
    
    /// invalidateTimer
    private func clearTimer() {
        self.timer?.invalidate()
        self.timer = nil
    }
    
    /// getRealTimeWithMinuteAndSeconds
    private func getRealTimeAboutMinuteAndSecondsWith(duration: Double, time: Int) {
        seconds = self.time % 60
        minute = self.time / 60
        totalDuration = duration
        minute = (Int(totalDuration / 60) == minute ? minute: Int(totalDuration / 60))
        seconds = (Int(totalDuration.truncatingRemainder(dividingBy: 60)) == seconds ? seconds: Int(totalDuration.truncatingRemainder(dividingBy: 60)))
    }
    
    /// setNewIndexNameForCurrentAudioUrlInDirectory
    private func setNewIndexNameForCurrentAudioUrlInDirectory(audioUrlString: String) {
        boomFileManagerReadFialedStatus()
        audioName = Date().timeIntervalSince1970.description
        fileIndexDictionary.setValue("\(audioName)" + ".mp3", forKey: audioUrlString)
        fileIndexDictionary.write(toFile: boomCreateIndexPlist(name: audioArrayDirectory), atomically: true)
    }
    
    /// 实现监听
    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?,
                               context: UnsafeMutableRawPointer?) {
        
        if keyPath == "status" {
            if let number = change?[NSKeyValueChangeKey.newKey] as? NSNumber {
                guard let status = AVPlayer.Status(rawValue: Int(truncating: number)) else { return }
                switch (status) {
                case .unknown:
                    removeObserve()
                    boomPlayerUnknowStatus()
                    break
                case .readyToPlay:
                    innerPlay()
                    break
                case .failed:
                    removeObserve()
                    boomPlayerFailedStatus()
                    break
                @unknown default:
                    fatalError()
                }
            }
        } else if keyPath == "loadedTimeRanges" {
            guard let item = object as? AVPlayerItem else { return }
            let array = item.loadedTimeRanges
            let timeRange = array.first?.timeRangeValue
            guard let startSeconds = timeRange?.start.seconds else { return }
            guard let durationSeconds = timeRange?.duration.seconds else { return }
            self.getRealTimeAboutMinuteAndSecondsWith(duration: durationSeconds, time: time)
            //缓冲总长度
            let totalBuffer = Double(startSeconds + durationSeconds)
            self.progressHandler?(totalBuffer / totalDuration)
        } else if keyPath == "rate" {
            guard let playerOfRate = object as? AVPlayer else { return }
            print("💗playerOfRate:"+"\(playerOfRate.rate)")
        }
    }
    
    /// 添加观察者
    private func addObserver() {
        if kIfHaveAddObserver == false {
            player?.currentItem?.addObserver(self, forKeyPath: "status", options: .new, context: nil)
            player?.currentItem?.addObserver(self, forKeyPath: "loadedTimeRanges", options: .new, context: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(playDidFinished), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: player?.currentItem)
            self.player?.addObserver(self, forKeyPath: "rate", options: .new, context: nil)
            kIfHaveAddObserver = true
        }
    }
    
    /// 移除观察者
    private func removeObserve() {
        if kIfHaveAddObserver == true {
            if ((player?.currentItem) != nil) {
                player?.currentItem?.removeObserver(self, forKeyPath: "status")
                player?.currentItem?.removeObserver(self, forKeyPath: "loadedTimeRanges")
                player?.removeObserver(self, forKeyPath: "rate")
            }
            
            NotificationCenter.default.removeObserver(self)
            kIfHaveAddObserver = false
        }
    }
    
    /// AudioPlayer播放完毕
    @objc private func playDidFinished() {
        boomPlayerFinishStatus()
        clearTimer()
        goForLoop()
    }
    
    /// AVPlayer播放完毕(AVAudioPlayerDelegate)
    internal func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playDidFinished()
    }
    
    /// 开启循环?
    private func goForLoop() {
        self.playType = BoomAudioPlayType.BoomAudioPlayTypeLocal
        
        if self.kIfLooped {
            playWithInner(audioUrlString: self.audioUrlString,
                          time:self.time,
                          kIfLooped: self.kIfLooped,
                          progressHandler: self.progressHandler,
                          playerStatusHandler: self.playerStatusHandler,
                          audioTimeHandler: self.audioTimeHandler,
                          fileManagerStatusHandler: self.fileManagerStatusHandler)
        }
    }
    
    /// deinit
    deinit {
        removeObserve()
    }
    
}

//MARK: - URLSessionTaskDelegate

extension BoomAudioPlayerManager: URLSessionDataDelegate {
    
    /// 设置下载器
    private func setDownLoader() {
        DispatchQueue.global().async {
            print("💗setDownLoader --> 开始检测下载")
            self.boomFileManagerReadyStatus()
            if let url = NSURL.init(string: self.audioUrlString) {
                let request = URLRequest.init(url: url as URL)
                let session = URLSession.init(configuration: URLSessionConfiguration.default,
                                              delegate: self,
                                              delegateQueue: OperationQueue.main)
                self.task = session.dataTask(with: request)
                if let _task = self.task {
                    _task.resume()
                }
            }
        }
    }
    
    /// 1.接收到服务器响应的时候使用该方法
    internal func urlSession(_ session: URLSession,
                             dataTask: URLSessionDataTask,
                             didReceive response: URLResponse,
                             completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        _expectedLength = Float(response.expectedContentLength);
        completionHandler(URLSession.ResponseDisposition.allow);
    }
    
    /// 2.接收到服务器返回数据的时候会调用该方法，如果数据较大那么该方法可能会调用多次
    internal func urlSession(_ session: URLSession,
                             dataTask: URLSessionDataTask,
                             didReceive data: Data) {
        _receivedLength += Float(data.count);
        let currentDownloadRatio = Float(_receivedLength / _expectedLength)
        self.progressHandler?(Double(currentDownloadRatio))
        audioData.append(data)
    }
    
    /// 3.当请求完成(成功|失败)的时候会调用该方法，如果请求失败，则error有值
    internal func urlSession(_ session: URLSession,
                             task: URLSessionTask,
                             didCompleteWithError error: Error?) {
        if (error == nil) {
            //请求成功
            boomFileManagerDownloadSuccessfulStatus()
            _receivedLength = 0
            boomCreateTempAudioFile(name: audioName, data: audioData)
        }else{
            //请求失败
            boomFileManagerDownloadFialedStatus()
        }
    }
    
}

//MARK: - FileManager

extension BoomAudioPlayerManager {
    
    /// 在沙盒tmp文件夹下创建文件夹 + 返回该文件夹路径
    public func boomCreateDirectory(name: String) -> String {
        
        var path = String()
        switch cacheCategory {
        case .BoomCacheCategoryTypeHome:
            path = NSHomeDirectory()
            break
        case .BoomCacheCategoryTypeDocuments:
            path = NSHomeDirectory().appending("/Documents")
            break
        case .BoomCacheCategoryTypeLibrary:
            path = NSHomeDirectory().appending("/Library")
            break
        case .BoomCacheCategoryTypeLibraryCaches:
            path = NSHomeDirectory().appending("/Library/Caches")
            break
        case .BoomCacheCategoryTypeLibraryPreference:
            path = NSHomeDirectory().appending("/Documents/Preferences")
            break
        case .BoomCacheCategoryTypeTemporary:
            path = NSTemporaryDirectory()
            break
        }
        
        let filepath = path.appending(name.isEmpty ? audioArrayDirectory: name)
        if fileManager.fileExists(atPath: filepath, isDirectory: nil) {
            return filepath
        }
        do {
            try fileManager.createDirectory(atPath: filepath, withIntermediateDirectories: true, attributes: nil)
            print("Create JB_Dictionary Successful !")
        } catch  {
            print(error)
        }
        
        return filepath
    }
    
    /// 在对应文件夹下创建mp3格式文件 + 返回该文件路径
    public func boomCreateTempAudioFile(name:String, data:Data) {
        DispatchQueue.global().async {
            let filePath = self.boomCreateDirectory(name: self.audioArrayDirectory)
            let audioFile = filePath.appending("/" + "\(name)" + ".mp3")
            let saveData = self.audioData as NSData
            print("💗 --> audioFile: " + "\(audioFile)")
            print("💗 --> 开始写入!")
            self.boomFileManagerWritngStatus()
            saveData.write(toFile: audioFile, atomically: true)
            DispatchQueue.main.async {
                self.fileManager.fileExists(atPath: audioFile, isDirectory: nil) ? self.boomFileManagerWritingSuccessfulStatus() : self.boomFileManagerWritingFialedStatus()
            }
        }
    }
    
    /// 在对应文件夹下创建plist索引录文件 + 返回该plist索引文件
    public func boomCreateIndexPlist(name: String?) -> String {
        var appenedPath = audioArrayDirectory
        if let _name = name,
           !_name.isEmpty {
            appenedPath = _name
        }
        
        let path = boomCreateDirectory(name: audioArrayDirectory).appending("/"+"\(appenedPath)"+".plist")
        if fileManager.fileExists(atPath: path, isDirectory: nil) {
            return path
        }
        
        fileManager.createFile(atPath: path, contents: nil, attributes: nil)
        fileIndexDictionary = NSMutableDictionary()
        fileIndexDictionary.setValue("value", forKey: "key")
        fileIndexDictionary.write(toFile: path, atomically: true)
        return path
    }
    
}

//MARK: - AudioPlayerStatus

extension BoomAudioPlayerManager {
    
    /// loading
    private func boomPlayerLoadingStatus() {
        playerStatus = BoomAudioPlayerStatusType.BoomAudioPlayerStatusTypeLoading
        self.playerStatusHandler?(playerStatus)
    }
    
    /// Ready
    private func boomPlayerReadyStatus() {
        playerStatus = BoomAudioPlayerStatusType.BoomAudioPlayerStatusTypeReady
        self.playerStatusHandler?(playerStatus)
    }
    
    /// Playing
    private func boomPlayerPlayingStatus() {
        playerStatus = BoomAudioPlayerStatusType.BoomAudioPlayerStatusTypePlaying
        self.playerStatusHandler?(playerStatus)
    }
    
    /// Pause
    private func boomPlayerPauseStatus() {
        playerStatus = BoomAudioPlayerStatusType.BoomAudioPlayerStatusTypePause
        self.playerStatusHandler?(playerStatus)
    }
    
    /// Finish
    private func boomPlayerFinishStatus() {
        playerStatus = BoomAudioPlayerStatusType.BoomAudioPlayerStatusTypeFinish
        self.playerStatusHandler?(playerStatus)
    }
    
    /// Fialed
    private func boomPlayerFailedStatus() {
        playerStatus = BoomAudioPlayerStatusType.BoomAudioPlayerStatusTypeFailed
        self.playerStatusHandler?(playerStatus)
        stop()
    }
    
    /// Unknow
    private func boomPlayerUnknowStatus() {
        playerStatus = BoomAudioPlayerStatusType.BoomAudioPlayerStatusTypeUnknow
        self.playerStatusHandler?(playerStatus)
        stop()
    }
    
}

//MARK: - FileManagerStatus

extension BoomAudioPlayerManager {
    
    /// Ready
    private func boomFileManagerReadyStatus() {
        fileManagerStatus = BoomFileManagerStatusType.BoomFileManagerStatusTypeReady
        self.fileManagerStatusHandler?(fileManagerStatus)
    }
    
    /// DownloadSuccessful
    private func boomFileManagerDownloadSuccessfulStatus() {
        fileManagerStatus = BoomFileManagerStatusType.BoomFileManagerStatusTypeDownloadSuccessful
        self.fileManagerStatusHandler?(fileManagerStatus)
    }
    
    /// DownloadFialed
    private func boomFileManagerDownloadFialedStatus() {
        fileManagerStatus = BoomFileManagerStatusType.BoomFileManagerStatusTypeDownloadFailed
        self.fileManagerStatusHandler?(fileManagerStatus)
    }
    
    /// Writing
    private func boomFileManagerWritngStatus() {
        fileManagerStatus = BoomFileManagerStatusType.BoomFileManagerStatusTypeWriting
        self.fileManagerStatusHandler?(fileManagerStatus)
    }
    
    /// WritingSuccessful
    private func boomFileManagerWritingSuccessfulStatus() {
        fileManagerStatus = BoomFileManagerStatusType.BoomFileManagerStatusTypeWriteSuccessful
        self.fileManagerStatusHandler?(fileManagerStatus)
    }
    
    /// WritingFialed
    private func boomFileManagerWritingFialedStatus() {
        fileManagerStatus = BoomFileManagerStatusType.BoomFileManagerStatusTypeWriteFailed
        self.fileManagerStatusHandler?(fileManagerStatus)
    }
    
    /// Reading
    private func boomFileManagerReadingStatus() {
        fileManagerStatus = BoomFileManagerStatusType.BoomFileManagerStatusTypeReading
        self.fileManagerStatusHandler?(fileManagerStatus)
    }
    
    /// ReadSuccessful
    private func boomFileManagerReadSuccessfulStatus() {
        fileManagerStatus = BoomFileManagerStatusType.BoomFileManagerStatusTypeReadSuccessful
        self.fileManagerStatusHandler?(fileManagerStatus)
    }
    
    /// ReadFialed
    private func boomFileManagerReadFialedStatus() {
        fileManagerStatus = BoomFileManagerStatusType.BoomFileManagerStatusTypeReadFailed
        self.fileManagerStatusHandler?(fileManagerStatus)
    }
    
}

//MARK: - ※Interface For Outer

extension BoomAudioPlayerManager {
    
    /// playWith For outer
    ///@ 供外部调用的播放接口
    ///@ 三作用: --->
    ///@ 一: 初始化播放操作
    ///@ 二: 实现播放中的暂停
    ///@ 三: 实现暂停中的再次播放
    public func playWithOuter(audioUrlString:String,
                              time:Int,
                              kIfLooped:Bool,
                              progressHandler: BoomProgressHandler?,
                              playerStatusHandler: BoomPlayerStatusHandler?,
                              audioTimeHandler: BoomAudioTimeHandler?,
                              fileManagerStatusHandler: BoomFileManagerStatusHandler?) {
        
        switch BoomAudioPlayerManager.sharedPlayerManager.currentPlayerStatus {
        case .BoomAudioPlayerStatusTypePlaying:
            BoomAudioPlayerManager.sharedPlayerManager.pause()
            break
        case .BoomAudioPlayerStatusTypePause:
            BoomAudioPlayerManager.sharedPlayerManager.innerPlay()
            break
        default:
            playWithInner(audioUrlString: audioUrlString,
                          time: time,
                          kIfLooped: kIfLooped,
                          progressHandler: progressHandler,
                          playerStatusHandler: playerStatusHandler,
                          audioTimeHandler: audioTimeHandler,
                          fileManagerStatusHandler: fileManagerStatusHandler)
            break
        }
    }
    
    /// playWith For inner also outer
    ///@ 供内外皆可调用的播放接口
    ///@ 一: 本地播放优先(网络省耗策略)
    ///@ 二: 在线播放与网络下载并行(边下边播)
    ///@ 三: 纯粹播放控制,不含逻辑耦合(-> 请根据 -- currentPlayerStatus(get)方法获取状态,进行业务层逻辑开发)
    /** - Parameters
     - audioUrlString: 播放路径
     - time: 可能的音频长度
     - kIfLooped: 是否循环
     - progressHandler: 进度回调
     - playerStatusHandler: 播放器状态回调
     - audioTimeHandler: 时间回调
     - fileManagerStatusHandler: 文件管理器状态回调
     */
    public func playWithInner(audioUrlString:String,
                              time:Int,
                              kIfLooped:Bool,
                              progressHandler: BoomProgressHandler?,
                              playerStatusHandler: BoomPlayerStatusHandler?,
                              audioTimeHandler: BoomAudioTimeHandler?,
                              fileManagerStatusHandler: BoomFileManagerStatusHandler?) {
        
        if (playerStatus == BoomAudioPlayerStatusType.BoomAudioPlayerStatusTypeLoading) && (self.audioUrlString == audioUrlString) {
            return
        }
        
        self.audioUrlString = audioUrlString
        self.time = time
        self.kIfLooped = kIfLooped
        self.progressHandler = progressHandler
        self.playerStatusHandler = playerStatusHandler
        self.audioTimeHandler = audioTimeHandler
        self.fileManagerStatusHandler = fileManagerStatusHandler
        
        switch playType {
        case .BoomAudioPlayTypeLocal:
            playWithLocal(audioUrlString: audioUrlString,
                          time: time,
                          kIfLooped: kIfLooped,
                          progressHandler: progressHandler,
                          playerStatusHandler: playerStatusHandler,
                          audioTimeHandler: audioTimeHandler)
            break
        case .BoomAudioPlayTypeNetwork:
            playWithNetwork(audioUrlString: audioUrlString,
                            time:time,
                            kIfLooped: kIfLooped,
                            progressHandler: progressHandler,
                            playerStatusHandler: playerStatusHandler,
                            audioTimeHandler: audioTimeHandler)
            break
        }
    }
    
    /// playAnother
    public func playAnother(audioUrlString:String,
                            time:Int,
                            kIfLooped:Bool,
                            progressHandler: BoomProgressHandler?,
                            playerStatusHandler: BoomPlayerStatusHandler?,
                            audioTimeHandler: BoomAudioTimeHandler?,
                            fileManagerStatusHandler: BoomFileManagerStatusHandler?) {
        stop()
        playWithOuter(audioUrlString: audioUrlString,
                      time: time,
                      kIfLooped: kIfLooped,
                      progressHandler: progressHandler,
                      playerStatusHandler: playerStatusHandler,
                      audioTimeHandler: audioTimeHandler,
                      fileManagerStatusHandler: fileManagerStatusHandler)
    }
    
    /// pausePlay
    public func pause() {
        if playerStatus == .BoomAudioPlayerStatusTypeFinish {
            return
        }
        boomPlayerPauseStatus()
        pauseTimer()
        switch self.playType {
        case .BoomAudioPlayTypeLocal:
            localPlayer?.pause()
            break
        case .BoomAudioPlayTypeNetwork:
            player?.pause()
            break
        }
    }
    
    /// stopPlay
    public func stop() {
        if playerStatus == .BoomAudioPlayerStatusTypeFinish {
            return
        }
        boomPlayerFinishStatus()
        clearTimer()
        switch self.playType {
        case .BoomAudioPlayTypeLocal:
            localPlayer?.stop()
            // 如果当前时间不设置为0，那么停止将毫无意义
            localPlayer?
                .currentTime = 0
            break
        case .BoomAudioPlayTypeNetwork:
            removeObserve()
            self.player = nil
            self.playType = BoomAudioPlayType.BoomAudioPlayTypeLocal
            break
        }
    }
    
    /// 控制循环(Bool值,指定是否循环播放)
    public func setKIfLooped(kIfLooped: Bool) {
        self.kIfLooped = kIfLooped
    }
    
    /// 设置缓存模式
    public func setCacheCategory(categoy: BoomCacheCategoryType) {
        self.cacheCategory = categoy
    }
    
}
