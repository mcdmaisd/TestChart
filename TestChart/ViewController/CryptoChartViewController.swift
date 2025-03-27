//
//  CryptoChartViewController.swift
//  TestChart
//
//  Created by ilim on 2025-03-27.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa
import LightweightCharts

class CryptoChartViewController: UIViewController {
    
    // MARK: - Properties
    private let disposeBag = DisposeBag()
    private let viewModel = CryptoChartViewModel()
    private let marketSelectionViewModel = MarketSelectionViewModel()
    
    private var chartView: LightweightCharts!
    private var candleSeries: CandlestickSeries!
    private var volumeSeries: HistogramSeries!
    private var isInitialConnection = true

    // MARK: - UI Components
    private let marketSelectionButton = UIButton(type: .system)
    private let timeframeSegmentedControl = UISegmentedControl(items: ["1분", "5분", "15분", "1시간", "일"])
    private let priceLabel = UILabel()
    private let changeLabel = UILabel()
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupChart()
        setupBindings()
        
        // 마켓 정보 로드
        marketSelectionViewModel.loadMarkets()
        
        // 초기 데이터 로드
        viewModel.connect()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.disconnect()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .white
        title = "업비트 차트"
        
        // 마켓 선택 버튼
        marketSelectionButton.setTitle("KRW-BTC", for: .normal)
        marketSelectionButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        marketSelectionButton.addTarget(self, action: #selector(showMarketSelection), for: .touchUpInside)
        
        // 가격 레이블
        priceLabel.font = .systemFont(ofSize: 20, weight: .bold)
        priceLabel.textAlignment = .right
        
        // 변동률 레이블
        changeLabel.font = .systemFont(ofSize: 14, weight: .medium)
        changeLabel.textAlignment = .right
        
        // 타임프레임 선택
        timeframeSegmentedControl.selectedSegmentIndex = 0
        timeframeSegmentedControl.addTarget(self, action: #selector(timeframeChanged), for: .valueChanged)
        
        // 로딩 인디케이터
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.color = .gray
        
        // 상단 컨트롤 스택뷰
        let marketInfoStackView = UIStackView(arrangedSubviews: [marketSelectionButton, priceLabel])
        marketInfoStackView.axis = .horizontal
        marketInfoStackView.distribution = .fillEqually
        
        let controlsStackView = UIStackView(arrangedSubviews: [marketInfoStackView, changeLabel, timeframeSegmentedControl])
        controlsStackView.axis = .vertical
        controlsStackView.spacing = 8
        controlsStackView.distribution = .fill
        
        view.addSubview(controlsStackView)
        controlsStackView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(8)
            make.left.right.equalToSuperview().inset(16)
        }
        
        // 차트 뷰 컨테이너
        let chartContainer = UIView()
        chartContainer.backgroundColor = .white
        view.addSubview(chartContainer)
        
        chartContainer.snp.makeConstraints { make in
            make.top.equalTo(controlsStackView.snp.bottom).offset(16)
            make.left.right.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
        }
        
        // 로딩 인디케이터
        view.addSubview(loadingIndicator)
        loadingIndicator.snp.makeConstraints { make in
            make.center.equalTo(chartContainer)
        }
        
        // 차트 뷰 초기화
        chartView = LightweightCharts()
        chartContainer.addSubview(chartView)
        
        chartView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    // MARK: - Chart Setup
    private func setupChart() {
        // 차트 옵션 설정
        var options = ChartOptions()
        options.layout = LayoutOptions(
            background: .solid(color: "#FFFFFF"),
            textColor: "#333333"
        )
        options.rightPriceScale = VisiblePriceScaleOptions(
            scaleMargins: PriceScaleMargins(top: 0.2, bottom: 0.2),
            borderVisible: true
        )
        options.timeScale = TimeScaleOptions(
            borderVisible: true
        )
        options.crosshair = CrosshairOptions(
            mode: .normal
        )
        
        chartView.applyOptions(options: options)
        
        // 캔들스틱 시리즈 추가
        var candleSeriesOptions = CandlestickSeriesOptions()
        candleSeriesOptions.upColor = "#26a69a"
        candleSeriesOptions.downColor = "#ef5350"
        candleSeriesOptions.borderVisible = false
        candleSeriesOptions.wickUpColor = "#26a69a"
        candleSeriesOptions.wickDownColor = "#ef5350"
        
        candleSeries = chartView.addCandlestickSeries(options: candleSeriesOptions)
        
        // 볼륨 시리즈 추가
        var volumeSeriesOptions = HistogramSeriesOptions()
        volumeSeriesOptions.priceFormat = .builtIn(BuiltInPriceFormat(type: .volume, precision: nil, minMove: nil))
        volumeSeriesOptions.priceScaleId = "volume"
        
        volumeSeries = chartView.addHistogramSeries(options: volumeSeriesOptions)
        
        // 볼륨 스케일 설정
        let volumeScaleOptions = PriceScaleOptions(
            scaleMargins: PriceScaleMargins(top: 0.8, bottom: 0),
            borderVisible: false
        )
        
        chartView.priceScale(priceScaleId: "volume").applyOptions(options: volumeScaleOptions)
    }
    
    // MARK: - Data Binding
    private func setupBindings() {
        // 로딩 상태 바인딩
        viewModel.isLoading
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] isLoading in
                if isLoading {
                    self?.loadingIndicator.startAnimating()
                } else {
                    self?.loadingIndicator.stopAnimating()
                }
            })
            .disposed(by: disposeBag)
        
        // 캔들 데이터 바인딩
        viewModel.candleData
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] candleData in
                self?.updateChartWithData(candleData)
            })
            .disposed(by: disposeBag)
        
        // 현재가 바인딩
        viewModel.currentPrice
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] price in
                self?.priceLabel.text = Formatters.formatCryptoPrice(price)
            })
            .disposed(by: disposeBag)
        
        // 에러 메시지 바인딩
        viewModel.errorMessage
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] message in
                self?.showErrorAlert(message)
            })
            .disposed(by: disposeBag)
        
        // 마켓 코드 바인딩
        viewModel.marketCode
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] market in
                guard let self = self else { return }
                let displayName = self.marketSelectionViewModel.getMarketDisplayName(market)
                self.marketSelectionButton.setTitle(displayName, for: .normal)
                self.title = displayName
            })
            .disposed(by: disposeBag)
        
        // 연결 상태 바인딩
        viewModel.connectionStatus
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] isConnected in
                self?.updateConnectionStatus(isConnected)
            })
            .disposed(by: disposeBag)
    }
    
    // MARK: - Chart Update
    private func updateChartWithData(_ candleData: [CandleData]) {
        // 캔들 데이터를 TradingView 라이브러리 형식으로 변환
        let candleItems = candleData.map { data -> CandlestickData in
            return CandlestickData(
                time: .utc(timestamp: data.time),
                open: data.open,
                high: data.high,
                low: data.low,
                close: data.close
            )
        }
        
        // 볼륨 데이터 변환
        let volumeItems = candleData.map { data -> HistogramData in
            return HistogramData(
                time: .utc(timestamp: data.time),
                value: data.volume ?? 0,
                color: data.close >= data.open ? "#26a69a80" : "#ef535080"
            )
        }
        
        // 차트 업데이트
        candleSeries.setData(data: candleItems)
        volumeSeries.setData(data: volumeItems)
        
        // 마지막 데이터로 스크롤
        if (candleItems.last?.time) != nil {
            chartView.timeScale().scrollToPosition(position: -10, animated: false)
        }
    }
    
    private func updateConnectionStatus(_ isConnected: Bool) {
        if isConnected {
            navigationController?.navigationBar.barTintColor = nil
            isInitialConnection = false
        } else {
            navigationController?.navigationBar.barTintColor = UIColor(hexString: "#ffcccc")
            
            // 초기 연결 시도가 아닐 때만 알림 표시
            if !isInitialConnection {
                // 연결 끊김 알림
                let alert = UIAlertController(
                    title: "연결 끊김",
                    message: "서버와의 연결이 끊어졌습니다. 다시 연결하시겠습니까?",
                    preferredStyle: .alert
                )
                
                alert.addAction(UIAlertAction(title: "재연결", style: .default) { [weak self] _ in
                    self?.viewModel.connect()
                })
                
                alert.addAction(UIAlertAction(title: "취소", style: .cancel))
                
                present(alert, animated: true)
            }
        }
    }

    // MARK: - Actions
    @objc private func showMarketSelection() {
        // 마켓 선택 액션시트 표시
        let actionSheet = UIAlertController(title: "마켓 선택", message: nil, preferredStyle: .actionSheet)
        
        for market in marketSelectionViewModel.availableMarkets.value {
            let displayName = "\(market.koreanName) (\(market.market))"
            
            actionSheet.addAction(UIAlertAction(title: displayName, style: .default) { [weak self] _ in
                self?.viewModel.changeMarket(market.market)
            })
        }
        
        actionSheet.addAction(UIAlertAction(title: "취소", style: .cancel))
        
        // iPad 대응
        if let popoverController = actionSheet.popoverPresentationController {
            popoverController.sourceView = marketSelectionButton
            popoverController.sourceRect = marketSelectionButton.bounds
        }
        
        present(actionSheet, animated: true)
    }
    
    @objc private func timeframeChanged() {
        // 타임프레임 변경 처리
        let timeframes = ["1", "5", "15", "60", "day"]
        guard let selectedTimeframe = timeframes[safe: timeframeSegmentedControl.selectedSegmentIndex] else { return }
        
        viewModel.changeTimeframe(selectedTimeframe)
    }
    
    // MARK: - Helpers
    private func showErrorAlert(_ message: String) {
        let alert = UIAlertController(
            title: "오류",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        
        present(alert, animated: true)
    }
}
