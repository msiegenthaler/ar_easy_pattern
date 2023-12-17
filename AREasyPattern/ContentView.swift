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
            print("Anchor detected")
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
    
    func createPattern(name: String, width: Float, height: Float) -> ModelEntity {
        let texture = try! TextureResource.load(named: name)
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
       
    mutating func addPlaneNode(for imageAnchor: ARImageAnchor) {
        if let priorAnchor = self.arModel.anchor {
            view.scene.removeAnchor(priorAnchor)
        }
        let anchor = AnchorEntity.init(anchor: imageAnchor)

        let annotation = annotateAnchor(width: Float(imageAnchor.referenceImage.physicalSize.width),
                                        height: Float(imageAnchor.referenceImage.physicalSize.height),
                                        show3d: false)
        anchor.addChild(annotation)

        //let pattern = createPattern(name: "Softshell", width: 0.841, height: 1.189) // the PDF in A0
        let pattern = createPattern(name: "Wickelkragen", width: 1.7251, height: 0.9803) // the PDF size
        pattern.position.x = patternModel.positionX
        pattern.position.z = patternModel.positionY
        self.arModel.pattern = pattern

        anchor.addChild(pattern)

        view.scene.addAnchor(anchor)

        self.arModel.anchor = anchor
    }
    
    
    func updateUIView(_ view: ARView, context: Context) {
        DispatchQueue.main.async {
            if let pattern = self.arModel.pattern {
                pattern.position.x = patternModel.positionX
                pattern.position.z = patternModel.positionY
            }
        }
    }

}
