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
    static func createModel() -> VNCoreMLModel {
        let defaultConfig = MLModelConfiguration()

        let wrapper = try? yolov8m_seg(configuration: defaultConfig)

        guard let wrapper = wrapper else {
            fatalError("App failed to create yolo model instance.")
        }

        // Create a Vision instance using the image classifier's model instance.
        guard let vision_model = try? VNCoreMLModel(for: wrapper.model) else {
            fatalError("App failed to create a `VNCoreMLModel` instance.")
        }

        return vision_model
    }
    
    private static let model = createModel()
    
    /// Stores a classification name and confidence for an image classifier's prediction.
    /// - Tag: Prediction
    struct Prediction {
        let confidence: Float
        let label: Int
        let box: [Float] // xywh? xyxy? who knows!
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
        
        predictions = [];
        for observation in observations {
            if let data = observation.featureValue.multiArrayValue{
                if observation.featureName == "p" {
                    print(data[[0, 0, 0, 1]], data[1]);
                    // TODO: handle segmentation data
                }
                else if observation.featureName == "var_1279" {
                    let npreds = data.shape[2].intValue;
                    var overall_class: Int = -1;
                    var overall_score: Float = -1;
                    var overall_box: [Float] = [0, 0, 0, 0];
                    for i in 0..<npreds {
                        let i = i as NSNumber;
                        
                        // First 4 are maybe boxes (see later)
                        // Next 80 are confidence scores
                        let scores: [Float] = (4..<84).map({ j in
                            data[[0, j as NSNumber, i]].floatValue
                        });
                        
                        // First 4 or final 32 could be bboxes
                        // First 4 are maybe in pixel units while last lot are all in (-1..1)
                        let off = 84;
                        let box: [Float] = (0..<4).map({ j in
                            data[[0, (j + off) as NSNumber, i]].floatValue * 640.0
                        });
                        
                        // Get the most likely class (i.e. with highest score)
                        let max_score = scores.max()!;
                        let i_max = scores.firstIndex(of: max_score)!; // I hate this
                        if max_score > overall_score {
                            overall_score = max_score;
                            overall_class = i_max;
                            overall_box = box;
                        }
                    }
                    
                    // If score is above threshold, store prediction result.
                    if overall_score > self.score_thresh {
                        predictions?.append(Prediction(confidence: overall_score, label: overall_class, box: overall_box));
                    }
                }
            }
        }
    }
}
