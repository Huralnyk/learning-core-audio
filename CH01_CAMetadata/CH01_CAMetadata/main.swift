//
//  main.swift
//  CH01_CAMetadata
//
//  Created by Oleksii Huralnyk on 11.12.2019.
//  Copyright © 2019 Oleksii Huralnyk. All rights reserved.
//

import Foundation
import AudioToolbox

let arguments = CommandLine.arguments
if arguments.count < 2 {
    print("Usage: CAMetadata /full/path/to/audiofile")
    exit(-1)
}

let audioFilePath = arguments[1].expandingTildeInPath
let audioURL = URL(fileURLWithPath: audioFilePath)
print("url:", audioURL)
var audioFileID: AudioFileID?

var status = AudioFileOpenURL(audioURL as CFURL, .readPermission, 0, &audioFileID)
assert(status == noErr)

guard let audioFile = audioFileID else {
    print("Audio file at: \(audioURL) couldn't be opened")
    exit(-1)
}

var dictionarySize: UInt32 = 0
var isWritable: UInt32 = 0
status = AudioFileGetPropertyInfo(audioFile, kAudioFilePropertyInfoDictionary, &dictionarySize, &isWritable)
assert(status == noErr)

var dictionary = Dictionary<String, Any>() as CFDictionary
status = AudioFileGetProperty(audioFile, kAudioFilePropertyInfoDictionary, &dictionarySize, &dictionary)
assert(status == noErr)

print("dictionary:", dictionary)

status = AudioFileClose(audioFile)
assert(status == noErr)
