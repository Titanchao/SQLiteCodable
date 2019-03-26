# SQLiteCodable

借鉴alibaba/HandyJSON代码
将model自动存储到数据库

```swift
SQLiteManager.setEnvironment("test")
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
