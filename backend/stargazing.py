"""
DuDu Stargazing — mundane astrology chart (天象盘) via Stellium.
Current datetime + geographic location, Alcabitus houses, standard preset render → PNG file.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

try:
    from zoneinfo import ZoneInfo
except ImportError:
    ZoneInfo = None  # type: ignore

from settings import SettingsManager

HOUSE_SYSTEM = "Alcabitus"
CHART_PNG = Path(__file__).resolve().parent / "data" / "chart_latest.png"
# ~3× panel preview (340px) — sharp at 1.5× lightbox zoom + HiDPI
CHART_RENDER_WIDTH = 1020

SIGN_ZH = {
    "Aries": "白羊",
    "Taurus": "金牛",
    "Gemini": "双子",
    "Cancer": "巨蟹",
    "Leo": "狮子",
    "Virgo": "处女",
    "Libra": "天秤",
    "Scorpio": "天蝎",
    "Sagittarius": "射手",
    "Capricorn": "摩羯",
    "Aquarius": "水瓶",
    "Pisces": "双鱼",
}


def _tz_dt(tz_name: str) -> datetime:
    if ZoneInfo is not None:
        try:
            return datetime.now(ZoneInfo(tz_name))
        except Exception:
            pass
    return datetime.now(timezone(timedelta(hours=8)))


def _sign_zh(sign_en: str) -> str:
    return SIGN_ZH.get(sign_en, sign_en)


def _render_chart_png(
    dt: datetime,
    lat: float,
    lon: float,
    tz_name: str,
    city: str,
) -> tuple[str, dict[str, Any]]:
    from stellium import ChartBuilder
    from stellium.engines.houses import AlcabitiusHouses
    import resvg_py

    chart = (
        ChartBuilder.from_details(
            dt,
            {
                "latitude": lat,
                "longitude": lon,
                "name": city,
                "timezone": tz_name,
            },
        )
        .with_house_systems([AlcabitiusHouses()])
        .calculate()
    )

    svg_str = chart.draw("standard.svg").preset_standard().save(to_string=True)
    png_bytes = resvg_py.svg_to_bytes(svg_string=svg_str, width=CHART_RENDER_WIDTH)
    CHART_PNG.parent.mkdir(parents=True, exist_ok=True)
    CHART_PNG.write_bytes(png_bytes)

    asc_data: dict[str, Any] = {}
    for angle in chart.get_angles():
        if angle.name == "ASC":
            asc_data = {
                "longitude": round(angle.longitude, 2),
                "sign": angle.sign,
                "sign_zh": _sign_zh(angle.sign),
                "degree": round(angle.sign_degree, 1),
            }
            break

    return CHART_PNG.name, asc_data


class StargazingService:
    """Build mundane astrology chart for current time + location."""

    def __init__(self, settings: SettingsManager):
        self._settings = settings

    def _location(self) -> tuple[float, float, str, str]:
        sg = self._settings.get("stargazing") or {}
        if not isinstance(sg, dict):
            sg = {}
        lat = float(sg.get("latitude") or 31.2304)
        lon = float(sg.get("longitude") or 121.4737)
        tz = str(sg.get("timezone") or "Asia/Shanghai")
        city = str(sg.get("city") or "上海")
        return lat, lon, tz, city

    def build_chart(self) -> dict[str, Any]:
        lat, lon, tz_name, city = self._location()
        dt = _tz_dt(tz_name)

        base: dict[str, Any] = {
            "chart_type": "mundane",
            "house_system": HOUSE_SYSTEM,
            "city": city,
            "latitude": lat,
            "longitude": lon,
            "timezone": tz_name,
            "observed_at": dt.strftime("%y-%m-%d %H:%M"),
        }

        try:
            image_file, asc = _render_chart_png(dt, lat, lon, tz_name, city)
        except Exception as exc:
            print(f"[!] Stellium chart error: {exc}")
            return {**base, "error": str(exc)}

        return {**base, "image_file": image_file, "ascendant": asc}
