//
//  Regift.swift
//  Regift
//
//  Created by Matthew Palmer on 27/12/2014.
//  Copyright (c) 2014 Matthew Palmer. All rights reserved.
//

import UIKit
import ImageIO
import MobileCoreServices
import AVFoundation
import QuartzCore

public typealias TimePoint = CMTime

public class Regift: NSObject {
    struct Constants {
        static let FileName = "regift.gif"
        static let TimeInterval: Int32 = 600
        static let Tolerance = 0.01
    }
    
    // Convert the video at the given URL to a GIF, and return the GIF's URL if it was created.
    // The frames are spaced evenly over the video, and each has the same duration.
    // loopCount is the number of times the GIF will repeat. Defaults to 0, which means repeat infinitely.
    // delayTime is the amount of time for each frame in the GIF.
    public class func createGIFFromURL(URL: NSURL, size: CGSize , withFrameCount frameCount: Int, delayTime: Float, loopCount: Int = 0) -> NSURL? {
        let fileProperties = [kCGImagePropertyGIFDictionary as String: [
            kCGImagePropertyGIFLoopCount as String: loopCount
        ]];
        
        let frameProperties = [kCGImagePropertyGIFDictionary as String: [
            kCGImagePropertyGIFDelayTime as String: delayTime
        ]];
        
        let asset = AVURLAsset(URL: URL, options: [NSObject: AnyObject]())

        // The total length of the movie, in seconds.
        let movieLength = Float(asset.duration.value) / Float(asset.duration.timescale)
        
        // How far along the video track we want to move, in seconds.
        let increment = Float(movieLength) / Float(frameCount)
        
        // Add each of the frames to the buffer
        var timePoints: [TimePoint] = []
        
        for frameNumber in 0 ..< frameCount {
            let seconds: Float64 = Float64(increment) * Float64(frameNumber)
            let time = CMTimeMakeWithSeconds(seconds, Constants.TimeInterval)
            
            timePoints.append(time)
        }
        
        let gifURL = Regift.createGIFForTimePoints(timePoints, fromURL: URL, size: size , fileProperties: fileProperties, frameProperties: frameProperties, frameCount: frameCount)
        
        return gifURL
    }
    
    public class func createGIFFromURL(URL: NSURL, withFrameCount frameCount: Int, delayTime: Float, loopCount: Int = 0) -> NSURL? {
        let asset = AVURLAsset(URL: URL, options: [NSObject: AnyObject]())
        let size = self.getVideoSize(asset)
        return self.createGIFFromURL(URL, size: size, withFrameCount: frameCount, delayTime: delayTime, loopCount: loopCount)
    }
    
    public class func createGIFForTimePoints(timePoints: [TimePoint], fromURL URL: NSURL, size: CGSize, fileProperties: [String: AnyObject], frameProperties: [String: AnyObject], frameCount: Int) -> NSURL? {
        let temporaryFile = NSTemporaryDirectory().stringByAppendingPathComponent(Constants.FileName)
        let fileURL = NSURL.fileURLWithPath(temporaryFile, isDirectory: false)
        
        if fileURL == nil {
            return nil
        }
        
        let destination = CGImageDestinationCreateWithURL(fileURL!, kUTTypeGIF, frameCount, NSDictionary())
        
        CGImageDestinationSetProperties(destination, fileProperties as CFDictionaryRef)
        let asset = AVURLAsset(URL: URL, options: [NSObject: AnyObject]())
        let generator = AVAssetImageGenerator(asset: asset)
        
        generator.appliesPreferredTrackTransform = true
        let tolerance = CMTimeMakeWithSeconds(Constants.Tolerance, Constants.TimeInterval)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance
        
        var error: NSError?
        for time in timePoints {
            var imageRef = generator.copyCGImageAtTime(time, actualTime: nil, error: &error)
            imageRef = self.resize(imageRef, size: size)
            if let error = error {
                return nil
            }
            
            CGImageDestinationAddImage(destination, imageRef, frameProperties as CFDictionaryRef)
        }
        
        // Finalize the gif
        if !CGImageDestinationFinalize(destination) {
            println("Failed to finalize image destination")
            return nil
        }
        
        return fileURL
    }
    
    class func resize(image: CGImageRef!, size: CGSize!) -> CGImageRef! {
        let origSize = CGSizeMake(CGFloat(CGImageGetWidth(image)), CGFloat(CGImageGetHeight(image)))
        
        if CGSizeEqualToSize(origSize, size) {
            return image
        }

        let bitsPerComponent = CGImageGetBitsPerComponent(image)
        let bytesPerRow = CGImageGetBytesPerRow(image)
        let colorSpace = CGImageGetColorSpace(image)
        let bitmapInfo = CGImageGetBitmapInfo(image)
        
        let context = CGBitmapContextCreate(nil, Int(size.width), Int(size.height), bitsPerComponent, bytesPerRow, colorSpace, bitmapInfo)
        
        CGContextSetInterpolationQuality(context, kCGInterpolationHigh)
        
        CGContextDrawImage(context, CGRect(origin: CGPointZero, size: size), image)
        
        let scaledImage = CGBitmapContextCreateImage(context)
        
        return scaledImage
    }
    
    class func getVideoSize(videoAsset: AVURLAsset!) -> CGSize! {
        var size = CGSizeMake(0, 0);
        let videoTracks = videoAsset.tracksWithMediaType(AVMediaTypeVideo) as! Array<AVAssetTrack>;
        
        if !videoTracks.isEmpty {
            let videoTrack = videoTracks[0]
            size = CGSizeApplyAffineTransform(videoTrack.naturalSize, videoTrack.preferredTransform)
            size = CGSizeMake(abs(size.width), abs(size.height))
        }
        
        return size
    }
}
