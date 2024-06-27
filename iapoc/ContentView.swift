// File: ContentView.swift
// Package: iapoc
// Created: 24/06/2024
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

import SwiftUI
import PhotosUI

struct InferenceResultsView: View {
    let segmentationResult: UIImage?
    
    var body: some View {
        if let segmentationResult = segmentationResult {
            Image(uiImage: segmentationResult).resizable(resizingMode: .stretch).aspectRatio(contentMode: .fit)
        }
        else {
            Image(systemName: "eye.square")
                .font(.system(size: 40))
                .symbolRenderingMode(.multicolor)
                .foregroundColor(.secondary)
        }
    }
}

struct ImageView: View {
    let imageState: ImageModel.ImageState
    
    var body: some View {
        switch imageState {
        case .success(let ui_image):
            Image(uiImage: ui_image).resizable(resizingMode: .stretch).aspectRatio(contentMode: .fit)
        case .loading:
            ProgressView()
        case .empty:
            Image(systemName: "photo.artframe")
                .font(.system(size: 40))
                .foregroundColor(.blue)
        case .failure:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.red)
        }
    }
}

struct EditableImageView: View {
    @ObservedObject public var viewModel: ImageModel
    
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // left: image picker
            PhotosPicker(selection: $viewModel.imageSelection,
                         matching: .images,
                         photoLibrary: .shared()) {
                ImageView(imageState: viewModel.imageState).frame(maxWidth: .infinity, maxHeight: .infinity).overlay(alignment: .bottomTrailing) {
                }
            }.buttonStyle(.borderless).frame(minWidth: 0, maxWidth: .infinity)
            InferenceResultsView(segmentationResult: viewModel.segmentationResult).frame(minWidth: 0, maxWidth: .infinity)
        }
    }
}

struct ContentView: View {
    @StateObject var viewModel = ImageModel();
    
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            EditableImageView(viewModel: viewModel)
        }
    }
    
}

#Preview {
    ContentView()
}
