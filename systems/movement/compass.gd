enum Compass { N, E, S, W }

const Direction: Dictionary[Compass, Vector2] = {
	Compass.N: Vector2.UP,
	Compass.S: Vector2.DOWN,
	Compass.E: Vector2.RIGHT,
	Compass.W: Vector2.LEFT
}
