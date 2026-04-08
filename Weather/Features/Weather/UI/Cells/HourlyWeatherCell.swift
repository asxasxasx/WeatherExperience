import UIKit

final class HourlyWeatherCell: UICollectionViewCell {
    static let reuseID = "HourlyWeatherCell"

    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let timeLabel = UILabel()
    private let iconView = UIImageView()
    private let tempLabel = UILabel()

    private var iconURL: URL?
    private var epoch: Int?

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.layer.cornerCurve = .continuous
        contentView.layer.cornerRadius = 18
        contentView.layer.masksToBounds = true

        contentView.addSubview(blur)
        blur.translatesAutoresizingMaskIntoConstraints = false

        timeLabel.font = .preferredFont(forTextStyle: .caption1)
        timeLabel.textColor = .secondaryLabel
        timeLabel.textAlignment = .center

        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        tempLabel.font = .preferredFont(forTextStyle: .headline)
        tempLabel.textColor = .label
        tempLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [timeLabel, iconView, tempLabel])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: contentView.topAnchor),
            blur.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),

            iconView.heightAnchor.constraint(equalToConstant: 38)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.image = nil
        iconURL = nil
        epoch = nil
    }

    func render(model: HourModel) {
        epoch = model.timeEpoch
        timeLabel.text = Self.hourString(epoch: model.timeEpoch)
        tempLabel.text = "\(Int(model.temperatureC.rounded()))°"
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

    private static func hourString(epoch: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(epoch))
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

