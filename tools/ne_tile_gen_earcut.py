import shapely.geometry
import shapely.ops
import fiona
import mapbox_earcut as earcut
import msgpack
import os
import math

import numpy as np
from shapely.geometry import Polygon, MultiPolygon
from math import cos, radians
from mapbox_earcut import triangulate_float32

LEVEL = 6
TILE_SIZE = 180.0 / (2 ** LEVEL)

SOURCE_DATA = []
SOURCE_DATA.append(["ne_10m_land.shp" ,"10m_land_l6"])
SOURCE_DATA.append(["ne_10m_roads.shp","10m_roads_l6"])
SOURCE_DATA.append(["ne_10m_airports.shp", "10m_airports_l6"])
SOURCE_DATA.append(["ne_10m_urban_areas.shp", "10m_urban_l6"])

SOURCE_SELECT = 3

# Whole planet - if I get picky I can reduce to specific regions.
REGION_BBOX = (-90.0, 90.0, -180.0, 180.0)  # lat_min, lat_max, lon_min, lon_max (Hawaii to SF)

DATA_PATH  = SOURCE_DATA[SOURCE_SELECT][0]
OUTPUT_DIR = SOURCE_DATA[SOURCE_SELECT][1]

os.makedirs(OUTPUT_DIR, exist_ok=True)

def latlon_to_tile_indices(lat, lon):
    lat_idx = int(math.floor((lat + 90) / TILE_SIZE))
    lon_idx = int(math.floor((lon + 180) / TILE_SIZE))
    return lat_idx, lon_idx

def get_tile_bounds(lat_idx, lon_idx):
    min_lat = lat_idx * TILE_SIZE - 90
    max_lat = min_lat + TILE_SIZE
    min_lon = lon_idx * TILE_SIZE - 180
    max_lon = min_lon + TILE_SIZE
    return (min_lat, max_lat, min_lon, max_lon)

def get_tile_range_for_bbox(bbox):
    lat_min, lat_max, lon_min, lon_max = bbox
    lat_start, lon_start = latlon_to_tile_indices(lat_min, lon_min)
    lat_end, lon_end = latlon_to_tile_indices(lat_max, lon_max)
    return lat_start, lat_end, lon_start, lon_end

def polygon_to_triangles(geometry, center_lon, center_lat):
    """
    geometry: shapely Polygon or MultiPolygon
    center_lon, center_lat: for local coordinate conversion
    Returns: list of triangles (each triangle is 3 points in local coords)
    """
    triangles = []

    from shapely.geometry import MultiPolygon, Polygon

    if isinstance(geometry, MultiPolygon):
        for part in geometry.geoms:
            triangles.extend(polygon_to_triangles(part, center_lon, center_lat))
        return triangles

    if not isinstance(geometry, Polygon):
        # unsupported geometry
        return triangles

    # Build rings (outer + holes) and flat coords list
    rings = []
    flat_coords = []

    # Helper: convert lon/lat to local XY
    def lonlat_to_local(lon, lat, c_lon, c_lat):
        x = (lon - c_lon)
        y = (lat - c_lat)
        return x, y

    # Start with outer ring
    outer = geometry.exterior.coords
    for lon, lat in outer:
        x, y = lonlat_to_local(lon, lat, center_lon, center_lat)
        flat_coords.append([x, y])

    # Then holes
    for interior in geometry.interiors:
        rings.append(len(flat_coords))
        for lon, lat in interior.coords:
            x, y = lonlat_to_local(lon, lat, center_lon, center_lat)
            flat_coords.append([x, y])

    if(len(rings) == 0):
        rings.append(len(flat_coords))

    # Call earcut triangulate_float32 with coords and rings
    try:
        indices = triangulate_float32(flat_coords, rings)
    except ValueError as e:
        print("Triangulation failed:", e)
        return []

    # Build triangles from indices
    for i in range(0, len(indices), 3):
        idx0, idx1, idx2 = indices[i], indices[i+1], indices[i+2]
        p0 = flat_coords[idx0]
        p1 = flat_coords[idx1]
        p2 = flat_coords[idx2]
        triangles.append([p0, p1, p2])

    return triangles

with fiona.open(DATA_PATH) as src:
    features = [shapely.geometry.shape(f["geometry"]) for f in src]

lat_start, lat_end, lon_start, lon_end = get_tile_range_for_bbox(REGION_BBOX)
print(f"Tile range lat: {lat_start} to {lat_end}, lon: {lon_start} to {lon_end}")

alltiles = []

for lat_idx in range(lat_start, lat_end + 1):
    for lon_idx in range(lon_start, lon_end + 1):
        bbox = get_tile_bounds(lat_idx, lon_idx)
        min_lat = bbox[0]
        max_lat = bbox[1]
        min_lon = bbox[2]
        max_lon = bbox[3]

        tile_bounds = shapely.geometry.box(min_lon, min_lat, max_lon, max_lat)
        tile_center = [(min_lon + max_lon) / 2, (min_lat + max_lat) / 2]

        clipped = []
        for feature in features:
            if not feature.intersects(tile_bounds):
                continue
            clipped_geom = feature.intersection(tile_bounds)
            if not clipped_geom.is_empty:
                clipped.append(clipped_geom)

        tile_triangles = []
        for geom in clipped:
            tris = polygon_to_triangles(geom, *tile_center)
            tile_triangles.extend(tris)

        if not tile_triangles:
            continue  # skip empty tiles

        tile = {
            "bounds": {
                "min_lat": min_lat,
                "min_lon": min_lon,
                "max_lat": max_lat,
                "max_lon": max_lon,
            },
            "triangles": tile_triangles,
        }

        tile_ref = {
            "pack": tile,
            "name": f"l{LEVEL}_{lat_idx}_{lon_idx}"
        }
        print(f"Tile: {tile_ref["name"]}")
        alltiles.append(tile_ref)

# Serialize to msgpack
filename = f"{OUTPUT_DIR}.msgpack"
filepath = os.path.join(OUTPUT_DIR, filename)
with open(filepath, 'wb') as f:
    f.write(msgpack.packb(alltiles))

print(f"Saved tile: {filename}")
