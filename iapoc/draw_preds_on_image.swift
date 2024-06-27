// File: draw_preds_on_image.swift
// Package: iapoc
// Created: 27/06/2024
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

import UIKit


func draw_preds(on image: UIImage, predictions: [IAModel.Prediction]?) -> UIImage? {
    if let predictions = predictions {
        var bmp = image;
        let sx = image.size.width / 640.0
        let sy = image.size.height / 640.0
        autoreleasepool {
            let rendererFormat = UIGraphicsImageRendererFormat();
            rendererFormat.scale = 1;
            let renderer = UIGraphicsImageRenderer(size: bmp.size, format: rendererFormat);
            bmp = renderer.image(actions: { ctx in
                // Draw original image
                ctx.cgContext.draw(bmp.cgImage!, in: CGRect(x: 1, y: 1, width: bmp.size.width-1, height: bmp.size.height-1));
                ctx.cgContext.setShouldAntialias(true);
                ctx.cgContext.setStrokeColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 1.0); // yellow
                ctx.cgContext.setLineWidth(10.0);
                
                for pred in predictions {
                    debugPrint("pred conf \(pred)")
                    
                    let x = pred.box[0];
                    let y = pred.box[1];
                    let w = pred.box[2] - x;
                    let h = pred.box[3] - y;
                    
                    let rect = CGRect(x: CGFloat(x)*sx, y: CGFloat(y)*sy, width: CGFloat(w)*sx, height: CGFloat(h)*sy);
                    ctx.stroke(rect);
                }
            });
        }
        
        // Image is upside down 😭
        return UIImage(cgImage: bmp.cgImage!, scale: image.scale, orientation: image.imageOrientation)
    }
    else {
        return nil
    }
}
