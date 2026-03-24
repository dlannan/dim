import shapely.geometry
import shapely.ops
import math
import os
import fiona
import msgpack
from shapely.geometry import shape, LineString, MultiLineString, box
from collections import defaultdict

LEVEL = 6  # Level 6: 64x64 global grid
TILE_SIZE = 180.0 / (2 ** LEVEL)

SOURCE_DATA = []
SOURCE_DATA.append(["ne_10m_roads.shp","10m_roads_l6"])

SOURCE_SELECT = 0

# Whole planet - if I get picky I can reduce to specific regions.
REGION_BBOX = (-90.0, 90.0, -180.0, 180.0)  # lat_min, lat_max, lon_min, lon_max (Hawaii to SF)

DATA_PATH  = SOURCE_DATA[SOURCE_SELECT][0]
OUTPUT_DIR = SOURCE_DATA[SOURCE_SELECT][1]

os.makedirs(OUTPUT_DIR, exist_ok=True)

LEVEL = 6
LON_PER_TILE = 360.0 / TILE_SIZE
LAT_PER_TILE = 180.0 / TILE_SIZE

def latlon_to_tile_indices(lat, lon):
    lat_idx = int(math.floor((lat + 90) / TILE_SIZE))
    lon_idx = int(math.floor((lon + 180) / TILE_SIZE))
    return lon_idx, lat_idx

# def tile_bounds(tx, ty):
#     min_lon = -180 + tx * LON_PER_TILE
#     max_lon = min_lon + LON_PER_TILE
#     min_lat = -90 + ty * LAT_PER_TILE
#     max_lat = min_lat + LAT_PER_TILE
#     return (min_lon, min_lat, max_lon, max_lat)

def get_tile_bounds(lon_idx, lat_idx):
    min_lat = lat_idx * TILE_SIZE - 90
    max_lat = min_lat + TILE_SIZE
    min_lon = lon_idx * TILE_SIZE - 180
    max_lon = min_lon + TILE_SIZE
    return (min_lon, min_lat, max_lon, max_lat)

# def lonlat_to_local(lon, lat, center_lon, center_lat):
#     # Approximate meters using spherical earth
#     m_per_deg_lon = 40075000 * math.cos(math.radians(center_lat)) / 360.0
#     m_per_deg_lat = 111320
#     dx = (lon - center_lon) * m_per_deg_lon
#     dy = (lat - center_lat) * m_per_deg_lat
#     return [dx, dy]
#     # Helper: convert lon/lat to local XY

def lonlat_to_local(lon, lat, c_lon, c_lat):
    x = (lon - c_lon)
    y = (lat - c_lat)
    return x, y

def process_linestring(geom, props, tile_segments):
    bounds = geom.bounds
    min_tx, min_ty = latlon_to_tile_indices(bounds[1], bounds[0])
    max_tx, max_ty = latlon_to_tile_indices(bounds[3], bounds[2])
    road_type = props.get("type", "unknown")

    for tx in range(min_tx, max_tx + 1):
        for ty in range(min_ty, max_ty + 1):
            tile_box = box(*get_tile_bounds(tx, ty))
            clipped = geom.intersection(tile_box)
            if clipped.is_empty:
                continue

            center_lon, center_lat = tile_box.centroid.x, tile_box.centroid.y

            lines = clipped.geoms if isinstance(clipped, MultiLineString) else [clipped]
            for line in lines:
                coords = [lonlat_to_local(lon, lat, center_lon, center_lat)
                          for lon, lat in line.coords]
                if len(coords) >= 2:
                    tile_segments[(tx, ty)].append({
                        "type": road_type,
                        "line": coords
                    })

def get_tile_range_for_bbox(bbox):
    lat_min, lat_max, lon_min, lon_max = bbox
    lon_start, lat_start = latlon_to_tile_indices(lat_min, lon_min)
    lon_end, lat_end = latlon_to_tile_indices(lat_max, lon_max)
    return lat_start, lat_end, lon_start, lon_end
    
lat_start, lat_end, lon_start, lon_end = get_tile_range_for_bbox(REGION_BBOX)
print(f"Tile range lat: {lat_start} to {lat_end}, lon: {lon_start} to {lon_end}")

tile_segments = defaultdict(list)

with fiona.open("ne_10m_roads.shp") as src:
    for feat in src:
        geom = shape(feat["geometry"])
        if isinstance(geom, (LineString, MultiLineString)):
            process_linestring(geom, feat["properties"], tile_segments)

alltiles = []

for (lon_idx, lat_idx), segments in tile_segments.items():

    bbox = get_tile_bounds(lat_idx, lon_idx)
    min_lat = bbox[1]
    max_lat = bbox[3]
    min_lon = bbox[0]
    max_lon = bbox[2]

    tile = {
        "bounds": {
            "min_lat": min_lat,
            "min_lon": min_lon,
            "max_lat": max_lat,
            "max_lon": max_lon,
        },
        "roads": segments,
    }

    tile_ref = {
        "pack": tile,
        "name": f"l{LEVEL}_{lat_idx}_{lon_idx}"
    }

    print(f"Tile: {tile_ref["name"]}")
    alltiles.append(tile_ref)

filename = f"{OUTPUT_DIR}.msgpack"
filepath = os.path.join(OUTPUT_DIR, filename)

with open(filepath, "wb") as f:
    f.write(msgpack.packb(alltiles))

print(f"Saved tile: {filename}")
