//
//  AdListViewController.swift
//  OM-TestApp
//
//  Created by Alex Chugunov on 9/24/17.
//

import UIKit
import SwiftUI

#if canImport(OMSDK_Criteo)
import OMSDK_Criteo
#endif

/**
 Presents the user with the list of available ad units in a table view.
 Tapping on a table view cell opens a view controller that handles selected ad unit.
 */
class AdListViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Register the basic cell class since we removed the storyboard
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "listCell")

        title = "Video Ad Examples"
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 4
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "listCell", for: indexPath)

        // Configure cell appearance (similar to storyboard)
        cell.accessoryType = .disclosureIndicator
        cell.textLabel?.font = UIFont.systemFont(ofSize: 17)

        switch indexPath.row {
        case 0:
            cell.textLabel?.text = "Fetch VAST XML (parses XML in the console)"
        case 1:
            cell.textLabel?.text = "Single Video Controller (UIKit)"
        case 2:
            cell.textLabel?.text = "TableView Video Controller (UIKit)"
        case 3:
            cell.textLabel?.text = "ListView Feed (SwiftUI)"
        default:
            cell.textLabel?.text = "Unknown"
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.row {
        case 0:
            self.parseVast()
        case 1:
            showSingleVideoController()
        case 2:
            showNewTableViewController()
        case 3:
            showSwiftUIListView()
        default:
            performSegue(withIdentifier:"showVideo", sender: self)
        }
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    private func parseVast() {
        let urlString = Constants.vastURL
        guard let url = URL(string: urlString) else { return }
        
        Task {
            do {
                let ad = try await NetworkManager.shared.fetchAndParseVAST(from: url)
                print("Video URL: \(ad.videoURL!)")
                print("Duration: \(ad.duration ?? "none")")
                print("Impressions: \(ad.impressionURLs)")
                print("Error URLs: \(ad.errorURLs)")
                print("Tracking: \(ad.trackingEvents)")
                print("ClickTracking: \(ad.clickTrackingURLs)")
                print("Click through URL: \(ad.clickThroughURL ?? URL(string: "No clickThroughURL present")!)")
                print("Captions: \(ad.closedCaptionURL ?? URL(string: "No closedCaptionURL present")!)")
                print("Verification JS: \(ad.verificationScriptURL ?? URL(string: "No verificationScriptURL present")!)")
                print("Verification Parameters: \(ad.verificationParameters ?? "none")")
                print("Verification Tracking: \(ad.verificationTracking)")
                print("VENDOR KEY: \(ad.vendorKey ?? "No vendor key present")")
            } catch {
                print("VAST error: \(error.localizedDescription)")

            }
        }
    }
    
    private func showSingleVideoController() {
        let vc = CriteoAdSingleVideoController_Sample()
        vc.title = "CriteoAdSingleVideoController_Sample"
        navigationController?.pushViewController(vc, animated: true)
    }

    private func showNewTableViewController() {
        let vc = CriteoAdTableViewController_Sample()
        vc.title = "CriteoAdTableViewController_Sample"
        navigationController?.pushViewController(vc, animated: true)
    }

    private func showSwiftUIListView() {
        let swiftUIView = CriteoAdSwiftUIListView_Sample()
        let hostingController = UIHostingController(rootView: swiftUIView)
        hostingController.title = "CriteoAdSwiftUIListView_Sample"
        navigationController?.pushViewController(hostingController, animated: true)
    }
}
