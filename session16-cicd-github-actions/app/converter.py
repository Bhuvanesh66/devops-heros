"""Pure conversion logic, kept free of Flask so it is easy to unit test."""

# Each length unit expressed in metres.
LENGTH_FACTORS = {
    "mm": 0.001,
    "cm": 0.01,
    "m": 1.0,
    "km": 1000.0,
    "in": 0.0254,
    "ft": 0.3048,
    "mi": 1609.344,
}

# Each mass unit expressed in kilograms.
MASS_FACTORS = {
    "g": 0.001,
    "kg": 1.0,
    "lb": 0.45359237,
    "oz": 0.028349523125,
}

TEMPERATURE_UNITS = ("c", "f", "k")

CATEGORIES = {
    "length": tuple(LENGTH_FACTORS),
    "mass": tuple(MASS_FACTORS),
    "temperature": TEMPERATURE_UNITS,
}

ABSOLUTE_ZERO_C = -273.15


class ConversionError(ValueError):
    """Raised when a conversion request is not valid."""


def _convert_by_factor(value: float, src: str, dst: str, factors: dict) -> float:
    if src not in factors or dst not in factors:
        raise ConversionError(f"unsupported units: {src} -> {dst}")
    return value * factors[src] / factors[dst]


def convert_temperature(value: float, src: str, dst: str) -> float:
    if src not in TEMPERATURE_UNITS or dst not in TEMPERATURE_UNITS:
        raise ConversionError(f"unsupported units: {src} -> {dst}")
    # Normalise to Celsius first.
    if src == "c":
        celsius = value
    elif src == "f":
        celsius = (value - 32) * 5 / 9
    else:
        celsius = value + ABSOLUTE_ZERO_C
    if celsius < ABSOLUTE_ZERO_C - 1e-9:
        raise ConversionError("temperature below absolute zero")
    if dst == "c":
        return celsius
    if dst == "f":
        return celsius * 9 / 5 + 32
    return celsius - ABSOLUTE_ZERO_C


def convert(category: str, value: float, src: str, dst: str) -> float:
    """Convert ``value`` from unit ``src`` to unit ``dst`` within ``category``."""
    category = category.lower()
    src = src.lower()
    dst = dst.lower()
    if category == "length":
        result = _convert_by_factor(value, src, dst, LENGTH_FACTORS)
    elif category == "mass":
        result = _convert_by_factor(value, src, dst, MASS_FACTORS)
    elif category == "temperature":
        result = convert_temperature(value, src, dst)
    else:
        raise ConversionError(f"unknown category: {category}")
    return round(result, 6)
