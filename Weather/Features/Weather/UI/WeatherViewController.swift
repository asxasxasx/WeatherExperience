import UIKit

final class WeatherViewController: UIViewController {
    enum Section: Int, CaseIterable {
        case current
        case hourly
        case daily
    }

    struct Item: Hashable {
        enum Kind {
            case current(CurrentModel, placeName: String)
            case hour(HourModel)
            case day(DayModel)
        }
        let id: UUID
        let kind: Kind

        init(_ kind: Kind) {
            self.id = UUID()
            self.kind = kind
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: Item, rhs: Item) -> Bool {
            lhs.id == rhs.id
        }
    }

    static func make() -> UIViewController {
        let api = WeatherAPIClient(http: URLSessionHTTPClient())
        let repo = WeatherRepository(api: api, cache: JSONDiskCache())
        let vm = WeatherViewModel(location: LocationService(), repository: repo)
        return WeatherViewController(viewModel: vm, imageLoader: ImageLoader())
    }

    private let viewModel: WeatherViewModel
    private let imageLoader: any ImageLoading

    private let backgroundView = GradientBackgroundView()
    private let collectionView: UICollectionView
    private let loadingView = LoadingOverlayView()
    private let errorView = ErrorOverlayView()

    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!

    init(viewModel: WeatherViewModel, imageLoader: any ImageLoading) {
        self.viewModel = viewModel
        self.imageLoader = imageLoader
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: Self.makeLayout())
        super.init(nibName: nil, bundle: nil)
        self.title = "Погода"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        view.addSubview(backgroundView)
        view.addSubview(collectionView)
        view.addSubview(loadingView)
        view.addSubview(errorView)

        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        errorView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            loadingView.topAnchor.constraint(equalTo: view.topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            errorView.topAnchor.constraint(equalTo: view.topAnchor),
            errorView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            errorView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.contentInset = .zero

        configureNavBar()
        configureCollection()
        configureOverlays()
        bind()

        viewModel.onAppear()
    }

    private func configureNavBar() {
        navigationController?.navigationBar.prefersLargeTitles = true
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
    }

    private func configureCollection() {
        collectionView.register(CurrentWeatherCell.self, forCellWithReuseIdentifier: CurrentWeatherCell.reuseID)
        collectionView.register(HourlyWeatherCell.self, forCellWithReuseIdentifier: HourlyWeatherCell.reuseID)
        collectionView.register(DailyWeatherCell.self, forCellWithReuseIdentifier: DailyWeatherCell.reuseID)

        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { [weak self] collectionView, indexPath, item in
            guard let self else { return UICollectionViewCell() }
            switch item.kind {
            case .current(let model, let placeName):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CurrentWeatherCell.reuseID, for: indexPath) as! CurrentWeatherCell
                cell.render(model: model, placeName: placeName)
                Task { await cell.loadIcon(using: self.imageLoader) }
                return cell
            case .hour(let model):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: HourlyWeatherCell.reuseID, for: indexPath) as! HourlyWeatherCell
                cell.render(model: model)
                Task { await cell.loadIcon(using: self.imageLoader) }
                return cell
            case .day(let model):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DailyWeatherCell.reuseID, for: indexPath) as! DailyWeatherCell
                cell.render(model: model)
                Task { await cell.loadIcon(using: self.imageLoader) }
                return cell
            }
        }
    }

    private func configureOverlays() {
        loadingView.isHidden = true
        errorView.isHidden = true
        errorView.onRetry = { [weak self] in self?.viewModel.retry() }
    }

    private func bind() {
        viewModel.onStateChange = { [weak self] state in
            guard let self else { return }
            switch state {
            case .loading:
                self.loadingView.isHidden = false
                self.errorView.isHidden = true
            case .failed(let message):
                self.loadingView.isHidden = true
                self.errorView.isHidden = false
                self.errorView.render(message: message)
            case .content(let model):
                self.loadingView.isHidden = true
                self.errorView.isHidden = true
                self.apply(model: model)
                self.backgroundView.render(isDay: model.now.isDay)
            }
        }
    }

    private func apply(model: WeatherScreenModel) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections(Section.allCases)

        snapshot.appendItems([Item(.current(model.now, placeName: model.placeName))], toSection: .current)
        snapshot.appendItems(model.hourly.map { Item(.hour($0)) }, toSection: .hourly)
        snapshot.appendItems(model.daily.map { Item(.day($0)) }, toSection: .daily)

        dataSource.apply(snapshot, animatingDifferences: true)
    }

    private static func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { sectionIndex, environment in
            guard let section = Section(rawValue: sectionIndex) else { return nil }

            let horizontalInset: CGFloat = 16

            switch section {

            // MARK: - CURRENT
            case .current:
                let item = NSCollectionLayoutItem(
                    layoutSize: .init(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .fractionalHeight(1)
                    )
                )

                let group = NSCollectionLayoutGroup.vertical(
                    layoutSize: .init(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .absolute(200)
                    ),
                    subitems: [item]
                )

                let section = NSCollectionLayoutSection(group: group)

                section.contentInsets = .init(
                    top: 8,
                    leading: horizontalInset,
                    bottom: 16,
                    trailing: horizontalInset
                )

                return section

            // MARK: - HOURLY
            case .hourly:
                let item = NSCollectionLayoutItem(
                    layoutSize: .init(
                        widthDimension: .absolute(72),
                        heightDimension: .absolute(110)
                    )
                )

                item.contentInsets = .init(
                    top: 0,
                    leading: 4,
                    bottom: 0,
                    trailing: 4
                )

                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: .init(
                        widthDimension: .estimated(72),
                        heightDimension: .absolute(110)
                    ),
                    subitems: [item]
                )

                let section = NSCollectionLayoutSection(group: group)

                section.orthogonalScrollingBehavior = .continuousGroupLeadingBoundary

                section.interGroupSpacing = 8

                section.contentInsets = .init(
                    top: 0,
                    leading: horizontalInset,
                    bottom: 20,
                    trailing: horizontalInset
                )

                return section

            // MARK: - DAILY
            case .daily:
                let item = NSCollectionLayoutItem(
                    layoutSize: .init(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .absolute(72)
                    )
                )

                item.contentInsets = .init(
                    top: 4,
                    leading: 0,
                    bottom: 4,
                    trailing: 0
                )

                let group = NSCollectionLayoutGroup.vertical(
                    layoutSize: .init(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .estimated(300)
                    ),
                    subitems: [item]
                )

                let section = NSCollectionLayoutSection(group: group)

                section.interGroupSpacing = 8

                section.contentInsets = .init(
                    top: 0,
                    leading: horizontalInset,
                    bottom: 20,
                    trailing: horizontalInset
                )

                return section
            }
        }
    }

    private static func makeLayout111() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { sectionIndex, environment in
            guard let section = Section(rawValue: sectionIndex) else { return nil }

            switch section {
            case .current:
                let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1)))
                let group = NSCollectionLayoutGroup.vertical(
                    layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(190)),
                    subitems: [item]
                )
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = .init(top: 0, leading: 0, bottom: 12, trailing: 0)
                return section

            case .hourly:
                let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .absolute(72), heightDimension: .absolute(112)))
                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(112)),
                    subitems: [item]
                )
                group.interItemSpacing = .fixed(10)
                let section = NSCollectionLayoutSection(group: group)
                section.orthogonalScrollingBehavior = .continuous
//                section.contentInsets = .init(top: 0, leading: 0, bottom: 14, trailing: 0)
                section.contentInsets = NSDirectionalEdgeInsets(
                    top: 8,
                    leading: 16,
                    bottom: 24,
                    trailing: 16
                )
                return section

            case .daily:
                let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(64)))
                let group = NSCollectionLayoutGroup.vertical(
                    layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(64 * 3)),
                    subitems: [item]
                )
                group.interItemSpacing = .fixed(10)
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = .init(top: 0, leading: 0, bottom: 0, trailing: 20)
                return section
            }
        }
    }
}

private final class GradientBackgroundView: UIView {
    private let layer1 = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer1.startPoint = CGPoint(x: 0, y: 0)
        layer1.endPoint = CGPoint(x: 1, y: 1)
        layer.addSublayer(layer1)
        render(isDay: true)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer1.frame = bounds
    }

    func render(isDay: Bool) {
        if isDay {
            layer1.colors = [
                UIColor(red: 0.27, green: 0.56, blue: 0.98, alpha: 1).cgColor,
                UIColor(red: 0.58, green: 0.82, blue: 0.99, alpha: 1).cgColor
            ]
        } else {
            layer1.colors = [
                UIColor(red: 0.07, green: 0.10, blue: 0.18, alpha: 1).cgColor,
                UIColor(red: 0.16, green: 0.19, blue: 0.33, alpha: 1).cgColor
            ]
        }
    }
}

private final class LoadingOverlayView: UIView {
    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let indicator = UIActivityIndicatorView(style: .large)

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(blur)
        addSubview(indicator)
        blur.translatesAutoresizingMaskIntoConstraints = false
        indicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor),

            indicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        indicator.startAnimating()
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private final class ErrorOverlayView: UIView {
    var onRetry: (() -> Void)?

    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let button = UIButton(type: .system)
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(blur)
        addSubview(stack)
        blur.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textAlignment = .center
        titleLabel.text = "Ошибка"

        messageLabel.font = .preferredFont(forTextStyle: .subheadline)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        button.configuration = .filled()
        button.configuration?.cornerStyle = .capsule
        button.configuration?.title = "Повторить"
        button.addTarget(self, action: #selector(retryTap), for: .touchUpInside)

        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 10
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(messageLabel)
        stack.addArrangedSubview(button)

        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func render(message: String) {
        messageLabel.text = message
    }

    @objc private func retryTap() {
        onRetry?()
    }
}

