//
//  main.swift
//  CH03_CAStreamFormatTester
//
//  Created by Oleksii Huralnyk on 20.12.2019.
//  Copyright © 2019 Oleksii Huralnyk. All rights reserved.
//

import Foundation
import AudioToolbox

extension FixedWidthInteger {
    func byteArray() -> [UInt8] {
        return withUnsafeBytes(of: self.bigEndian) { Array($0) }
    }
}

var fileTypeAndFormat = AudioFileTypeAndFormatID()
fileTypeAndFormat.mFileType = kAudioFileCAFType
fileTypeAndFormat.mFormatID = kAudioFormatiLBC

var status: OSStatus = noErr
var infoSize: UInt32 = 0

status = AudioFileGetGlobalInfoSize(
    kAudioFileGlobalInfo_AvailableStreamDescriptionsForFormat,
    UInt32(MemoryLayout.size(ofValue: fileTypeAndFormat)),
    &fileTypeAndFormat,
    &infoSize
)
assert(status == noErr, "status: \(String(bytes: status.byteArray(), encoding: .utf8) ?? "")")

let asbdCount = Int(infoSize) / MemoryLayout<AudioStreamBasicDescription>.size
var asbds: [AudioStreamBasicDescription] = Array<AudioStreamBasicDescription>(repeating: .init(), count: asbdCount)
status = AudioFileGetGlobalInfo(
    kAudioFileGlobalInfo_AvailableStreamDescriptionsForFormat,
    UInt32(MemoryLayout.size(ofValue: fileTypeAndFormat)),
    &fileTypeAndFormat,
    &infoSize,
    &asbds
)
assert(status == noErr)

for (i, asbd) in asbds.enumerated() {
    let format4cc = String(bytes: asbd.mFormatID.byteArray(), encoding: .utf8) ?? ""
    print(String(format: "%d: mFormatID: %@, mFormatFlags: %d, mBitsPerChannel: %d", i, format4cc, asbd.mFormatFlags, asbd.mBitsPerChannel))
}

