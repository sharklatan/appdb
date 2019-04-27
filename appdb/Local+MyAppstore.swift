//
//  Local+MyAppstore.swift
//  appdb
//
//  Created by ned on 22/04/2019.
//  Copyright © 2019 ned. All rights reserved.
//

import UIKit
import DeepDiff

class LocalAndMyAppstore: LoadingCollectionView {
    
    fileprivate var ipas = [MyAppstoreApp]()
    fileprivate var timer: Timer? = nil
    
    convenience init() {
        self.init(collectionViewLayout: UICollectionViewFlowLayout())
    }
    
    deinit {
        timer?.invalidate()
        timer = nil
    }
    
    override func viewDidLoad() {
        self.hasSegment = true
        super.viewDidLoad()
        
        // Collection View
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.collectionViewLayout = layout
        
        // UI
        view.theme_backgroundColor = Color.tableViewBackgroundColor
        collectionView.theme_backgroundColor = Color.tableViewBackgroundColor
        collectionView.register(MyAppstoreCell.self, forCellWithReuseIdentifier: "myappstorecell")

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        state = .loading
        fetchIpas()
        
        if timer == nil {
            timer = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(fetchIpas), userInfo: nil, repeats: true)
        }
    }
    
    @objc fileprivate func fetchIpas() {
        API.getIpas(success: { ipas in
            
            let changes = diff(old: self.ipas, new: ipas)
            let animated = self.ipas.isEmpty
            
            self.collectionView.reload(changes: changes, section: 0, updateData: {
                self.ipas = ipas
                if !self.isDone { self.state = .done(animated: animated) }
            })
            
            if self.ipas.isEmpty {
                self.setErrorMessage()
            }
            
            self.collectionView.reloadData()
            
        }) { error in
            self.state = .error(first: "Unable to load apps", second: error.localizedDescription, animated: false) // todo localize
        }
    }
    
    fileprivate func setErrorMessage() {
        let noAppsMessage = "No MyAppstore apps".localized() // todo localize
        if case LoadingCollectionView.State.error(noAppsMessage, _, _) = state {} else {
            state = .error(first: noAppsMessage, second: "", animated: false)
        }
    }
    
    // MARK: - Orientation change
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            if !self.isLoading {
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.collectionViewLayout = self.layout
            }
        })
    }
    
    // MARK: - Collection view delegate
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return (isLoading || hasError) ? 0 : ipas.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard !isLoading, ipas.indices.contains(indexPath.row) else { return UICollectionViewCell() }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "myappstorecell", for: indexPath) as! MyAppstoreCell
        cell.configure(with: ipas[indexPath.row])
        cell.installButton.addTarget(self, action: #selector(install), for: .touchUpInside)
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard self.ipas.indices.contains(indexPath.row) else { return }
        
        let ipa = self.ipas[indexPath.row]
        
        let title = ipa.name
        let message = "\(ipa.bundleId)\(Global.bulletPoint)\(ipa.size)\n\nUploaded on \(ipa.uploadedAt.unixToDetailedString)" // todo localize
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        
        let delete = UIAlertAction(title: "Delete ipa".localized(), style: .destructive) { _ in // todo localize
            API.deleteIpa(id: ipa.id, completion: { error in
                if let error = error {
                    debugLog(error)
                } else {
                    self.ipas.remove(at: indexPath.row)
                    self.collectionView.deleteItems(at: [indexPath])
                    if self.ipas.isEmpty {
                        self.setErrorMessage()
                    }
                }
            })
        }
        let cancel = UIAlertAction(title: "Cancel".localized(), style: .cancel)
        
        alertController.addAction(delete)
        alertController.addAction(cancel)
        
        if let presenter = alertController.popoverPresentationController, let attributes = collectionView.layoutAttributesForItem(at: indexPath) {
            presenter.theme_backgroundColor = Color.popoverArrowColor
            presenter.sourceView = self.view
            presenter.sourceRect = collectionView.convert(attributes.frame, to: collectionView.superview)
            presenter.permittedArrowDirections = [.up, .down]
        }
        
        DispatchQueue.main.async {
            self.present(alertController, animated: true)
        }
    }
    
    // MARK: - Install app
    
    @objc fileprivate func install(sender: RoundedButton) {
        
        func setButtonTitle(_ text: String) {
            sender.setTitle(text.localized().uppercased(), for: .normal)
        }
        
        if DeviceInfo.deviceIsLinked {
            setButtonTitle("Requesting...") // todo localize
            
            API.install(id: sender.linkId, type: .myAppstore) { error in
                if let error = error {
                    debugLog(error)
                    delay(0.3) { setButtonTitle("Install") }
                } else {
                    setButtonTitle("Requested") // todo localize
                    
                    // todo addApp
                    
                    delay(5) { setButtonTitle("Install") }
                }
            }
        } else {
            // Install requested but device is not linked
        }
    }
    
}

// MARK: - ETCollectionViewDelegateWaterfallLayout

extension LocalAndMyAppstore: ETCollectionViewDelegateWaterfallLayout {
    
    var margin: CGFloat {
        return UIApplication.shared.statusBarOrientation.isLandscape && Global.hasNotch ? 50 : (20~~15)
    }
    
    var topInset: CGFloat {
        return Global.isIpad ? 25 : 15
    }
    
    var layout: ETCollectionViewWaterfallLayout {
        let layout = ETCollectionViewWaterfallLayout()
        layout.minimumColumnSpacing = 20~~15
        layout.minimumInteritemSpacing = 15~~10
        layout.sectionInset = UIEdgeInsets(top: topInset, left: margin, bottom: topInset, right: margin)
        if Global.isIpad {
            layout.columnCount = 2
        } else {
            layout.columnCount = UIApplication.shared.statusBarOrientation.isPortrait ? 1 : 2
        }
        return layout
    }
    
    var itemDimension: CGFloat {
        if Global.isIpad {
            if UIDevice.current.orientation.isPortrait {
                return (view.bounds.width / 2) - 30
            } else {
                return (view.bounds.width / 3) - 25
            }
        } else {
            if UIDevice.current.orientation.isPortrait {
                return view.bounds.width - 30
            } else {
                return (view.bounds.width / 2) - (Global.hasNotch ? 80 : 25)
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, sizeAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: itemDimension, height: (80~~70))
    }
}
