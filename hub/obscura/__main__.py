"""Entry point: `python -m obscura` serves the hub, `python -m obscura pair` prints a pairing code."""

import logging
import sys

from . import config


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    # httpx logs every request URL at INFO; go2rtc registrations carry camera passwords in theirs.
    logging.getLogger("httpx").setLevel(logging.WARNING)
    settings = config.load()
    if sys.argv[1:] == ["pair"]:
        from .db import Database
        from .hub import new_pairing_code

        code = new_pairing_code(Database(settings.db_path))
        print(f"\n  Pairing code: {code}\n  Valid for 10 minutes, single use.\n")
        return

    import uvicorn

    from .api import create_app

    uvicorn.run(create_app(settings), host=settings.host, port=settings.port,
                proxy_headers=False, server_header=False, log_level="info")


if __name__ == "__main__":
    main()
