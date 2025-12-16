//
//  UploadsCollectionViewCell.swift
//  AksharOCR
//
//  Created by SDC-USER on 12/12/25.
//

import UIKit

class UploadsCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var containerView: UIView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        containerView.layer.cornerRadius = 12
        containerView.layer.masksToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true

        // label settings
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.textAlignment = .left
        titleLabel.adjustsFontSizeToFitWidth = false
    }

    // Helper to configure cell
    func configure(title: String, dateText: String, image: UIImage?) {
        titleLabel.text = title
        dateLabel.text = dateText
        imageView.image = image
    }
}
