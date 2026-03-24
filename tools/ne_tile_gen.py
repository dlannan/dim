import os
import math
import shapefile  # pyshp library
from shapely.geometry import shape, mapping, box
from shapely.ops import unary_union
from earcut import earcut 
import msgpack
import urllib.request
import zipfile

# Config
LEVEL = 6
TILE_SIZE = 180.0 / (2 ** LEVEL)
OUTPUT_DIR = "tiles/land"
REGION_BBOX = (18.0, 40.0, -160.0, -120.0)  # lat_min, lat_max, lon_min, lon_max (Hawaii to SF)

def download_and_extract_ne():
    url = "https://www.naturalearthdata.com/http//www.naturalearthdata.com/download/50m/physical/ne_50m_land.zip"
    zip_path = "ne_50m_land.zip"
    extract_dir = "ne_50m_land"

    if not os.path.exists(extract_dir):
        if not os.path.exists(zip_path):
            print("Downloading Natural Earth land polygons...")
            urllib.request.urlretrieve(url, zip_path)
        print("Extracting shapefile...")
        with zipfile.ZipFile(zip_path, "r") as zip_ref:
            zip_ref.extractall(extract_dir)
    return os.path.join(extract_dir, "ne_50m_land.shp")

def latlon_to_tile_indices(lat, lon):
    lat_idx = int(math.floor((lat + 90) / TILE_SIZE))
    lon_idx = int(math.floor((lon + 180) / TILE_SIZE))
    return lat_idx, lon_idx

def tile_bounds(lat_idx, lon_idx):
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

def polygon_to_tile_coords(polygon, tile_bbox):
    min_lat, max_lat, min_lon, max_lon = tile_bbox
    # Convert absolute lat/lon to local tile coords (0..tile_size)
    def local_coords(point):
        lat, lon = point[1], point[0]  # shapely is (lon, lat)
        return (lon - min_lon, lat - min_lat)
    if polygon.geom_type == 'Polygon':
        return [list(map(local_coords, ring.coords)) for ring in [polygon.exterior] + list(polygon.interiors)]
    elif polygon.geom_type == 'MultiPolygon':
        polys = []
        for poly in polygon.geoms:
            polys.extend(polygon_to_tile_coords(poly, tile_bbox))
        return polys
    else:
        return []

def main():
    shp_path = download_and_extract_ne()
    print("Loading shapefile:", shp_path)

    sf = shapefile.Reader(shp_path)
    shapes = sf.shapes()

    lat_start, lat_end, lon_start, lon_end = get_tile_range_for_bbox(REGION_BBOX)
    print(f"Tile range lat: {lat_start} to {lat_end}, lon: {lon_start} to {lon_end}")

    # Prepare output dir
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # Pre-load shapes as shapely geometries for clipping
    geoms = [shape(s.__geo_interface__) for s in shapes]

    # Combine all land shapes to simplify clipping
    combined = unary_union(geoms)

    for lat_idx in range(lat_start, lat_end + 1):
        for lon_idx in range(lon_start, lon_end + 1):
            bbox = tile_bounds(lat_idx, lon_idx)
            tile_box = box(*bbox[2:], *bbox[:2])  # lon_min, lon_max, lat_min, lat_max
            # Clip the combined land polygons with tile box
            clipped = combined.intersection(tile_box)
            if clipped.is_empty:
                continue

            polygons = []
            # Convert clipped geometry into polygon rings in local tile coords
            if clipped.geom_type == 'Polygon':
                polygons.append(polygon_to_tile_coords(cutt, bbox))
            elif clipped.geom_type == 'MultiPolygon':
                for geom in clipped.geoms:
                    polygons.append(polygon_to_tile_coords(cutt, bbox))

            if not polygons:
                continue

            # Prepare data dict
            data = {
                'bbox': bbox,
                'polygons': [{'points': poly} for poly in polygons],
            }

            # Serialize to msgpack
            filename = f"l{LEVEL}_{lat_idx}_{lon_idx}.msgpack"
            filepath = os.path.join(OUTPUT_DIR, filename)
            with open(filepath, 'wb') as f:
                f.write(msgpack.packb(data))

            print(f"Saved tile: {filename}")

if __name__ == "__main__":
    main()
