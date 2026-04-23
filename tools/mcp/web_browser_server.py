from pathlib import Path
import sys


sys.path.insert(0, str(Path(__file__).resolve().parent))

from web_browser_server_async import mcp


if __name__ == "__main__":
    mcp.run()
