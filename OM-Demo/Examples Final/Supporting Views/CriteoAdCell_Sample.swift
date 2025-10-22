//
//  CriteoAdCell_Sample.swift
//  OM-Demo
//
//  Created by Serxhio Gugo on 8/26/25.
//  Copyright © 2025 Open Measurement Working Group. All rights reserved.
//

import UIKit

#if canImport(OMSDK_Criteo)
import OMSDK_Criteo
#endif

/// Clean table view cell that properly uses CriteoVideoAdWrapper
/// No business logic - just UI and delegation to wrapper
class CriteoAdCell_Sample: UITableViewCell {

    // MARK: - Properties

    private var videoWrapper: CriteoVideoAdWrapper?

    // UI Elements
    private let containerView = UIView()
    private let headerLabel = UILabel()
    private let videoContainerView = UIView()
    private let footerLabel = UILabel()

    // MARK: - Initialization

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear

        setupContainerView()
        setupHeaderLabel()
        setupVideoContainer()
        setupFooterLabel()
        setupConstraints()
    }

    private func setupContainerView() {
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 12
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.1
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowRadius = 4

        contentView.addSubview(containerView)
    }

    private func setupHeaderLabel() {
        headerLabel.text = "Sponsored Video Ad"
        headerLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        headerLabel.textColor = .secondaryLabel
        headerLabel.textAlignment = .left

        containerView.addSubview(headerLabel)
    }

    private func setupVideoContainer() {
        videoContainerView.backgroundColor = .systemGray6
        videoContainerView.layer.cornerRadius = 8
        videoContainerView.clipsToBounds = true

        containerView.addSubview(videoContainerView)
    }

    private func setupFooterLabel() {
        footerLabel.text = "Tap the video to interact or learn more about our products"
        footerLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        footerLabel.textColor = .label
        footerLabel.numberOfLines = 2
        footerLabel.textAlignment = .left

        containerView.addSubview(footerLabel)
    }

    private func setupConstraints() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        videoContainerView.translatesAutoresizingMaskIntoConstraints = false
        footerLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            // Container view
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            // Header label
            headerLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            headerLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            headerLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

            // Video container (16:9 aspect ratio)
            videoContainerView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 12),
            videoContainerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            videoContainerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            videoContainerView.heightAnchor.constraint(equalTo: videoContainerView.widthAnchor, multiplier: 9.0/16.0),

            // Footer label
            footerLabel.topAnchor.constraint(equalTo: videoContainerView.bottomAnchor, constant: 12),
            footerLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            footerLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            footerLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])
    }

    // MARK: - Configuration

    /// Configure cell with a video ad wrapper
    /// This is the ONLY method that should be called - no business logic here!
    func configure(with wrapper: CriteoVideoAdWrapper?) {
        // Remove previous wrapper if any
        if let previousWrapper = videoWrapper {
            previousWrapper.removeFromSuperview()
        }

        // Store new wrapper reference
        videoWrapper = wrapper

        // Add wrapper to video container if it exists
        if let wrapper = wrapper {
            // Remove from any existing superview first
            wrapper.removeFromSuperview()

            // Ensure wrapper is visible
            wrapper.alpha = 1.0
            wrapper.isHidden = false

            // Add to our video container
            videoContainerView.addSubview(wrapper)

            // Set up constraints to fill the video container
            wrapper.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                wrapper.topAnchor.constraint(equalTo: videoContainerView.topAnchor),
                wrapper.leadingAnchor.constraint(equalTo: videoContainerView.leadingAnchor),
                wrapper.trailingAnchor.constraint(equalTo: videoContainerView.trailingAnchor),
                wrapper.bottomAnchor.constraint(equalTo: videoContainerView.bottomAnchor)
            ])

            // Bring wrapper to front to ensure it's visible
            videoContainerView.bringSubviewToFront(wrapper)

            CriteoLogger.debug("📱 Configured cell with video wrapper", category: .ui)
        } else {
            CriteoLogger.debug("📱 Configured cell with no video wrapper", category: .ui)
        }
    }

    // MARK: - Cleanup

    override func prepareForReuse() {
        super.prepareForReuse()

        // The wrapper is managed by the table view controller
        // We don't clean it up here - just remove from superview
        if let wrapper = videoWrapper {
            wrapper.removeFromSuperview()
            // Don't set to nil - let the controller manage the wrapper lifecycle
        }

        CriteoLogger.debug("♻️ Video ad cell prepared for reuse", category: .ui)
    }

    deinit {
        // Wrapper cleanup is handled by the table view controller
        CriteoLogger.debug("🗑️ Video ad cell deallocated", category: .ui)
    }
}