//
//  ViewController.swift
//  demo
//
//  Created by tian on 2018/12/17.
//  Copyright © 2018 tian. All rights reserved.
//

import UIKit
import SQLiteCodable

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        SQLiteManager.initialize("private")
        SQLiteManager.prepare { () -> [SQLiteCodable.Type] in
            return [Player.self]
        }
        
        let player = Player()
        player.id = 24
        player.name = "Kobe"
        player.time = Date()
        
        Player.insert([player])
        
        
        if let aplayer = Player.selectOne() {
            print(aplayer.name)
        }
    }


}

class Player: SQLiteCodable {
    
    var id = 0
    var name = ""
    var time = Date()
    
    required init() {}
    
    func declareKeys(mapper: SQLiteMapper) {
        mapper <<- self.id
        mapper <~~ self.time
    }
    
    

}

