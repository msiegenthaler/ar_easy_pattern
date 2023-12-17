import SwiftUI


struct OverlayView: View {
    @ObservedObject var patternModel: PatternModel

    private let step: Float = 0.05;

    private let buttonSize: CGFloat = 30
    private let pad: CGFloat = 10

    var body: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom) {
                VStack(alignment: .center) {
                    Button {
                        patternModel.positionY = patternModel.positionY - step
                    }label: {
                        Label("Up", systemImage: "chevron.up.circle")
                            .labelStyle(.iconOnly)
                            .imageScale(.large)
                            .font(.system(size: buttonSize))
                            .padding()
                    }.frame(width: buttonSize+pad, height: buttonSize+pad)
                    HStack {
                        Button {
                            patternModel.positionX = patternModel.positionX - step
                        }label: {
                            Label("Left", systemImage: "chevron.left.circle")
                                .labelStyle(.iconOnly)
                                .imageScale(.large)
                                .font(.system(size: buttonSize))
                                .padding()
                        }.frame(width: buttonSize+pad, height: buttonSize+pad)
                        Spacer()
                        Button {
                            patternModel.positionX = patternModel.positionX + step
                        }label: {
                            Label("Right", systemImage: "chevron.right.circle")
                                .labelStyle(.iconOnly)
                                .imageScale(.large)
                                .font(.system(size: buttonSize))
                                .padding()
                        }.frame(width: buttonSize+pad, height: buttonSize+pad)
                    }.frame(maxHeight: 0)
                    Button {
                        patternModel.positionY = patternModel.positionY + step
                    }label: {
                        Label("Down", systemImage: "chevron.down.circle")
                            .labelStyle(.iconOnly)
                            .imageScale(.large)
                            .font(.system(size: buttonSize))
                            .padding()
                    }.frame(width: buttonSize+pad, height: buttonSize+pad)
                }.frame(width: 100)
                Spacer().frame(idealWidth: .infinity)
            }.padding()
        }
    }
}

#Preview {
    OverlayView(patternModel: PatternModel())
}
