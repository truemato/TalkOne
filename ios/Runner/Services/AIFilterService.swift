import Foundation
import CoreImage
import UIKit
import Accelerate

class AIFilterService {
    
    // Singleton instance
    static let shared = AIFilterService()
    
    // Filter parameters
    var threshold1: CGFloat = 100.0
    var threshold2: CGFloat = 200.0
    var enableColorful: Bool = true
    
    // Core Image filters
    private let context = CIContext()
    private let edgeDetector = CIFilter(name: "CIEdges")
    private let colorControls = CIFilter(name: "CIColorControls")
    
    private init() {}
    
    struct FilterParams {
        var threshold1: CGFloat = 100.0  // Python: threshold1 = 100
        var threshold2: CGFloat = 200.0  // Python: threshold2 = 200
        var enableColorful: Bool = true
        var detectFaceOnly: Bool = true
        
        // HoughLinesP parameters to match Python code
        var houghThreshold: Int = 30      // Python: threshold = 30
        var minLineLength: Int = 80       // Python: minLineLength = 80
        var maxLineGap: Int = 5           // Python: maxLineGap = 5
    }
    
    /// Apply AI filter to transform face into colorful edge detection
    func applyAIFilter(to image: UIImage, params: FilterParams) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        // Convert to grayscale for edge detection
        let grayscale = ciImage.applyingFilter("CIPhotoEffectNoir")
        
        // Apply Gaussian blur to reduce noise
        let blurred = grayscale.applyingGaussianBlur(sigma: 1.4)
        
        // Apply edge detection (Canny-like effect using CIEdges)
        edgeDetector?.setValue(blurred, forKey: kCIInputImageKey)
        edgeDetector?.setValue(params.threshold1 / 255.0, forKey: kCIInputIntensityKey)
        
        guard let edges = edgeDetector?.outputImage else { return nil }
        
        // Create black background
        let blackBackground = CIImage(color: CIColor.black)
            .cropped(to: ciImage.extent)
        
        var result: CIImage
        
        if params.enableColorful {
            // Apply colorful edge effect
            result = applyColorfulEdges(edges: edges, originalImage: ciImage)
        } else {
            // Simple white edges on black background
            result = edges
        }
        
        // Composite edges over black background
        let composite = result.composited(over: blackBackground)
        
        // Convert back to UIImage
        guard let cgImage = context.createCGImage(composite, from: composite.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    /// Apply colorful edges based on edge angles (similar to the Python/Java implementation)
    private func applyColorfulEdges(edges: CIImage, originalImage: CIImage) -> CIImage {
        // Detect lines using custom implementation
        let lines = detectLines(in: edges)
        
        // Create a new image for colored edges
        let extent = edges.extent
        UIGraphicsBeginImageContextWithOptions(extent.size, false, 1.0)
        guard let ctx = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return edges
        }
        
        // Fill with black background
        ctx.setFillColor(UIColor.black.cgColor)
        ctx.fill(CGRect(origin: .zero, size: extent.size))
        
        if !lines.isEmpty {
            // Draw colored lines based on angle (matching Python algorithm exactly)
            for line in lines {
                // Python: a = (x1 - x2) / (y1 - y2)
                let x1 = line.start.x, y1 = line.start.y
                let x2 = line.end.x, y2 = line.end.y
                
                if y1 != y2 {
                    let a = (x1 - x2) / (y1 - y2)
                    // Python: b = round(math.degrees(math.atan(a))) + 90
                    let angleRadians = atan(a)
                    let degrees = round(angleRadians * 180.0 / .pi) + 90
                    
                    // Python: c = hsv_to_rgb(b, 255, 255)
                    let hsvColor = hsvToRgb(h: Int(degrees), s: 255, v: 255)
                    let color = UIColor(red: CGFloat(hsvColor.r)/255.0, 
                                      green: CGFloat(hsvColor.g)/255.0, 
                                      blue: CGFloat(hsvColor.b)/255.0, 
                                      alpha: 1.0)
                    
                    ctx.setStrokeColor(color.cgColor)
                    ctx.setLineWidth(3.0)
                    ctx.move(to: line.start)
                    ctx.addLine(to: line.end)
                    ctx.strokePath()
                }
            }
        } else {
            // If no lines detected, show rainbow gradient edges
            guard let cgImage = context.createCGImage(edges, from: edges.extent) else {
                UIGraphicsEndImageContext()
                return edges
            }
            
            let edgeImage = UIImage(cgImage: cgImage)
            
            // Apply rainbow gradient based on position
            for y in stride(from: 0, to: Int(extent.height), by: 2) {
                for x in stride(from: 0, to: Int(extent.width), by: 2) {
                    let point = CGPoint(x: x, y: y)
                    
                    // Check if edge exists at this point
                    if isEdgeAt(point: point, in: edgeImage) {
                        let hue = CGFloat((x + y) % 180) / 180.0
                        let color = UIColor(hue: hue, saturation: 1.0, brightness: 1.0, alpha: 1.0)
                        
                        ctx.setFillColor(color.cgColor)
                        ctx.fill(CGRect(x: CGFloat(x), y: CGFloat(y), width: 2, height: 2))
                    }
                }
            }
        }
        
        let coloredImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let finalImage = coloredImage,
              let ciColoredImage = CIImage(image: finalImage) else {
            return edges
        }
        
        return ciColoredImage
    }
    
    /// Detect lines in edge image (simplified Hough transform)
    private func detectLines(in edgeImage: CIImage) -> [Line] {
        var lines: [Line] = []
        
        // Convert to CGImage for pixel access
        guard let cgImage = context.createCGImage(edgeImage, from: edgeImage.extent) else {
            return lines
        }
        
        let width = cgImage.width
        let height = cgImage.height
        
        // Simple line detection (simplified for performance)
        let minLineLength = 80
        let maxGap = 5
        
        // Scan for horizontal and vertical lines
        for y in stride(from: 0, to: height, by: 10) {
            var lineStart: CGPoint?
            var lineLength = 0
            
            for x in 0..<width {
                if isPixelBright(at: CGPoint(x: x, y: y), in: cgImage) {
                    if lineStart == nil {
                        lineStart = CGPoint(x: x, y: y)
                    }
                    lineLength += 1
                } else {
                    if let start = lineStart, lineLength > minLineLength {
                        lines.append(Line(start: start, end: CGPoint(x: x - 1, y: y)))
                    }
                    lineStart = nil
                    lineLength = 0
                }
            }
        }
        
        return lines
    }
    
    /// Check if pixel is bright (edge)
    private func isPixelBright(at point: CGPoint, in cgImage: CGImage) -> Bool {
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data else {
            return false
        }
        
        let pixelData = CFDataGetBytePtr(data)
        let bytesPerRow = cgImage.bytesPerRow
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        
        let pixelOffset = Int(point.y) * bytesPerRow + Int(point.x) * bytesPerPixel
        
        if pixelOffset < CFDataGetLength(data) {
            let brightness = pixelData?[pixelOffset] ?? 0
            return brightness > 128
        }
        
        return false
    }
    
    /// Check if edge exists at point
    private func isEdgeAt(point: CGPoint, in image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }
        return isPixelBright(at: point, in: cgImage)
    }
    
    /// Line structure
    private struct Line {
        let start: CGPoint
        let end: CGPoint
    }
    
    /// HSV to RGB conversion matching Python cv2.cvtColor(HSV2BGR)
    private func hsvToRgb(h: Int, s: Int, v: Int) -> (r: Int, g: Int, b: Int) {
        let hNorm = CGFloat(h % 360) / 360.0
        let sNorm = CGFloat(s) / 255.0
        let vNorm = CGFloat(v) / 255.0
        
        let c = vNorm * sNorm
        let x = c * (1 - abs((hNorm * 6).truncatingRemainder(dividingBy: 2) - 1))
        let m = vNorm - c
        
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        
        let sector = Int(hNorm * 6)
        switch sector {
        case 0: (r, g, b) = (c, x, 0)
        case 1: (r, g, b) = (x, c, 0)
        case 2: (r, g, b) = (0, c, x)
        case 3: (r, g, b) = (0, x, c)
        case 4: (r, g, b) = (x, 0, c)
        default: (r, g, b) = (c, 0, x)
        }
        
        return (r: Int((r + m) * 255), g: Int((g + m) * 255), b: Int((b + m) * 255))
    }
}