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


let COLOURS: [UIColor] = (0..<4).map({ i in UIColor(named: "C\(i)")!});


func draw_preds(on image: UIImage, predictions: [IAModel.Prediction]?) -> UIImage? {
    if let predictions = predictions {
        var bmp = image
        let sx = image.size.width / 640.0
        let sy = image.size.height / 640.0
        
        autoreleasepool {
            let rendererFormat = UIGraphicsImageRendererFormat();
            rendererFormat.scale = 1;
            let renderer = UIGraphicsImageRenderer(size: bmp.size, format: rendererFormat);
            bmp = renderer.image(actions: { ctx in
                // Draw original image
                image.draw(in: CGRect(x: 0, y: 0, width: bmp.size.width, height: bmp.size.height))
                ctx.cgContext.setShouldAntialias(true)
                ctx.cgContext.setStrokeColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 1.0)
                ctx.cgContext.setLineWidth(10.0)
                
                for (i, pred) in predictions.enumerated() {
                    let colour = COLOURS[i % COLOURS.count]
                    colour.setStroke()
                    
                    let (x1, y1, x2, y2) = pred.box.xyxy()
                    let (w, h) = (x2 - x1, y2 - y1)
                    
                    let rect = CGRect(x: CGFloat(x1)*sx, y: CGFloat(y1)*sy, width: CGFloat(w)*sx, height: CGFloat(h)*sy);
                    ctx.stroke(rect);
                    let conf_rounded = Int((pred.confidence * 100.0).rounded())
                    let label = "\(pred.label) \(conf_rounded)%"
                    let attrs = [
                        NSAttributedString.Key.font: UIFont(name: "Helvetica", size: 45)!,
                        NSAttributedString.Key.foregroundColor: CGColor(gray: 1.0, alpha: 1.0),
                        NSAttributedString.Key.backgroundColor: colour,
                    ]
                    label.draw(at: CGPoint(x: CGFloat(x1)*sx, y: CGFloat(y2)*sy - 50.0), withAttributes: attrs)
                }
            });
        }
        
        return UIImage(cgImage: bmp.cgImage!)
    }
    else {
        return nil
    }
}
