import SwiftUI
import ARKit
import SwiftUI
import RealityKit

struct ContentView : View {
    let arModel = ARModel()
    let patternModel = PatternModel()
    var body: some View {
        ZStack {
            RealityKitView(patternModel: patternModel, arModel: arModel).edgesIgnoringSafeArea(.all)
            OverlayView(patternModel: patternModel)
        }
    }
}

class ARModel: ObservableObject {
    @Published var anchor: AnchorEntity?
    @Published var pattern: ModelEntity?
    /** url of the pattern above (to see if it has changed) */
    @Published var patternUrl: URL?
}

protocol PatternVisualizer {
    mutating func addPlaneNode(for imageAnchor: ARImageAnchor)
}

struct RealityKitView: UIViewRepresentable, PatternVisualizer {
    @ObservedObject var patternModel: PatternModel
    @ObservedObject var arModel: ARModel

    let view: ARView =  ARView(frame: .zero)
    

    func makeCoordinator() -> Coordinator {
        Coordinator(delegate: self)
    }
    
    
    func makeUIView(context: Context) -> ARView {
        view.cameraMode = .ar
        view.automaticallyConfigureSession = false
        
        // Start AR session
        let session = view.session

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = []
        config.sceneReconstruction = .mesh

        guard let referenceImages = ARReferenceImage.referenceImages(
            inGroupNamed: "Anchors", bundle: nil) else {
            fatalError("Missing expected asset catalog resources.")
        }
        config.detectionImages = referenceImages
        config.maximumNumberOfTrackedImages = 1

        view.session.delegate = context.coordinator

        session.run(config, options: [.resetTracking, .removeExistingAnchors])


        // load default pattern
        if let image = UIImage(named: "DefaultPattern") {
            if let pattern = createPattern(image: image, width: 0.21, height: 0.297) {
                self.arModel.pattern = pattern
            }
        }

        if let url = Bundle.main.url(forResource: "DefaultPattern", withExtension: "pdf") {
            updatePattern(url: url)
        }

        #if DEBUG
        print("View is set up")
        #endif

        return view
    }
    
    
    class Coordinator: NSObject, ARSessionDelegate {
        var delegate: PatternVisualizer?
        
        init(delegate: PatternVisualizer) {
              self.delegate = delegate
        }
        
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            guard let imageAnchor = anchors.compactMap({ $0 as? ARImageAnchor }).first else {
                return
            }
            
            #if DEBUG
            print("Image Anchor detected")
            #endif

            // Add a plane node for this anchor
            DispatchQueue.main.async {
                self.delegate?.addPlaneNode(for: imageAnchor)
            }
        }
        func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
            #if DEBUG
            print("Number of Anchors removed \(anchors.count)")
            #endif
        }
    }

    func createPinhead() -> ModelEntity {
        let sphereMesh = MeshResource.generateSphere(radius: 0.0025)
        let material = SimpleMaterial(color: SimpleMaterial.Color.green, isMetallic: false)
        return ModelEntity(mesh: sphereMesh, materials: [material])
    }

    func annotateAnchor(width: Float, height: Float, show3d: Bool) -> ModelEntity {
        let m = ModelEntity()
        
        let left = createPinhead()
        left.position.x = width / -2
        m.addChild(left)

        let right = createPinhead()
        right.position.x = width / 2
        m.addChild(right)
        
        let top = createPinhead()
        top.position.z = height / -2
        m.addChild(top)
        
        let bottom = createPinhead()
        bottom.position.z = height / 2
        m.addChild(bottom)
        
        let overlayMesh = MeshResource.generatePlane(width: width, height: height, cornerRadius: width/20)
        let material = SimpleMaterial(color: .white.withAlphaComponent(0.9), isMetallic: false)
        let overlay = ModelEntity(mesh: overlayMesh, materials: [material])
        overlay.transform.rotation = simd_quatf(angle: -Float.pi / 2, axis: [1, 0, 0])
        m.addChild(overlay)

        m.position.y = -0.001 // move back a bit so it won't obstruct the pattern
        return m
    }

    func loadPdf(url: URL) -> (image: UIImage, widthInM: Float, heightInM: Float)? {
        guard let pdf = CGPDFDocument(url as CFURL) else { return nil }
        guard let page = pdf.page(at: 1) else { return nil }
        let pageRect = page.getBoxRect(.mediaBox)
        let w = 1500.0
        let h = w*pageRect.height/pageRect.width
        let scale = w / pageRect.width
        let size = CGSize(width: w, height: h)
        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { ctx in
            ctx.cgContext.saveGState()
            ctx.cgContext.translateBy(x: 0.0, y: h)
            ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
            ctx.cgContext.scaleBy(x: scale, y: scale)
            ctx.cgContext.drawPDFPage(page)
            ctx.cgContext.restoreGState()
        }
        let dpi = 72.0
        let dpm = dpi/2.54*100
        let widthInM = Float(pageRect.width/dpm)
        let heightInM = Float(pageRect.height/dpm)
        #if DEBUG
        print("Size of pattern is \(widthInM)m x \(heightInM)m")
        #endif
        return (image, widthInM, heightInM)
    }
    func createPattern(image: UIImage, width: Float, height: Float) -> ModelEntity? {
        guard let cgImage = image.cgImage else { return nil }
        let options = TextureResource.CreateOptions.init(semantic: .normal)
        guard let texture = try? TextureResource.generate(from: cgImage, options: options) else { return nil }
        let plane = MeshResource.generatePlane(width: width, height: height)

        let color = MaterialParameters.Texture(texture)
        var material = PhysicallyBasedMaterial()
        material.blending = .transparent(opacity: 0.01)
        material.opacityThreshold = 0.1
        material.baseColor =  PhysicallyBasedMaterial.BaseColor(texture:color)
        let entity = ModelEntity(mesh: plane, materials: [material])
        entity.transform.rotation = simd_quatf(angle: -Float.pi / 2, axis: [1, 0, 0])
        return entity
    }
    
    func updatePattern(url: URL) {
        #if DEBUG
        print("Loading new pattern \(url)")
        #endif

        if let anchor = self.arModel.anchor {
            if let oldPattern = self.arModel.pattern {
                #if DEBUG
                print("Removing old pattern")
                #endif
                anchor.removeChild(oldPattern)
            }
        }

        guard let (image, width, height) = loadPdf(url: url) else { return }
        guard let pattern = createPattern(image: image, width: width, height: height) else { return }
        self.arModel.patternUrl = url
        self.arModel.pattern = pattern
        
        guard let anchor = self.arModel.anchor else { return }
        anchor.addChild(pattern)
    }
       
    mutating func addPlaneNode(for imageAnchor: ARImageAnchor) {
        if let priorAnchor = self.arModel.anchor {
            view.scene.removeAnchor(priorAnchor)
        }
        let anchor = AnchorEntity.init(anchor: imageAnchor)

        let annotation = annotateAnchor(width: Float(imageAnchor.referenceImage.physicalSize.width),
                                        height: Float(imageAnchor.referenceImage.physicalSize.height),
                                        show3d: false)
        anchor.addChild(annotation)

        if let pattern = self.arModel.pattern {
            pattern.position.x = patternModel.positionX
            pattern.position.z = patternModel.positionY
            anchor.addChild(pattern)
        }


        view.scene.addAnchor(anchor)

        self.arModel.anchor = anchor
    }
    
    
    func updateUIView(_ view: ARView, context: Context) {
        DispatchQueue.main.async {
            if let url = self.patternModel.patternUrl {
                if let oldUrl = self.arModel.patternUrl {
                    if (url != oldUrl) {
                        updatePattern(url: url)
                    }
                } else {
                    updatePattern(url: url)
                }
            }

            if let pattern = self.arModel.pattern {
                pattern.position.x = patternModel.positionX
                pattern.position.z = patternModel.positionY
            }
        }
    }

}
