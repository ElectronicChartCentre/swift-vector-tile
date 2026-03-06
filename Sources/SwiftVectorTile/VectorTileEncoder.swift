//
//  VectorTileEncoder.swift
//

import Foundation

import SwiftGeo

/**
 A class to encode vector tiles.
 
 Based on https://github.com/manimaul/SwiftVectorTiles that is based on https://github.com/ElectronicChartCentre/java-vector-tile
 
 This is how to recreate VectorTile.swift:
 ```
 brew install swift-protobuf
 cd proto/
 protoc --swift_out=. vector_tile.proto
 mv vector_tile.pb.swift ../Classes/VectorTile.swift
 ```
 
 */
private class Feature {
    let _geometry: Geometry
    let _tags: [Int]
    let _id: UInt64?

    init(geometry: Geometry, tags: [Int], id: UInt64?) {
        self._geometry = geometry
        self._tags = tags
        self._id = id
    }
}

private class Layer {
    var _features = [Feature]()

    var _keys = [String: Int]()
    var _keysKeysOrdered = [String]()

    var _values = [VectorTileAttribute: Int]()
    var _valuesKeysOrdered = [VectorTileAttribute]()

    func key(key k: String) -> Int {
        guard let i = _keys[k] else {
            let index = _keys.count
            _keys[k] = index
            _keysKeysOrdered.append(k)
            return index
        }
        return i
    }

    func keys() -> [String] {
        return _keysKeysOrdered
    }

    func value(object obj: VectorTileAttribute) -> Int {
        guard let i = _values[obj] else {
            let index = _values.count
            _values[obj] = index
            _valuesKeysOrdered.append(obj)
            return index
        }
        return i
    }

    func values() -> [VectorTileAttribute] {
        return _valuesKeysOrdered
    }
}

private func createTileEnvelope(buffer b: Int, size s: Int) -> BoundingBox {
    let minx = 0 - Double(b)
    let maxx = Double(s + b)
    let miny = 0 - Double(b)
    let maxy = Double(s + b)
    return DefaultBoundingBox(minX: minx, maxX: maxx, minY: miny, maxY: maxy)
}

private func toIntArray(intArray arr: [Int]) -> [UInt32] {
    var ints = [UInt32]()
    for i in arr {
        ints.append(UInt32(i))
    }
    return ints
}

private func toGeomType(geometry g: Geometry) -> VectorTile_Tile.GeomType {
    switch g {
        case is Point, is MultiPoint:
            return VectorTile_Tile.GeomType.point
        // TODO: MultiLineString
        case is LineString, /*is MultiLineString, */is LinearRing:
             return VectorTile_Tile.GeomType.linestring
        // TODO: MultiPolygon
        case is Polygon/*, is MultiPolygon*/:
             return VectorTile_Tile.GeomType.polygon
        default:
            return VectorTile_Tile.GeomType.unknown
    }
}

/// https://developers.google.com/protocol-buffers/docs/encoding#types
private func zigZagEncode(number n: Int) -> Int {
    return (n << 1) ^ (n >> 31)
}

private func commandAndLength(command c: VectorTileCommand, repeated r: Int) -> Int {
    return r << 3 | c.rawValue
}

/**
 * Encodes geometries into Mapbox Vector tiles.
 */
public class VectorTileEncoder {
    private var _layers = [String: Layer]()
    private var _layerKeysOrdered = [String]()

    let _extent: Int
    let _clipGeometry: BoundingBox
    let _autoScale: Bool
    var _x = 0
    var _y = 0
    
    private let creator = DefaultGeometryCreator()

    /// Create a 'VectorTileEncoder' with the default extent of 4096 and clip buffer of 8.
    public convenience init() {
        self.init(extent: 4096, clipBuffer: 8, autoScale: true)
    }

    /// Create a 'VectorTileEncoder' with the given extent and a clip buffer of 8.
    public convenience init(extent e: Int) {
        self.init(extent: e, clipBuffer: 8, autoScale: true)
    }

    /// Create a {@link VectorTileEncoder} with the given extent value.
    ///
    /// The extent value control how detailed the coordinates are encoded in the
    /// vector tile. 4096 is a good default, 256 can be used to reduce density.
    ///
    /// The clip buffer value control how large the clipping area is outside of
    /// the tile for geometries. 0 means that the clipping is done at the tile
    /// border. 8 is a good default.
    ///
    /// - parameter extent: a int with extent value. 4096 is a good value.
    /// - parameter clipBuffer: a int with clip buffer size for geometries. 8 is a good value.
    /// - parameter autoScale: when true, the encoder expects coordinates in the 0..255 range and will scale them
    ///                        automatically to the 0..extent-1 range before encoding. when false, the encoder expects
    ///                        coordinates in the 0..extent-1 range.
    public init(extent e: Int, clipBuffer buffer: Int, autoScale auto: Bool) {
        _extent = e
        _autoScale = auto
        let size = auto ? 256 : e
        _clipGeometry = createTileEnvelope(buffer: buffer, size: size)
    }

    /// - returns: 'Data' with the vector tile
    public func encode() -> Data {
        var tileBuilder = VectorTile_Tile()
        var tileLayers = Array<VectorTile_Tile.Layer>()
        for layerName in _layerKeysOrdered {
            let layer = _layers[layerName]!

            var tileLayerBuilder = VectorTile_Tile.Layer()
            tileLayerBuilder.version = 2
            tileLayerBuilder.name = layerName
            tileLayerBuilder.keys = layer.keys()

            var values = Array<VectorTile_Tile.Value>()
            for attributeValue in layer.values() {
                var tileValue = VectorTile_Tile.Value()
                switch attributeValue {
                case let .attInt(aInt):
                    tileValue.intValue = aInt
                case let .attFloat(aFloat):
                    tileValue.floatValue = aFloat
                case let .attDouble(aDouble):
                    tileValue.doubleValue = aDouble
                case let .attBool(aBool):
                    tileValue.boolValue = aBool
                case let .attString(aString):
                    tileValue.stringValue = aString
                }
                values.append(tileValue)
            }
            tileLayerBuilder.values = values
            tileLayerBuilder.extent = UInt32(_extent)

            var features = Array<VectorTile_Tile.Feature>()
            for feature in layer._features {
                let geo = feature._geometry
                var f = VectorTile_Tile.Feature()
                f.tags = toIntArray(intArray: feature._tags)
                f.type = toGeomType(geometry: geo)
                f.geometry = commands(geometry: geo)
                if let fid = feature._id {
                    f.id = fid
                }
                features.append(f)
            }

            tileLayerBuilder.features = features
            tileLayers.append(tileLayerBuilder)

        }

        tileBuilder.layers = tileLayers
        
        do {
            return try tileBuilder.serializedData()
        } catch {
            fatalError("could not build tile")
        }
    }

    /*
    public func addFeature(layerName name: String, attributes attrs: [String: VectorTileAttribute]?, geometry wkb: Data) {
        guard let geo = GeometryFactory.geometryFromWellKnownBinary(wkb) else {
            print("could not create geometry")
            return
        }
        addFeature(layerName: name, attributes: attrs, geometry: geo)
    }

    public func addFeature(layerName name: String, attributes attrs: [String: VectorTileAttribute]?, geometry wkt: String) {
        guard let geo = GeometryFactory.geometryFromWellKnownText(wkt) else {
            print("could not create geometry")
            return
        }
        addFeature(layerName: name, attributes: attrs, geometry: geo)
    }
     */
    
    public func attrs(attributes attrs: [String: Any]) -> [String: VectorTileAttribute] {
        var returnAttributes = [String: VectorTileAttribute]()
        for (_, element) in attrs.enumerated() {
            if let s = element.value as? String {
                returnAttributes[element.key] = .attString(s)
            } else if let i = element.value as? Int64 {
                returnAttributes[element.key] = .attInt(i)
            } else if let i = element.value as? Int {
                returnAttributes[element.key] = .attInt(Int64(i))
            } else if let f = element.value as? Float {
                returnAttributes[element.key] = .attFloat(f)
            } else if let d = element.value as? Double {
                returnAttributes[element.key] = .attDouble(d)
            } else if let b = element.value as? Bool {
                returnAttributes[element.key] = .attBool(b)
            } else {
                returnAttributes[element.key] = .attString(String(describing: element.value))
            }
        }
        return returnAttributes
    }

    /// Add a feature with layer name (typically feature type name), some attributes and a Geometry. The Geometry must
    /// be in "pixel" space 0,0 lower left and 256,256 upper right.
    ///
    /// For optimization, geometries will be clipped, geometries will simplified and features with geometries outside
    /// of the tile will be skipped.
    ///
    /// - parameter layerName:
    /// - parameter attributes:
    /// - parameter geometry:
    /// - parameter id:
    public func addFeature(layerName name: String, attributes attrs: [String: VectorTileAttribute]?, geometry geom: Geometry?, id: UInt64? = nil) {
        guard let geo = geom else {
            return
        }

        if let mgc = geo as? MultiGeometry {
            splitAndAddFeatures(layerName: name, attributes: attrs, geometry: mgc.geometries())
            return
        }

        // skip small Polygon/LineString.
        if let polygon = geo as? Polygon {
            if let bbox = polygon.bbox() {
                let width = bbox.maxX - bbox.minX
                let height = bbox.maxY - bbox.minY
                if width * height < 1.0 {
                    return
                }
            }
        }

        if let line = geo as? LineString {
            if (line.length() < 1.0) {
                return
            }
        }

        // clip geometry
        var clippedGeo = geo
        
        // covers-check for point and clip for non-point
        if let point = geo as? Point {
            if !(clipCovers(geometry: point)) {
                print("DEBUG: point \(point) not in cover \(_clipGeometry)");
                return
            }
        } else {
            if let clippedNonPointGeo = createdClippedGeometry(geometry: geo) {
                clippedGeo = clippedNonPointGeo
            } else {
                return
            }
        }
        
        // if clipping result in GeometryCollection, then split once more
        if let mgc = clippedGeo as? MultiGeometry {
            splitAndAddFeatures(layerName: name, attributes: attrs, geometry: mgc.geometries())
            return
        }

        // no need to add empty geometry
        if clippedGeo.isEmpty() {
            return
        }

        var layer = _layers[name]
        if layer == nil {
            layer = Layer()
            _layers[name] = layer
            _layerKeysOrdered.append(name)
        }

        var tags = [Int]()
        if let attributes = attrs {
            for (key, val) in attributes {
                tags.append(layer!.key(key: key))
                tags.append(layer!.value(object: val))
            }
        }
        let feature = Feature(geometry: clippedGeo, tags: tags, id: id)
        layer!._features.append(feature)
    }

    private func commands(coordinates cs: [any Coordinate], closePathAtEnd closedEnd: Bool, isMultiPoint mp: Bool) -> [UInt32] {
        let count = Int(cs.count)

        if count == 0 {
            fatalError("empty geometry")
        }

        var r = [Int]()
        var lineToIndex = 0
        var lineToLength = 0
        let scale = _autoScale ? (Double(_extent) / 256.0) : 1.0

        var i = 0
        let first = cs[0]
        for c in cs {
            if i == 0 {
                r.append(commandAndLength(command: .moveTo, repeated: mp ? count: 1))
            }

            let x = Int(round(c.x * scale))
            let y = Int(round(c.y * scale))

            // prevent point equal to the previous
            if i > 0 && x == _x && y == _y {
                lineToLength -= 1
                continue
            }

            // prevent double closing
            if closedEnd && (cs.count > 1) && (i == (count - 1)) && first.isEqual(to: c) {
                lineToLength -= 1
                continue
            }

            // delta, then zigzag
            r.append(zigZagEncode(number: x - _x))
            r.append(zigZagEncode(number: y - _y))

            _x = x
            _y = y

            if (i == 0) && (count > 1) && !mp {
                // can length be too long?
                lineToIndex = r.count
                lineToLength = count - 1
                r.append(commandAndLength(command: .lineTo, repeated: lineToLength))

            }
            i += 1
        }

        // update LineTo length
        if lineToIndex > 0 {
            if lineToLength == 0 {
                r.remove(at: lineToIndex)
            } else {
                // update LineTo with new length
                r[lineToIndex] = commandAndLength(command: .lineTo, repeated: lineToLength)
            }
        }

        if closedEnd {
            r.append(commandAndLength(command: .closePath, repeated: 1))
        }

        return toIntArray(intArray: r)
    }

    private func commands(coordinates cs: [any Coordinate], closePathAtEnd closedEnd: Bool) -> [UInt32] {
        return commands(coordinates: cs, closePathAtEnd: closedEnd, isMultiPoint: false)
    }

    private func commands(geometry geo: Geometry) -> [UInt32] {

        _x = 0
        _y = 0

        if let polygon = geo as? Polygon {
            var result = [UInt32]()

            // According to the vector tile specification, the exterior ring of a polygon
            // must be in clockwise order, while the interior ring in counter-clockwise order.
            // In the tile coordinate system, Y axis is positive down.
            //
            // However, in geaphic coordinate system, Y axis is positive up.
            // Therefore, we must reverse the coordinates.
            // So, the code below will make sure that exterior ring is in counter-clockwise order
            // and interior ring in clockwise order.
            let exteriorRing = Orientation.ensureDirection(ring: polygon.shell, direction: .CW, creator: creator)
            result.append(contentsOf: commands(coordinates: exteriorRing.coordinates, closePathAtEnd: true))

            for interiorRing in polygon.holes {
                let ir = Orientation.ensureDirection(ring: interiorRing, direction: .CCW, creator: creator)
                result.append(contentsOf: commands(coordinates: ir.coordinates, closePathAtEnd: true))
            }

            return result
        }

        /* TODO: MultiLineString
        if let mls = geo as? MultiLineString {
            var result = [UInt32]()
            for iGeo in mls.geometries() {
                result.append(contentsOf: commands(coordinates: iGeo.coordinateXYs(), closePathAtEnd: false))
            }
            return result
        }
         */
        
        if let line = geo as? LinearGeometry {
            return commands(coordinates: line.coordinates, closePathAtEnd: shouldClosePath(geometry: geo), isMultiPoint: false)
        }
        
        if let point = geo as? Point {
            return commands(coordinates: [point.coordinate], closePathAtEnd: shouldClosePath(geometry: geo), isMultiPoint: false)
        }
        
        if let multiPoint = geo as? MultiPoint {
            return commands(coordinates: multiPoint.coordinates(), closePathAtEnd: shouldClosePath(geometry: geo), isMultiPoint: true)
        }

        print("TODO: Unsupported geometry type: \(type(of: geo))")
        return []
    }

    private func shouldClosePath(geometry: Geometry) -> Bool {
        return (geometry is Polygon) || (geometry is LinearRing)
    }

    private func createdClippedGeometry(geometry g: Geometry?) -> Geometry? {
        // TODO: implement geometry clipping
        return g
        /*
        guard let geo = g,
              let clipped = _clipGeometry.intersectionGeometry(geo) else {
            // could not intersect. original geometry will be used instead.
            return g
        }

        return clipped
         */
    }

    /// A short circuit clip to the tile extent (tile boundary + buffer) for points to improve performance. This method
    /// can be overridden to change clipping behavior. See also 'clipGeometry(Geometry)'.
    ///
    /// see https://github.com/ElectronicChartCentre/java-vector-tile/issues/13
    private func clipCovers(geometry geo: Geometry) -> Bool {
        // TODO: implement covers
        if let geobbox = geo.bbox() {
            return _clipGeometry.intersects(geobbox)
        }
        return false
        //return _clipGeometry.coversGeometry(geo);
    }

    private func splitAndAddFeatures(layerName name: String, attributes attrs: [String: VectorTileAttribute]?, geometry geo: [Geometry]) {

        for each in geo {
            addFeature(layerName: name, attributes: attrs, geometry: each)
        }
    }

}
