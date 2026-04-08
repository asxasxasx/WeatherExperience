import UIKit

final class CurrentWeatherCell: UICollectionViewCell {
    static let reuseID = "CurrentWeatherCell"

    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let iconView = UIImageView()
    private let placeLabel = UILabel()
    private let tempLabel = UILabel()
    private let condLabel = UILabel()
    private let metaLabel = UILabel()

    private var iconURL: URL?

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.layer.cornerCurve = .continuous
        contentView.layer.cornerRadius = 22
        contentView.layer.masksToBounds = true
        
        blur.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(blur)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        placeLabel.translatesAutoresizingMaskIntoConstraints = false
        tempLabel.translatesAutoresizingMaskIntoConstraints = false
        condLabel.translatesAutoresizingMaskIntoConstraints = false
        metaLabel.translatesAutoresizingMaskIntoConstraints = false

        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .label

        placeLabel.font = .preferredFont(forTextStyle: .headline)
        placeLabel.textColor = .label

        tempLabel.font = .systemFont(ofSize: 64, weight: .semibold)
        tempLabel.textColor = .label
        tempLabel.adjustsFontSizeToFitWidth = true
        tempLabel.minimumScaleFactor = 0.7

        condLabel.font = .preferredFont(forTextStyle: .subheadline)
        condLabel.textColor = .secondaryLabel

        metaLabel.font = .preferredFont(forTextStyle: .footnote)
        metaLabel.textColor = .secondaryLabel
        metaLabel.numberOfLines = 2

        let vStack = UIStackView(arrangedSubviews: [placeLabel, tempLabel, condLabel, metaLabel])
        vStack.axis = .vertical
        vStack.alignment = .leading
        vStack.spacing = 4
        vStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(iconView)
        contentView.addSubview(vStack)

        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: contentView.topAnchor),
            blur.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            iconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            iconView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            iconView.widthAnchor.constraint(equalToConstant: 54),
            iconView.heightAnchor.constraint(equalToConstant: 54),

            vStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            vStack.trailingAnchor.constraint(lessThanOrEqualTo: iconView.leadingAnchor, constant: -12),
            vStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            vStack.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 16)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.image = nil
        iconURL = nil
    }

    func render(model: CurrentModel, placeName: String) {
        placeLabel.text = placeName
        tempLabel.text = "\(Int(model.temperatureC.rounded()))°"
        condLabel.text = model.conditionText
        metaLabel.text = "Ощущается \(Int(model.feelsLikeC.rounded()))° · Ветер \(Int(model.windKph.rounded())) км/ч · Влажн. \(model.humidity)%"
        iconURL = model.conditionIconURL
    }

    func loadIcon(using loader: any ImageLoading) async {
        guard let url = iconURL else { return }
        if let image = await loader.image(for: url) {
            await MainActor.run { [weak self] in
                guard let self, self.iconURL == url else { return }
                self.iconView.image = image
            }
        }
    }
}

