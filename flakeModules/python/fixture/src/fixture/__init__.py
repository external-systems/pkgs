"""flakeModules.python self-test."""

from importlib.metadata import version


def main() -> None:
    """Print `fixture <version>`."""
    print(f"fixture {version('fixture')}")
