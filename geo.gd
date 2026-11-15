extends RefCounted
## Kleine Geometrie-Helfer: glatte Kurven, Rohre (Chrom-Streben) und flache Baender (Wege).


static func _idx(i: int, n: int, offen: bool) -> int:
	return clampi(i, 0, n - 1) if offen else posmod(i, n)


## Catmull-Rom-Kurve durch die Punkte. Geschlossen: letzter Punkt == erster.
static func kurve(pts: Array[Vector3], offen := true, samples := 10) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var n := pts.size()
	var segs := n - 1 if offen else n
	for i in segs:
		var p0 := pts[_idx(i - 1, n, offen)]
		var p1 := pts[_idx(i, n, offen)]
		var p2 := pts[_idx(i + 1, n, offen)]
		var p3 := pts[_idx(i + 2, n, offen)]
		for k in samples:
			var t := float(k) / float(samples)
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	if offen:
		out.append(pts[n - 1])
	else:
		out.append(out[0])
	return out


static func rohr(k: Array[Vector3], radius: float, seiten := 8) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ringe: Array = []
	for i in k.size():
		var t := (k[mini(i + 1, k.size() - 1)] - k[maxi(i - 1, 0)]).normalized()
		var ref := Vector3.UP if absf(t.y) < 0.9 else Vector3.RIGHT
		var seite := t.cross(ref).normalized()
		var hoch := seite.cross(t).normalized()
		var ring: Array[Vector3] = []
		for j in seiten:
			var a := TAU * j / seiten
			ring.append(k[i] + (seite * cos(a) + hoch * sin(a)) * radius)
		ringe.append(ring)
	for i in ringe.size() - 1:
		for j in seiten:
			var j2 := (j + 1) % seiten
			var a: Vector3 = ringe[i][j]
			var b: Vector3 = ringe[i + 1][j]
			var c: Vector3 = ringe[i + 1][j2]
			var d: Vector3 = ringe[i][j2]
			for v in [a, b, c, a, c, d]:
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()


## Flaches Band (Weg) entlang der Kurve in der xz-Ebene. versatz = seitlich verschoben.
static func band(k: Array[Vector3], breite: float, versatz := 0.0, y := 0.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var li: Array[Vector3] = []
	var re: Array[Vector3] = []
	for i in k.size():
		var t := k[mini(i + 1, k.size() - 1)] - k[maxi(i - 1, 0)]
		t.y = 0.0
		t = t.normalized()
		var q := Vector3(-t.z, 0.0, t.x)
		var m := k[i] + q * versatz + Vector3(0, y, 0)
		li.append(m + q * breite * 0.5)
		re.append(m - q * breite * 0.5)
	for i in k.size() - 1:
		for v in [li[i], re[i], li[i + 1], re[i], re[i + 1], li[i + 1]]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	return st.commit()
