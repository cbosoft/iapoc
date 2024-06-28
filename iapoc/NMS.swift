// File: NMS.swift
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


func calc_iou(_ a: BBox, _ b: BBox) -> Float {
    let (ax1, ay1, ax2, ay2) = a.xyxy()
    let (bx1, by1, bx2, by2) = b.xyxy()

    // Get area of intersection
    let i_x1 = max(ax1, bx1)
    let i_y1 = max(ay1, by1)
    let i_x2 = min(ax2, bx2)
    let i_y2 = min(ay2, by2)
    let i_w = i_x2 - i_x1
    let i_h = i_y2 - i_y1
    let area_intersection = i_w*i_h

    // Get area of both boxes, subtract intersection -> gives union
    let area_a = (ax2 - ax1)*(ay2 - ay1)
    let area_b = (bx2 - bx1)*(by2 - by1)
    let area_union = area_a + area_b - area_intersection

    let iou = area_intersection / area_union

    if iou < 0.0 {
        return 0.0
    }
    else {
        return iou
    }
}


func best_pred(_ preds: [IAModel.Prediction]) -> Int {
    var best = 0
    var best_score = preds[0].confidence
    for (i, pred) in preds.enumerated() {
        if pred.confidence > best_score {
            best = i
            best_score = pred.confidence
        }
    }
    return best
}


func nonmax_suppression(_ predictions: [IAModel.Prediction], iou_threshold: Float = 0.5) -> [IAModel.Prediction] {
    var working_predictions = predictions
    let finalised_predictions: [IAModel.Prediction] = []

    while working_predictions.count > 0 {
        let top_i = best_pred(working_predictions)
        let top_pred = working_predictions.remove(at: top_i)

        finalised_predictions.append(top_pred)
        var to_remove = []
        for (i, other_pred) in working_predictions.enumerated() {
            let iou = calc_iou(top_pred.box, other_pred.box)
            if iou < iou_threshold {
                to_remove.append(i)
            }
        }

        for i in to_remove.reversed() {
            working_predictions.remove(at: i)
        }

    }

    return finalised_predictions
}
