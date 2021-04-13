//
//  ViewController.swift
//  BoomAudioPlayer
//
//  Created by jianghongbao on 2021/4/13.
//

import UIKit

class ViewController: UIViewController {
    
    //TODO: 待补充
    /*
     1.支持是否同步下载到本地功能
     2.抽取与细化
     3.组播放下载功能
     */
    
    let s1 = "https://audio.xiaozhibo.com/dev/586b67943518301a88514d01.mp3"
    let s2 = "http://m2.music.126.net/zLk1RXSKMONJye6jB3mjSA==/1407374887680902.mp3"
    
    var titles: [String] = ["播放", "暂停", "停止"]
    var colors: [UIColor] = [.green, .yellow, .red]
    var selectors: [Selector] = [#selector(play), #selector(pause), #selector(stop)]
    var operButtons: [UIButton] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        for (index, title) in self.titles.enumerated() {
            let button = UIButton()
            button.center = view.center
            button.setTitleColor(self.colors[index], for: .normal)
            button.setTitle(title, for: .normal)
            button.backgroundColor = .black
            button.addTarget(self, action: self.selectors[index], for: .touchUpInside)
            self.operButtons.append(button)
            self.view.addSubview(button)
        }
        
        print("NSHomeDirectory:"+"\(NSHomeDirectory())\n")
        print("NSHomeDirectoryForUser:"+"\(String(describing: NSHomeDirectoryForUser("JIANG-HONG-BAO")))\n")
        print("NSTemporaryDirectory:"+"\(NSTemporaryDirectory())\n")
        
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        var preButton: UIButton?
        let buttonSize: CGSize = CGSize.init(width: 150, height: 30)
        
        self.operButtons.forEach { (button) in
            if let _preButton = preButton {
                button.frame = CGRect.init(x: 0, y: _preButton.frame.maxY + 50, width: buttonSize.width, height: buttonSize.height)
            } else {
                if #available(iOS 11.0, *) {
                    button.frame = CGRect.init(x: 0, y: self.view.safeAreaInsets.top + 50, width: buttonSize.width, height: buttonSize.height)
                } else {
                    // Fallback on earlier versions
                }
            }
            button.center.x = self.view.center.x
            preButton = button
        }
    }
    
    @objc func play() {
        BoomAudioPlayerManager.sharedPlayerManager.playWithOuter(audioUrlString: s1, time: 10, kIfLooped: true, progressHandler: {(progress) in
            print("💗currentDownloadRatio > :"+"\(progress)")
        }, playerStatusHandler: { (playerStatus) in
            print("💗playerStatus >> :"+"\(playerStatus)")
        }, audioTimeHandler: { (minute, seconds) in
            print("💗minute >>> "+"\(minute) "+"分 "+"seconds >>> "+"\(seconds)"+"秒 ")
        }) { (fileManagerStatus) in
            print("💗fileManagerStatus >>>> :"+"\(fileManagerStatus)")
        }
    }
    
    @objc func pause() {
        BoomAudioPlayerManager.sharedPlayerManager.pause()
        
    }
    
    @objc func stop() {
        BoomAudioPlayerManager.sharedPlayerManager.stop()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}
