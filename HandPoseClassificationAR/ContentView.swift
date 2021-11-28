//
//  ContentView.swift
//  HandPoseClassificationAR
//
//  Created by 間嶋大輔 on 2021/11/27.
//

import SwiftUI
import RealityKit

struct ContentView : View {
    var body: some View {
        return ARViewControllerContainer().edgesIgnoringSafeArea(.all)
    }
}

struct ARViewControllerContainer: UIViewControllerRepresentable {
        
    func makeUIViewController(context: UIViewControllerRepresentableContext<ARViewControllerContainer>) -> ARViewController {
        let viewController = ARViewController()
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: ARViewController, context: UIViewControllerRepresentableContext<ARViewControllerContainer>) {
        
    }
    
    func makeCoordinator() -> ARViewControllerContainer.Coordinator {
        return Coordinator()
    }
    
    class Coordinator: NSObject {
        
    }
}

#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
