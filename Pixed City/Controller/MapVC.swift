//
//  ViewController.swift
//  Pixed City
//
//  Created by Wissa Azmy on 10/1/18.
//  Copyright © 2018 Wissa Azmy. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import Alamofire

class MapVC: UIViewController, UIGestureRecognizerDelegate {
    
    typealias completionHandler = (_ status: Bool) -> ()
    var locationManager = CLLocationManager()
    let authorizationStatus = CLLocationManager.authorizationStatus()
    let regionRadius: Double = 1000
    var progressLbl: UILabel!
    let spinner = UIActivityIndicatorView()
    var requestBody = [String: String]()
    // To get the screen size
    let screenSize = UIScreen.main.bounds
    var flowLayout = UICollectionViewFlowLayout()
    var collectionView: UICollectionView!
    var imageUrlArray = [String]()
    var imagesArray = [UIImage]() {
        didSet{
            progressLbl.text = "\(imagesArray.count)/\(imageUrlArray.count) Photos Downloaded"
        }
    }
    var imageCache = NSCache<NSString, UIImage>()
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var pullUpView: UIView!
    @IBOutlet weak var centerBtn: UIView!
    @IBOutlet weak var pullUpViewHeightConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        mapView.delegate = self
        locationManager.delegate = self
        
        // You need to add the following keys to your info.blist file
        // before requesting user location for it to work
        // Privacy - Location When In Use Usage Description
        // Privacy - Location Always Usage Description
        // Privacy - Location Always and When In Use Usage Description
        
        configureLocationServices()
        addDoubleTap()
        
        addCollectionView()
    }

    @IBAction func centerMapBtnTapped(_ sender: UIButton) {
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            centerMapOnUserLocation()
        }
    }
    
    private func addCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: flowLayout)
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: "photoCell")
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = #colorLiteral(red: 0, green: 1, blue: 0, alpha: 1)
        pullUpView.addSubview(collectionView)
    }

    func addDoubleTap() {
        // The doubleTap gestureRecognizer will pass itself automatically to the dropPen
        // function this way for it takes a parameter of the same type.
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(dropPen(sender: )))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delegate = self
        mapView.addGestureRecognizer(doubleTap)
    }
    
    private func addSwipe() {
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(togglePullUpView))
        swipe.direction = .down
        pullUpView.addGestureRecognizer(swipe)
    }
    
    @objc private func dropPen(sender: UITapGestureRecognizer) {
        // remove previous annotations before adding a new one
        removePin()
        // Get the touchPoint of the double tap gesture
        let touchPoint = sender.location(in: mapView)
        
        // This will convert the double tap touchPoint to coordinate from the MapView
        let touchCoordinate = mapView.convert(touchPoint, toCoordinateFrom: mapView)
        // Create annotation and add it to the mapView
        let annotation = DroppablePin(coordinate: touchCoordinate, identifier: "droppablePin")
        mapView.addAnnotation(annotation)
        // Recenter the mapView to the new annotation
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(touchCoordinate, regionRadius * 2.0, regionRadius * 2.0)
        mapView.setRegion(coordinateRegion, animated: true)
        
        if pullUpViewHeightConstraint.constant == 1 {
            togglePullUpView()
        } else { cancelAllSessions() }
        
        if progressLbl == nil { addProgressLbl() }
        
        downloadPhotosUrls(forAnnotation: annotation) { (status) in
            if status {
                DispatchQueue.main.async {
                    // hide spinner
                    self.spinner.stopAnimating()
                    // hide label
                    self.progressLbl.isHidden = true
                    // reload collection view
                }
                
            }
        }
    }
    
    private func removePin() {
        mapView.annotations.forEach( {mapView.removeAnnotation($0)} )
    }
    
    @objc private func togglePullUpView() {
        let pullViewHeight = self.view.frame.height / 3
        
        if pullUpViewHeightConstraint.constant == 1 {
            pullUpViewHeightConstraint.constant = pullViewHeight
            addSwipe()
            layoutViews()
            addSpinner()
        } else {
            pullUpViewHeightConstraint.constant = 1
            layoutViews()
            spinner.stopAnimating()
            cancelAllSessions()
        }
    }
    
    private func layoutViews() {
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    private func addSpinner() {
        spinner.center = pullUpView.convert(pullUpView.center, from: pullUpView.superview)
        spinner.activityIndicatorViewStyle = .whiteLarge
        spinner.color = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        spinner.startAnimating()
        collectionView.addSubview(spinner)
    }
    
    private func addProgressLbl() {
        progressLbl = UILabel()
        progressLbl.frame = CGRect(x: (screenSize.width / 2) - 150, y: (pullUpView.frame.height / 2) + (spinner.frame.width / 2) + 8, width: 300, height: 40)
        progressLbl.font = UIFont(name: "Avenir Next", size: 18)
        progressLbl.textColor = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        progressLbl.textAlignment = .center
        collectionView.addSubview(progressLbl)
    }
    
    private func downloadPhotosUrls(forAnnotation annotation: DroppablePin, completion: @escaping completionHandler) {

        let lat = annotation.coordinate.latitude
        let lon = annotation.coordinate.longitude
        
        let url = "https://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=\(flickrAPI.key)&lat=\(lat)&lon=\(lon)&radius=1&radius_units=mi&per_page=40&format=json&nojsoncallback=1"

        Alamofire.request(url).responseJSON { (response) in
//            print(response)
            guard let json = response.result.value as? Dictionary<String, AnyObject> else {return}
            let photosDict = json["photos"] as! Dictionary<String, AnyObject>
            let photosDictArray = photosDict["photo"] as! [Dictionary<String, AnyObject>]
            for photo in photosDictArray {
                let postUrl = "https://farm\(photo["farm"]!).staticflickr.com/\(photo["server"]!)/\(photo["id"]!)_\(photo["secret"]!)_h_d.jpg"
                self.imageUrlArray.append(postUrl)
            }
            
            self.retrieveImages(completion: { (success) in
                if success {
                    completion(true)
                }
            })
        }
    }
    
    private func retrieveImages(completion: @escaping completionHandler) {
        imagesArray = []
        DispatchQueue.global(qos: .userInitiated).async {
            self.imageUrlArray.forEach({
                let url = $0
                if let cachedImage = self.imageCache.object(forKey: url as NSString) {
                    self.imagesArray.append(cachedImage)
                }
                
                if let imageURL = URL(string: url) {
                    if let imgData = try? Data(contentsOf: imageURL),
                        let image = UIImage(data: imgData) {
                        self.imageCache.setObject(image, forKey: url as NSString)
                        DispatchQueue.main.async {
                            self.imagesArray.append(image)
                        }
                    }
                }
                
            })
            completion(true)
        }
    }
    
    private func cancelAllSessions() {
        Alamofire.SessionManager.default.session.getTasksWithCompletionHandler { (sessionDataTask, uploadData, downloadDataTask) in
            sessionDataTask.forEach({$0.cancel()})
            downloadDataTask.forEach({$0.cancel()})
        }
    }
    
}



extension MapVC: MKMapViewDelegate {
    // Change Pin color & customize it
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        // Avoid applying these changes to the user location Pin
        if annotation is MKUserLocation {
            return nil
        }
        // Create a new custom Pin to return
        let pinAnnotation = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "droppablePin")
        pinAnnotation.pinTintColor = #colorLiteral(red: 0.9771530032, green: 0.7062081099, blue: 0.1748393774, alpha: 1)
        pinAnnotation.animatesDrop = true
        return pinAnnotation
    }
    
    func centerMapOnUserLocation() {
        guard let coordinate = locationManager.location?.coordinate else {
            return
        }
        // regionRadius * 2.0 for the space above and under the location indicator,
        // and the same for right and left
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(coordinate, regionRadius * 2.0, regionRadius * 2.0)
        mapView.setRegion(coordinateRegion, animated: true)
    }
}

extension MapVC: CLLocationManagerDelegate {
    func configureLocationServices() {
        if authorizationStatus == .notDetermined {
            locationManager.requestAlwaysAuthorization()
        } else {
            // If authorization is already granted or denied
            return
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        centerMapOnUserLocation()
    }
}

extension MapVC: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 4
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "photoCell", for: indexPath) as! PhotoCell
        return cell
    }
}

extension MapVC: UICollectionViewDelegate {
    
}
