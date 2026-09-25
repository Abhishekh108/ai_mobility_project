import json
import polyline

d = json.load(open('scratch_routes.json'))
print("Origin:", d.get('origin'))
print("Destination:", d.get('destination'))
for i, r in enumerate(d['routes']):
    pts = polyline.decode(r['polyline_encoded'])
    print(f"Route {i}: {r['summary']}")
    print(f"  Total pts: {len(pts)}")
    print(f"  First 3 pts: {pts[:3]}")
    print(f"  Last 3 pts: {pts[-3:]}")
    print(f"  Duration: {r.get('total_duration_minutes')}")
    print(f"  Distance: {r.get('total_distance_km')}")
