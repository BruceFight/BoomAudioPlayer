//
//  BoomAudioPlayerManager.swift
//  BoomAudioPlayer
//
//  Created by jianghongbao on 2021/4/13.
//

import Foundation

//MARK: - BoomAudioPlayerStatusTypeType

enum BoomAudioPlayerStatusType {
    case BoomAudioPlayerStatusTypeLoading //loading
    case BoomAudioPlayerStatusTypeReady   //ready
    case BoomAudioPlayerStatusTypePlaying //playing
    case BoomAudioPlayerStatusTypePause   //pause
    case BoomAudioPlayerStatusTypeFinish  //finish
    case BoomAudioPlayerStatusTypeUnknow  //unknow
    case BoomAudioPlayerStatusTypeFailed  //failed
}

//MARK: - BoomAudioPlayType

enum BoomAudioPlayType {
    case BoomAudioPlayTypeNetwork //from netWork
    case BoomAudioPlayTypeLocal   //from local
}

//MARK: - BoomFileManagerStatusType

enum BoomFileManagerStatusType {
    case BoomFileManagerStatusTypeReady
    case BoomFileManagerStatusTypeDownloadSuccessful
    case BoomFileManagerStatusTypeDownloadFailed
    case BoomFileManagerStatusTypeWriting
    case BoomFileManagerStatusTypeWriteSuccessful
    case BoomFileManagerStatusTypeWriteFailed
    case BoomFileManagerStatusTypeReading
    case BoomFileManagerStatusTypeReadSuccessful
    case BoomFileManagerStatusTypeReadFailed
}

//MARK: - BoomAudioPlayType(待定)

enum BoomCacheCategoryType {
    case BoomCacheCategoryTypeHome
    case BoomCacheCategoryTypeDocuments
    case BoomCacheCategoryTypeLibrary
    case BoomCacheCategoryTypeLibraryCaches
    case BoomCacheCategoryTypeLibraryPreference
    case BoomCacheCategoryTypeTemporary
}
