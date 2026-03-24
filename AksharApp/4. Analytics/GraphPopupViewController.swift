import UIKit
import SwiftUI

class GraphPopupViewController: UIViewController {

    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var graphContinerView: UIView!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet var backgroundView: UIView!

    private var hostingController: UIHostingController<AccuracyLineChartView>?

    var graphTitle: String = ""
    var graphData: [AccuracyPoint] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        containerView.layer.cornerRadius = 20
        embedChart()
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.gray.cgColor
        containerView.bringSubviewToFront(closeButton)
    }

    private func embedChart() {
        let chartView = AccuracyLineChartView(
            title: graphTitle,
            data: graphData
        )

        let host = UIHostingController(rootView: chartView)
        hostingController = host

        addChild(host)
        host.view.backgroundColor = .clear
        
        host.view.translatesAutoresizingMaskIntoConstraints = false
        
        graphContinerView.addSubview(host.view)

        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: graphContinerView.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: graphContinerView.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: graphContinerView.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: graphContinerView.trailingAnchor)
        ])

        host.didMove(toParent: self)
    }

    @IBAction func closeTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }

}



    

