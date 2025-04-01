import UIKit

class BattleCategoryCell: UICollectionViewCell {
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray6
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let categoryLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .black
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .primaryPurple
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(containerView)
        containerView.addSubview(iconImageView)
        containerView.addSubview(categoryLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            iconImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 32),
            iconImageView.heightAnchor.constraint(equalToConstant: 32),
            
            categoryLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 8),
            categoryLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            categoryLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            categoryLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])
    }
    
    func configure(with category: String, isSelected: Bool) {
        categoryLabel.text = category
        
        if let quizCategory = QuizCategory(rawValue: category) {
            iconImageView.image = UIImage(systemName: quizCategory.iconName)
        } else {
            iconImageView.image = UIImage(systemName: "questionmark.circle")
        }
        
        if isSelected {
            containerView.backgroundColor = .primaryPurple.withAlphaComponent(0.2)
            containerView.layer.borderWidth = 2
            containerView.layer.borderColor = UIColor.primaryPurple.cgColor
            iconImageView.tintColor = .primaryPurple
            categoryLabel.textColor = .primaryPurple
        } else {
            containerView.backgroundColor = .systemGray6
            containerView.layer.borderWidth = 0
            iconImageView.tintColor = .systemGray
            categoryLabel.textColor = .black
        }
    }
} 