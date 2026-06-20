#!/usr/bin/env python3
import csv
import math
import os
import statistics
import sys
from collections import defaultdict
from xml.sax.saxutils import escape


WIDTH = 1120
HEIGHT = 680
LEFT = 86
RIGHT = 250
TOP = 58
BOTTOM = 82

SERIES = [
    ("standard", "otp-base64", "OTP base64", {
        "encode": ("#4b5563", "", 2.1),
        "decode": ("#cbd5e1", "", 2.1),
    }),
    ("standard", "b64fast", "Original b64fast", {
        "encode": ("#8c6d31", "", 2.1),
        "decode": ("#d8b365", "", 2.1),
    }),
    ("base64url", "b64rs", "b64rs url", {
        "encode": ("#2166ac", "", 2.1),
        "decode": ("#92c5de", "", 2.1),
    }),
    ("standard", "b64veryfast", "b64veryfast", {
        "encode": ("#b2182b", "", 3.1),
        "decode": ("#ef8a62", "", 3.1),
    }),
    ("standard", "b64veryfast-unchecked", "b64veryfast unchecked", {
        "decode": ("#d6604d", ' stroke-dasharray="6 4"', 3.1),
    }),
]


def read_rows(path):
    rows = []
    with open(path, newline="") as f:
        for row in csv.DictReader(f):
            row["size_bytes"] = int(row["size_bytes"])
            row["iterations"] = int(row["iterations"])
            row["run"] = int(row["run"])
            row["elapsed_us"] = int(row["elapsed_us"])
            row["mib_per_s"] = float(row["mib_per_s"])
            if row["library"] == "b64veryfast-trusted":
                row["library"] = "b64veryfast-unchecked"
            elif row["library"] == "b64veryfast-url-trusted":
                row["library"] = "b64veryfast-url-unchecked"
            rows.append(row)
    return rows


def summarize(rows):
    grouped = defaultdict(list)
    for row in rows:
        key = (row["family"], row["library"], row["operation"], row["size_bytes"])
        grouped[key].append(row["mib_per_s"])
    summary = {}
    for key, values in grouped.items():
        values = sorted(values)
        summary[key] = {
            "mean": statistics.fmean(values),
            "median": statistics.median(values),
            "min": min(values),
            "max": max(values),
        }
    return summary


def write_summary_csv(summary, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", newline="") as f:
        writer = csv.writer(f, lineterminator="\n")
        writer.writerow(["family", "library", "operation", "size_bytes", "mean_mib_per_s",
                         "median_mib_per_s", "min_mib_per_s", "max_mib_per_s"])
        for key in sorted(summary):
            family, library, operation, size = key
            vals = summary[key]
            writer.writerow([
                family, library, operation, size,
                f"{vals['mean']:.6f}",
                f"{vals['median']:.6f}",
                f"{vals['min']:.6f}",
                f"{vals['max']:.6f}",
            ])


def fmt_size(value):
    if value >= 1024 * 1024:
        v = value / (1024 * 1024)
        return f"{v:g} MiB"
    if value >= 1024:
        v = value / 1024
        return f"{v:g} KiB"
    return f"{value} B"


def scale_log(domain_min, domain_max, range_min, range_max):
    lo = math.log10(domain_min)
    hi = math.log10(domain_max)

    def mapper(value):
        return range_min + (math.log10(value) - lo) / (hi - lo) * (range_max - range_min)

    return mapper


def scale_linear(domain_min, domain_max, range_min, range_max):
    def mapper(value):
        return range_min + (value - domain_min) / (domain_max - domain_min) * (range_max - range_min)

    return mapper


def path_for(points, xmap, ymap, field="mean"):
    parts = []
    for i, point in enumerate(points):
        command = "M" if i == 0 else "L"
        parts.append(f"{command}{xmap(point['size']):.2f},{ymap(point[field]):.2f}")
    return " ".join(parts)


def nice_y_ticks(y_min, y_max):
    if y_max <= 0:
        return [0]
    rough = y_max / 5
    exp = math.floor(math.log10(rough))
    base = rough / (10 ** exp)
    if base <= 1:
        step = 1
    elif base <= 2:
        step = 2
    elif base <= 5:
        step = 5
    else:
        step = 10
    step *= 10 ** exp
    return [tick * step for tick in range(0, int(math.ceil(y_max / step)) + 1) if tick * step <= y_max]


def collect_series(summary, rows):
    combined = []
    for family, library, label, operations in SERIES:
        for operation, (color, dash, width) in operations.items():
            points = []
            for (fam, lib, op, size), vals in summary.items():
                if fam == family and lib == library and op == operation:
                    points.append({"size": size, **vals})
            run_points = [
                row for row in rows
                if row["family"] == family and row["library"] == library and row["operation"] == operation
            ]
            if points:
                combined.append({
                    "label": label,
                    "operation": operation,
                    "color": color,
                    "dash": dash,
                    "width": width,
                    "points": sorted(points, key=lambda item: item["size"]),
                    "run_points": sorted(run_points, key=lambda item: (item["size_bytes"], item["run"])),
                })
    return combined


def svg_chart(summary, rows, out_path):
    series = collect_series(summary, rows)
    sizes = sorted({point["size"] for item in series for point in item["points"]})
    values = [point["median"] for item in series for point in item["points"]]
    values += [point["mib_per_s"] for item in series for point in item["run_points"]]
    x_min, x_max = min(sizes), max(sizes)
    y_min = 0
    y_max = max(values) * 1.12
    xmap = scale_log(x_min, x_max, LEFT, WIDTH - RIGHT)
    ymap = scale_linear(y_min, y_max, HEIGHT - BOTTOM, TOP)

    x_ticks = [16, 64, 256, 1024, 4096, 16384, 65536, 262144, 1048576, 4194304, 16777216]
    x_ticks = [tick for tick in x_ticks if x_min <= tick <= x_max]
    y_ticks = nice_y_ticks(y_min, y_max)

    lines = [
        '<svg xmlns="http://www.w3.org/2000/svg" width="{0}" height="{1}" viewBox="0 0 {0} {1}">'.format(WIDTH, HEIGHT),
        "<style>",
        "text{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;fill:#172033}",
        ".title{font-size:24px;font-weight:700}",
        ".label{font-size:14px;font-weight:600}",
        ".tick{font-size:12px;fill:#526070}",
        ".grid{stroke:#d8dee8;stroke-width:1}",
        ".axis{stroke:#172033;stroke-width:1.5}",
        ".legend{font-size:13px}",
        ".legend-small{font-size:12px;fill:#526070}",
        "</style>",
        '<rect x="0" y="0" width="100%" height="100%" fill="#ffffff"/>',
        f'<text class="title" x="{LEFT}" y="34">Base64 throughput by payload size</text>',
        f'<text class="tick" x="{LEFT}" y="54">Median lines plus every run as points. X-axis log scale, y-axis linear. Dark encode, light decode.</text>',
    ]

    for tick in x_ticks:
        x = xmap(tick)
        lines.append(f'<line class="grid" x1="{x:.2f}" y1="{TOP}" x2="{x:.2f}" y2="{HEIGHT - BOTTOM}"/>')
        lines.append(f'<text class="tick" x="{x:.2f}" y="{HEIGHT - BOTTOM + 24}" text-anchor="middle">{fmt_size(tick)}</text>')

    for tick in y_ticks:
        value = tick if isinstance(tick, float) else tick
        y = ymap(value)
        lines.append(f'<line class="grid" x1="{LEFT}" y1="{y:.2f}" x2="{WIDTH - RIGHT}" y2="{y:.2f}"/>')
        lines.append(f'<text class="tick" x="{LEFT - 10}" y="{y + 4:.2f}" text-anchor="end">{value:g}</text>')

    lines.append(f'<line class="axis" x1="{LEFT}" y1="{HEIGHT - BOTTOM}" x2="{WIDTH - RIGHT}" y2="{HEIGHT - BOTTOM}"/>')
    lines.append(f'<line class="axis" x1="{LEFT}" y1="{TOP}" x2="{LEFT}" y2="{HEIGHT - BOTTOM}"/>')
    lines.append(f'<text class="label" x="{(LEFT + WIDTH - RIGHT) / 2:.2f}" y="{HEIGHT - 24}" text-anchor="middle">Input or decoded output size</text>')
    lines.append(f'<text class="label" transform="translate(22,{(TOP + HEIGHT - BOTTOM) / 2:.2f}) rotate(-90)" text-anchor="middle">MiB/s</text>')

    legend_x = WIDTH - RIGHT + 28
    legend_y = TOP + 8
    legend_rows = [
        (item["label"], item["operation"], item["color"], item["dash"], item["width"])
        for item in series
    ]
    for i, (label, operation, color, dash, width) in enumerate(legend_rows):
        y = legend_y + i * 24
        lines.append(f'<line x1="{legend_x}" y1="{y}" x2="{legend_x + 24}" y2="{y}" stroke="{color}" stroke-width="{width}" stroke-linecap="round"{dash}/>')
        lines.append(f'<text class="legend" x="{legend_x + 34}" y="{y + 4}">{escape(label)} {operation}</text>')

    for item in series:
        for point in item["run_points"]:
            jitter = (point["run"] - 3) * 1.6
            radius = 2.2 if item["width"] > 3 else 1.7
            opacity = 0.20 if item["width"] > 3 else 0.16
            lines.append(
                f'<circle cx="{xmap(point["size_bytes"]) + jitter:.2f}" '
                f'cy="{ymap(point["mib_per_s"]):.2f}" r="{radius}" '
                f'fill="{item["color"]}" opacity="{opacity}"/>'
            )

    for item in series:
        if len(item["points"]) >= 2:
            lines.append(
                f'<path d="{path_for(item["points"], xmap, ymap, "median")}" fill="none" '
                f'stroke="{item["color"]}" stroke-width="{item["width"]}" '
                f'stroke-linejoin="round" stroke-linecap="round"{item["dash"]}/>'
            )

    lines.append("</svg>")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w") as f:
        f.write("\n".join(lines))


def main():
    if len(sys.argv) not in (2, 3):
        print("usage: bench/plot.py <raw.csv> [out-dir]", file=sys.stderr)
        return 2
    raw_path = sys.argv[1]
    out_dir = sys.argv[2] if len(sys.argv) == 3 else "docs/benchmarks"
    rows = read_rows(raw_path)
    summary = summarize(rows)
    write_summary_csv(summary, os.path.join(os.path.dirname(raw_path), "apple-arm64-otp28-summary.csv"))
    svg_chart(summary, rows, os.path.join(out_dir, "throughput.svg"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
