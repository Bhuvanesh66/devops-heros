import pytest

from app.converter import ConversionError, convert


@pytest.mark.parametrize(
    ("category", "value", "src", "dst", "expected"),
    [
        ("length", 1, "km", "m", 1000.0),
        ("length", 12, "in", "ft", 1.0),
        ("length", 1, "mi", "km", 1.609344),
        ("mass", 1, "kg", "g", 1000.0),
        ("mass", 16, "oz", "lb", 1.0),
        ("temperature", 100, "c", "f", 212.0),
        ("temperature", 32, "f", "c", 0.0),
        ("temperature", 0, "k", "c", -273.15),
        ("temperature", 0, "c", "k", 273.15),
    ],
)
def test_known_conversions(category, value, src, dst, expected):
    assert convert(category, value, src, dst) == pytest.approx(expected)


def test_same_unit_is_identity():
    assert convert("length", 42.5, "m", "m") == 42.5


def test_units_are_case_insensitive():
    assert convert("LENGTH", 1, "KM", "M") == 1000.0


def test_unknown_category_raises():
    with pytest.raises(ConversionError, match="unknown category"):
        convert("volume", 1, "l", "ml")


def test_unsupported_unit_raises():
    with pytest.raises(ConversionError, match="unsupported units"):
        convert("mass", 1, "kg", "stone")


def test_unsupported_temperature_unit_raises():
    with pytest.raises(ConversionError, match="unsupported units"):
        convert("temperature", 1, "c", "r")


def test_below_absolute_zero_raises():
    with pytest.raises(ConversionError, match="absolute zero"):
        convert("temperature", -500, "c", "k")
