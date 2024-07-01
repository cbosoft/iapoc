// File: IAModel.swift
// Package: iapoc
// Created: 25/06/2024
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

import Foundation
import CoreML
import Vision
import UIKit


@MainActor
class IAModel {
    
    /// Threshold score below which detections are discarded
    private let score_thresh: Float;
    
    /// A dictionary of prediction handler functions, each keyed by its Vision request.
    private var predictionHandlers: [VNRequest: ImagePredictionHandler]
    
    public init(scoreThresh: Float = 0.5) {
        self.predictionHandlers = [VNRequest: ImagePredictionHandler]()
        self.score_thresh = scoreThresh
    }
    
    /// - Tag: name
    static func createModel() -> (VNCoreMLModel, [Int: String]) {
        let defaultConfig = MLModelConfiguration()

        let inner = try? yolov8m_seg(configuration: defaultConfig)

        guard let inner = inner else {
            fatalError("App failed to create yolo model instance.")
        }
        
        let metadata = inner.model.modelDescription.metadata
        let creator_data = metadata[.creatorDefinedKey] as! [String: String]
        let names_str_raw = creator_data["names"]!
        let names_str = names_str_raw
            .replacingOccurrences(of: "{", with: "{'")
            .replacingOccurrences(of: ":", with: "':")
            .replacingOccurrences(of: ", ", with: ", '")
            .replacingOccurrences(of: "'", with: "\"")
        let names_json = names_str.data(using: .utf8)!
        let label_names = try! JSONDecoder().decode([Int: String].self, from: names_json)

        // Create a Vision instance using the image classifier's model instance.
        guard let vision_model = try? VNCoreMLModel(for: inner.model) else {
            fatalError("App failed to create a `VNCoreMLModel` instance.")
        }

        return (vision_model, label_names)
    }
    
    private static let (model, label_names) = createModel()
    
    /// Stores a classification name and confidence for an image classifier's prediction.
    /// - Tag: Prediction
    struct Prediction {
        let confidence: Float
        let label: String
        let label_index: Int
        let box: BBox
        let mask_weights: [Float]
    }

    /// The function signature the caller must provide as a completion handler.
    typealias ImagePredictionHandler = (_ predictions: [Prediction]?) -> Void
    
    private func createRequest() -> VNImageBasedRequest {
        // Create an image classification request with an image classifier model.

        let imageInferenceRequest = VNCoreMLRequest(model: IAModel.model,
                                                         completionHandler: visionRequestHandler)

        imageInferenceRequest.imageCropAndScaleOption = .centerCrop
        return imageInferenceRequest
    }
    
    /// Generates an image classification prediction for a photo.
    /// - Parameter photo: An image, typically of an object or a scene.
    /// - Tag: makePredictions
    func makePredictions(for photo: UIImage, completionHandler: @escaping ImagePredictionHandler) throws {
        let orientation = CGImagePropertyOrientation(photo.imageOrientation)

        guard let photoImage = photo.cgImage else {
            fatalError("Photo doesn't have underlying CGImage.")
        }

        let request = createRequest()
        predictionHandlers[request] = completionHandler

        let handler = VNImageRequestHandler(cgImage: photoImage, orientation: orientation)
        let requests: [VNRequest] = [request]

        // Start the image classification request.
        try handler.perform(requests)
    }
    
    private func visionRequestHandler(_ request: VNRequest, error: Error?) {
        // Remove the caller's handler from the dictionary and keep a reference to it.
        guard let predictionHandler = predictionHandlers.removeValue(forKey: request) else {
            fatalError("Every request must have a prediction handler.")
        }

        // Start with a `nil` value in case there's a problem.
        var predictions: [Prediction]? = nil

        // Impromptu context manager syntax? Swift has some cool stuff
        defer {
            // Send the predictions back to the client.
            predictionHandler(predictions)
        }

        // Check for an error first.
        if let error = error {
            print("Vision image inference error...\n\n\(error.localizedDescription)")
            return
        }

        // Check that the results aren't `nil`.
        if request.results == nil {
            print("Vision request had no results.")
            return
        }
        
        guard let observations = request.results as? [VNCoreMLFeatureValueObservation] else {
            print("uh oh, wrong type: \(type(of: request.results))")
            return
        }
        
        for observation in observations {
            if let data = observation.featureValue.multiArrayValue{
                if observation.featureName == "p" {
                    // TODO: handle segmentation data
                    // data is the 32 prototype masks used to build the mask for each of the detections
                }
                else if observation.featureName == "var_1279" {
                    predictions = []
                    let npreds = data.shape[2].intValue;
                    for i in 0..<npreds {
                        let i = i as NSNumber;
                        
                        // First 4 are boxes
                        let box_points: [Float] = (0..<4).map({ j in
                            data[[0, j as NSNumber, i]].floatValue
                        });
                        let box = BBox(x: box_points[0], y: box_points[1], w: box_points[2], h: box_points[3])
                        
                        // Next 80 are confidence scores
                        let scores: [Float] = (4..<84).map({ j in
                            data[[0, j as NSNumber, i]].floatValue
                        });

                        // Next 32 are mask weights used to create the final mask from the prototype masks
                        let mask_weights: [Float] = (84..<116).map({ j in
                            data[[0, j as NSNumber, i]].floatValue
                        });
                        
                        // Get the most likely class (i.e. with highest score)
                        let score = scores.max()!
                        let label_index = scores.firstIndex(of: score)! // I hate this
                        let label = IAModel.label_names[label_index]!

                        // If score is above threshold, store prediction result.
                        if score > self.score_thresh {
                            predictions?.append(Prediction(confidence: score, label: label, label_index: label_index, box: box, mask_weights: mask_weights))
                        }
                    }
                }
            }
        }

        if predictions != nil {
            predictions = nonmax_suppression(predictions!)
        }
    }
}
