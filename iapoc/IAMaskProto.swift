// File: IAMaskProto.swift
// Package: iapoc
// Created: 28/06/2024
//
// MIT License
// 
// Copyright © 2020 Christopher Boyle
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import CoreML
import UIKit


public struct PixelData {
    var a: UInt8
    var r: UInt8
    var g: UInt8
    var b: UInt8
}


// https://stackoverflow.com/questions/30958427/pixel-array-to-uiimage-in-swift
func imageFromARGB32Bitmap(pixels: [PixelData], width: Int, height: Int) -> UIImage? {
    guard width > 0 && height > 0 else { return nil }
    guard pixels.count == width * height else { return nil }

    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
    let bitsPerComponent = 8
    let bitsPerPixel = 32

    var data = pixels // Copy to mutable []
    guard let providerRef = CGDataProvider(data: NSData(bytes: &data,
                            length: data.count * MemoryLayout<PixelData>.size)
        )
        else { return nil }

    guard let cgim = CGImage(
        width: width,
        height: height,
        bitsPerComponent: bitsPerComponent,
        bitsPerPixel: bitsPerPixel,
        bytesPerRow: width * MemoryLayout<PixelData>.size,
        space: rgbColorSpace,
        bitmapInfo: bitmapInfo,
        provider: providerRef,
        decode: nil,
        shouldInterpolate: true,
        intent: .defaultIntent
        )
        else { return nil }

    return UIImage(cgImage: cgim)
}


class IAMaskProto {
    // N x H x W
    var proto: [[[Float]]]
    var n: Int
    var h: Int
    var w: Int
    
    init(data: MLMultiArray) {
        // 1 x N x H/4 x W/4
        assert(data.shape.count == 4)
        assert(data.shape[0] == (1 as NSNumber))
        let n = data.shape[1].intValue
        let h = data.shape[2].intValue
        let w = data.shape[3].intValue
        self.proto = (0..<n).map({ i in (0..<h).map({ r in (0..<w).map({ c in data[[0, i as NSNumber, r as NSNumber, c as NSNumber]].floatValue })})})
        self.n = n
        self.h = h
        self.w = w
    }
    
    public func get_weighted_mask(_ weights: [Float]) -> [[Float]] {
        assert(weights.count == proto.count)
        let merged = (0..<h).map({r in
            (0..<w).map({c in
                (0..<n).reduce(0.0, {(running, i) in
                    running + (weights[i] * proto[i][r][c]
                )}
            )}
        )})
        return merged
    }
    
    static func fltarr2image(_ arr: [[Float]], r: UInt8 = 255, g: UInt8 = 0, b: UInt8 = 255, thresh: Float = 0.0) -> UIImage {
        let h = arr.count
        let w = arr[0].count
        
        // create 8bit bitmap image data
        var pixels: [PixelData] = []
        for row in arr {
            for f in row {
                let a: UInt8 = UInt8(f < thresh ? 0 : 127)
                pixels.append(PixelData(a: a, r: r, g: g, b: b))
            }
        }
        let image = imageFromARGB32Bitmap(pixels: pixels, width: w, height: h)!
        return image
    }
}
