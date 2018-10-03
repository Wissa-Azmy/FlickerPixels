//
//  DroppablePin.swift
//  Pixed City
//
//  Created by Wissa Azmy on 10/1/18.
//  Copyright © 2018 Wissa Azmy. All rights reserved.
//

import UIKit
import MapKit

class DroppablePin: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    var identifier: String
    
    init(coordinate: CLLocationCoordinate2D, identifier: String) {
        self.coordinate = coordinate
        self.identifier = identifier
        super.init()
    }
    
}
