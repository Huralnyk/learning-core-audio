//
//  main.swift
//  CH04_Recorder
//
//  Created by Oleksii Huralnyk on 31.12.2019.
//  Copyright © 2019 Oleksii Huralnyk. All rights reserved.
//

import AudioToolbox

let kNumberRecordBuffers = 3

// MARK: - User Data Struct

struct Recorder {
    var recordFile: AudioFileID? // reference to your output file
    var recordPacket: Int64 = 0  // current packet index in output file
    var running: Bool = false    // recording state
}

// MARK: - Utility Functions

extension FixedWidthInteger {
    func byteArray() -> [UInt8] {
        return withUnsafeBytes(of: self.bigEndian) { Array($0) }
    }
}

func whenFailed(message: String, routine: () -> OSStatus) {
    let status = routine()
    guard status != noErr else { return }
    // see if it appears to be a 4-char-code
    if let code = String(bytes: status.byteArray(), encoding: .utf8), code.count == 4 {
        print("Error: \(message) (\(code))")
    } else {
        print("Error: \(message) (\(status))")
    }
    exit(1)
}

func getDefaultInputDeviceSampleRate(sampleRate: inout Float64) -> OSStatus {
    var status: OSStatus
    var deviceID: AudioDeviceID = 0
    var propertyAddress = AudioObjectPropertyAddress()
    var propertySize: UInt32
    
    // get the default input device
    propertyAddress.mSelector = kAudioHardwarePropertyDefaultInputDevice
    propertyAddress.mScope = kAudioObjectPropertyScopeGlobal
    propertyAddress.mElement = 0
    propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
    status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &propertySize, &deviceID)
    guard status == noErr else { return status }

    // get its sample rate
    propertyAddress.mSelector = kAudioDevicePropertyNominalSampleRate
    propertyAddress.mScope = kAudioObjectPropertyScopeGlobal
    propertyAddress.mElement = 0
    propertySize = UInt32(MemoryLayout<Float64>.size)
    status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, &sampleRate)
    return status
}

func computeRecordBufferSize(_ format: inout AudioStreamBasicDescription, _ queue: AudioQueueRef, _ duration: TimeInterval) -> UInt32 {
    var packets: UInt32 = 0
    var frames: UInt32 = 0
    var bytes: UInt32 = 0
    
    frames = UInt32(ceil(duration * Double(format.mSampleRate)))
    
    if format.mBytesPerFrame > 0 {
        bytes = frames * format.mBytesPerFrame
    } else {
        var maxPacketSize: UInt32 = 0
        if format.mBytesPerPacket > 0 {
            maxPacketSize = format.mBytesPerPacket
        } else {
            // get the largest single packet size possible
            var propertySize = UInt32(MemoryLayout.size(ofValue: maxPacketSize))
            whenFailed(message: "Couldn't get queue's maximum output packet size") {
                AudioQueueGetProperty(queue, kAudioConverterPropertyMaximumOutputPacketSize, &maxPacketSize, &propertySize)
            }
        }
        if format.mFramesPerPacket > 0 {
            packets = frames / format.mFramesPerPacket
        } else {
            // worst-case scenario: 1 frame in a packet
            packets = frames
        }
        
        // sanity check
        if packets == 0 {
            packets = 1
        }
        
        bytes = packets * maxPacketSize
    }
    
    return bytes
}

func copyEncoderCookieToFile(_ queue: AudioQueueRef, _ file: AudioFileID) {
    var status = noErr
    var propertySize: UInt32 = 0
    
    status = AudioQueueGetPropertySize(queue, kAudioQueueProperty_MagicCookie, &propertySize)
    guard status == noErr && propertySize > 0 else { return }
    
    var magicCookie = [UInt8](repeating: 0, count: Int(propertySize))
    whenFailed(message: "Couldn't get audio queue's magic cookie") {
        AudioQueueGetProperty(queue, kAudioQueueProperty_MagicCookie, &magicCookie, &propertySize)
    }
    
    whenFailed(message: "Couldn't get audio file's magic cookie") {
        AudioFileSetProperty(file, kAudioFilePropertyMagicCookieData, propertySize, &magicCookie)
    }
}

// MARK: - Record Callback Function

var audioQueueInputCallback: AudioQueueInputCallback = { userData, queue, buffer, startTime, numPackets, packetDesc in
    guard let p = userData?.bindMemory(to: Recorder.self, capacity: MemoryLayout<Recorder>.size) else { return }
    guard packetDesc != nil else { return }
    var numPackets = numPackets
    
    // write packets to file
    whenFailed(message: "AudioFileWritePackets failed") {
        AudioFileWritePackets(p.pointee.recordFile!, false, buffer.pointee.mAudioDataByteSize, packetDesc, p.pointee.recordPacket, &numPackets, buffer.pointee.mAudioData)
    }
    // increment the packet index
    p.pointee.recordPacket += Int64(numPackets)

    if p.pointee.running {
        whenFailed(message: "AudioQueueEnqueueBuffer failed") {
            AudioQueueEnqueueBuffer(queue, buffer, 0, nil)
        }
    }
}

// MARK: - Main Function

func run() {
//    var recorder = Recorder()
    
    // Set up format
    var format = AudioStreamBasicDescription()
    format.mFormatID = kAudioFormatMPEG4AAC
    format.mChannelsPerFrame = 2
    whenFailed(message: "Couldn't get default sample rate") {
        getDefaultInputDeviceSampleRate(sampleRate: &format.mSampleRate)
    }
    
//    var propSize = UInt32(MemoryLayout.size(ofValue: format))
//    whenFailed(message: "Audio Format Get Propery failed") {
//        AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, nil, &propSize, &format)
//    }
//
//    // Set up queue
//    var queue: AudioQueueRef?
//    whenFailed(message: "AudioQueueNewInput failed") {
//        AudioQueueNewInput(&format, audioQueueInputCallback, &recorder, nil, nil, 0, &queue)
//    }
//
//    var size = UInt32(MemoryLayout.size(ofValue: format))
//    whenFailed(message: "Couldn't get queue's format") {
//        AudioQueueGetProperty(queue!, kAudioConverterCurrentOutputStreamDescription, &format, &size)
//    }
//
//    // Set up file
//    guard let fileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, "output.caf" as CFString, .cfurlposixPathStyle, false) else {
//        exit(1)
//    }
//    whenFailed(message: "AudioFileCreateWithURL failed") {
//        AudioFileCreateWithURL(fileURL, kAudioFileCAFType, &format, .eraseFile, &recorder.recordFile)
//    }
//
//    copyEncoderCookieToFile(queue!, recorder.recordFile!)
//
//    let bufferByteSize = computeRecordBufferSize(&format, queue!, 0.5)
//
//    for _ in 0..<kNumberRecordBuffers {
//        var buffer: AudioQueueBufferRef?
//        whenFailed(message: "AudioQueueAllocateBuffer failed") {
//            AudioQueueAllocateBuffer(queue!, bufferByteSize, &buffer)
//        }
//        whenFailed(message: "AudioQueueEnqueueBuffer failed") {
//            AudioQueueEnqueueBuffer(queue!, buffer!, 0, nil)
//        }
//    }
//
//    recorder.running = true
//    whenFailed(message: "AudioQueueStart failed") {
//        AudioQueueStart(queue!, nil)
//    }
//
//    print("Recording, press <return> to stop:")
//    getchar()
//
//    print("* Recording done *")
//    recorder.running = false
//    whenFailed(message: "AudioQueueStop failed") {
//        AudioQueueStop(queue!, true)
//    }
//
//    copyEncoderCookieToFile(queue!, recorder.recordFile!)
//
//    AudioQueueDispose(queue!, true)
//    AudioFileClose(recorder.recordFile!)
}

run()
