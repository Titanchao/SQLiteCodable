# SQLiteCodable

```swift
SQLiteManager.initialize("private")
SQLiteManager.prepare { () -> [SQLiteCodable.Type] in
	return [Player.self]
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

let player = Player()
player.id = 24
player.name = "Kobe"
player.time = Date()
Player.insert([player])
