import UIKit

final class DailyWeatherCell: UICollectionViewCell {
    static let reuseID = "DailyWeatherCell"

    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let dayLabel = UILabel()
    private let iconView = UIImageView()
    private let minMaxLabel = UILabel()
    private let rainLabel = UILabel()

    private var iconURL: URL?

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.layer.cornerCurve = .continuous
        contentView.layer.cornerRadius = 18
        contentView.layer.masksToBounds = true

        contentView.addSubview(blur)
        blur.translatesAutoresizingMaskIntoConstraints = false

        dayLabel.font = .preferredFont(forTextStyle: .headline)
        dayLabel.textColor = .label

        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        minMaxLabel.font = .preferredFont(forTextStyle: .subheadline)
        minMaxLabel.textColor = .secondaryLabel
        minMaxLabel.textAlignment = .right

        rainLabel.font = .preferredFont(forTextStyle: .caption1)
        rainLabel.textColor = .tertiaryLabel
        rainLabel.textAlignment = .right

        let rightStack = UIStackView(arrangedSubviews: [minMaxLabel, rainLabel])
        rightStack.axis = .vertical
        rightStack.alignment = .trailing
        rightStack.spacing = 2
        rightStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(dayLabel)
        contentView.addSubview(iconView)
        contentView.addSubview(rightStack)

        dayLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: contentView.topAnchor),
            blur.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            dayLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            dayLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 34),
            iconView.heightAnchor.constraint(equalToConstant: 34),

            rightStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            rightStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            rightStack.leadingAnchor.constraint(greaterThanOrEqualTo: iconView.trailingAnchor, constant: 10)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.image = nil
        iconURL = nil
    }

    func render(model: DayModel) {
        dayLabel.text = Self.dayString(epoch: model.dateEpoch)
        minMaxLabel.text = "\(Int(model.minTempC.rounded()))°  /  \(Int(model.maxTempC.rounded()))°"
        if let rain = model.chanceOfRain {
            rainLabel.text = "Осадки \(rain)%"
            rainLabel.isHidden = false
        } else {
            rainLabel.isHidden = true
        }
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

    private static func dayString(epoch: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(epoch))
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "EEE, d MMM"
        return f.string(from: date).capitalized
    }
}

