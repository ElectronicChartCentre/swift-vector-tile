# Swift Vector tile

A Swift Package to encode Mapbox Vector Tiles (MVT) from [SwiftGeo](https://github.com/ElectronicChartCentre/swift-geo) geometries.

## This is how to recreate VectorTile.swift:
 
 ```
 brew install swift-protobuf
 mkdir proto; cd proto/
 curl -O https://raw.githubusercontent.com/mapbox/vector-tile-spec/master/2.1/vector_tile.proto
 protoc --swift_out=. vector_tile.proto
 mv vector_tile.pb.swift ../Sources/SwiftVectorTile/VectorTile.swift
 ```


## History.

* ECC created https://github.com/ElectronicChartCentre/java-vector-tile with JTS geometries.
* https://github.com/manimaul/SwiftVectorTiles was created as a Swift port of https://github.com/ElectronicChartCentre/java-vector-tile . It uses/used GEOS for the geometries.
* ECC created https://github.com/ElectronicChartCentre/swift-vector-tile based on https://github.com/manimaul/SwiftVectorTiles , but with https://github.com/ElectronicChartCentre/swift-geo instead of GEOS.
