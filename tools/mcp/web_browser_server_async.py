from __future__ import annotations

import asyncio
import atexit
import base64
import json
import re
import xml.etree.ElementTree as ElementTree
import threading
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qs, quote_plus, urlparse
from urllib.request import Request, urlopen

from mcp.server.fastmcp import FastMCP
from playwright.async_api import Browser
from playwright.async_api import BrowserContext
from playwright.async_api import Error as PlaywrightError
from playwright.async_api import Page
from playwright.async_api import Playwright
from playwright.async_api import TimeoutError as PlaywrightTimeoutError
from playwright.async_api import async_playwright


PROJECT_NAME = "Web Browser Helper"
DEFAULT_TIMEOUT_SECONDS = 30
DEFAULT_WORKSPACE_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SCREENSHOT_DIR_NAME = ".mcp/web_browser/screenshots"
DEFAULT_VIEWPORT_WIDTH = 1440
DEFAULT_VIEWPORT_HEIGHT = 1600

mcp = FastMCP(PROJECT_NAME)


def resolve_workspace_root(project_root: str | None) -> Path:
    workspace_root = Path(project_root).expanduser().resolve() if project_root else DEFAULT_WORKSPACE_ROOT
    if not workspace_root.exists():
        raise FileNotFoundError(f"Project root does not exist: {workspace_root}")
    return workspace_root


def sanitize_filename_component(value: str, fallback: str = "item") -> str:
    sanitized = re.sub(r"[^A-Za-z0-9._-]+", "_", value.strip())
    sanitized = sanitized.strip("._-")
    return sanitized or fallback


def truncate_text(text: str, limit: int = 12000) -> str:
    if len(text) <= limit:
        return text
    return text[:limit] + "\n... [truncated]"


def normalize_url(url: str) -> str:
    value = url.strip()
    if not value:
        raise ValueError("url cannot be empty")
    parsed = urlparse(value)
    if not parsed.scheme:
        return f"https://{value}"
    return value


def build_output_path(workspace_root: Path, page_title: str, output_path: str | None) -> Path:
    if output_path is not None:
        target_path = Path(output_path).expanduser()
        if not target_path.is_absolute():
            target_path = workspace_root / target_path
    else:
        screenshots_dir = workspace_root / DEFAULT_SCREENSHOT_DIR_NAME
        timestamp = time.strftime("%Y%m%d-%H%M%S")
        safe_title = sanitize_filename_component(page_title)[:48]
        target_path = screenshots_dir / f"{timestamp}-{safe_title}.png"

    target_path.parent.mkdir(parents=True, exist_ok=True)
    return target_path


def decode_bing_redirect_url(href: str) -> str:
    parsed = urlparse(href)
    if "bing.com" not in parsed.netloc or "/ck/a" not in parsed.path:
        return href

    query_parameters = parse_qs(parsed.query)
    encoded_target = query_parameters.get("u", [""])[0]
    if encoded_target.startswith(("a1", "a2")):
        encoded_target = encoded_target[2:]

    if not encoded_target:
        return href

    padding = "=" * (-len(encoded_target) % 4)
    try:
        decoded_bytes = base64.urlsafe_b64decode((encoded_target + padding).encode("ascii"))
        decoded_target = decoded_bytes.decode("utf-8", errors="replace")
    except Exception:  # noqa: BLE001
        return href

    return decoded_target if decoded_target.startswith(("http://", "https://")) else href


SEARCH_QUERY_VARIANT_STOP_WORDS = {
    "doc",
    "docs",
    "documentation",
    "example",
    "examples",
    "fix",
    "fixes",
    "getting",
    "guide",
    "guides",
    "how",
    "a",
    "an",
    "and",
    "for",
    "from",
    "in",
    "install",
    "installation",
    "issue",
    "issues",
    "learn",
    "problem",
    "problems",
    "of",
    "on",
    "or",
    "setup",
    "start",
    "started",
    "the",
    "to",
    "tutorial",
    "tutorials",
    "with",
    "use",
    "usage",
    "using",
    "error",
    "errors",
}


SEARCH_QUERY_SITE_HINTS: tuple[tuple[str, str], ...] = (
    ("firebase", "site:firebase.google.com/docs"),
    ("flutter", "site:docs.flutter.dev"),
    ("playwright", "site:playwright.dev"),
    ("dart", "site:dart.dev"),
)

SEARCH_QUERY_SITE_DOMAINS: dict[str, set[str]] = {
    "site:firebase.google.com/docs": {"firebase.google.com"},
    "site:docs.flutter.dev": {"docs.flutter.dev"},
    "site:playwright.dev": {"playwright.dev"},
    "site:dart.dev": {"dart.dev"},
}


def normalize_search_query(query: str) -> str:
    return " ".join(query.split()).strip()


def build_search_query_variants(query: str, limit: int = 4) -> list[str]:
    normalized_query = normalize_search_query(query)
    if not normalized_query:
        return []

    variants: list[str] = []
    seen: set[str] = set()

    def add(candidate: str) -> None:
        normalized_candidate = normalize_search_query(candidate)
        if not normalized_candidate or normalized_candidate in seen:
            return
        seen.add(normalized_candidate)
        variants.append(normalized_candidate)

    def is_stop_word(token: str) -> bool:
        normalized_token = re.sub(r'^[^\w+#.-]+|[^\w+#.-]+$', '', token).lower()
        return normalized_token in SEARCH_QUERY_VARIANT_STOP_WORDS

    tokens = normalized_query.split()
    trimmed_tokens = [token for token in tokens if not is_stop_word(token)]
    trimmed_query = " ".join(trimmed_tokens)

    lower_query = normalized_query.casefold()
    for keyword, site_hint in SEARCH_QUERY_SITE_HINTS:
        if keyword in lower_query:
            if trimmed_query:
                add(f"{site_hint} {trimmed_query}")
            if normalized_query != trimmed_query:
                add(f"{site_hint} {normalized_query}")

    if trimmed_query and trimmed_query != normalized_query:
        add(trimmed_query)

    add(normalized_query)

    for end_index in range(len(tokens) - 1, 0, -1):
        add(" ".join(tokens[:end_index]))

    return variants[:limit]


def get_allowed_result_domains(search_query: str) -> set[str]:
    allowed_domains: set[str] = set()
    lower_query = search_query.casefold()
    for site_hint, domains in SEARCH_QUERY_SITE_DOMAINS.items():
        if site_hint in lower_query:
            allowed_domains.update(domains)
    return allowed_domains


def href_matches_allowed_domains(href: str, allowed_domains: set[str]) -> bool:
    if not allowed_domains:
        return True

    parsed_href = urlparse(href)
    netloc = parsed_href.netloc.casefold()
    return any(netloc == domain or netloc.endswith(f".{domain}") for domain in allowed_domains)


def fetch_bing_rss_results(
    search_query: str,
    timeout_seconds: int,
    max_results: int,
    allowed_domains: set[str] | None = None,
) -> tuple[str, list[dict[str, str]]]:
    search_url = f"https://www.bing.com/search?format=rss&q={quote_plus(search_query)}"
    request = Request(search_url, headers={"User-Agent": "Mozilla/5.0"})

    try:
        with urlopen(request, timeout=timeout_seconds) as response:  # noqa: S310
            rss_text = response.read().decode("utf-8", errors="replace")
    except (HTTPError, URLError, TimeoutError, OSError):
        return search_url, []

    try:
        root = ElementTree.fromstring(rss_text)
    except ElementTree.ParseError:
        return search_url, []

    channel = root.find("channel")
    if channel is None:
        return search_url, []

    results: list[dict[str, str]] = []
    seen: set[str] = set()
    for item in channel.findall("item"):
        text = (item.findtext("title") or "").strip()
        href = decode_bing_redirect_url((item.findtext("link") or "").strip())
        if not text or not href:
            continue
        parsed_href = urlparse(href)
        if parsed_href.scheme not in {"http", "https"}:
            continue
        if "bing.com" in parsed_href.netloc:
            continue
        if allowed_domains and not href_matches_allowed_domains(href, allowed_domains):
            continue
        if href in seen:
            continue
        seen.add(href)
        results.append({"text": text, "href": href})
        if len(results) >= max_results:
            break

    return search_url, results


async def fetch_bing_search_results(
    session: "WebBrowserSession",
    search_query: str,
    timeout_seconds: int,
    max_results: int,
    allowed_domains: set[str] | None = None,
) -> tuple[str, Page, list[dict[str, str]]]:
    search_url = f"https://www.bing.com/search?q={quote_plus(search_query)}"
    page = await session.open_url(search_url, wait_until="domcontentloaded", timeout_seconds=timeout_seconds)

    try:
        await page.wait_for_selector("li.b_algo h2 a", timeout=timeout_seconds * 1000)
    except PlaywrightTimeoutError:
        pass

    raw_results = await page.locator("li.b_algo h2 a").evaluate_all(
        """
        elements => elements.map(el => ({
          text: (el.innerText || el.textContent || '').trim(),
          href: el.href || '',
        }))
        """
    )

    filtered_results: list[dict[str, str]] = []
    seen: set[str] = set()
    for item in raw_results:
        if not isinstance(item, dict):
            continue
        text = str(item.get("text", "")).strip()
        href = decode_bing_redirect_url(str(item.get("href", "")).strip())
        if not text or not href:
            continue
        if href in seen:
            continue
        parsed_href = urlparse(href)
        if "bing.com" in parsed_href.netloc:
            continue
        if allowed_domains and not href_matches_allowed_domains(href, allowed_domains):
            continue
        seen.add(href)
        filtered_results.append({"text": text, "href": href})
        if len(filtered_results) >= max_results:
            break

    if not filtered_results:
        fallback_links = await session.extract_links(limit=max_results * 10)
        for item in fallback_links:
            href = str(item.get("href", "")).strip()
            if not href:
                continue
            parsed_href = urlparse(href)
            if "bing.com" in parsed_href.netloc:
                continue
            if href in seen:
                continue
            seen.add(href)
            filtered_results.append(item)
            if len(filtered_results) >= max_results:
                break

    return search_url, page, filtered_results


def format_json_block(title: str, workspace_root: Path, session: "WebBrowserSession", payload: Any) -> str:
    body = json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True, default=str)
    return format_text_block(title, workspace_root, session, body)


def format_text_block(title: str, workspace_root: Path, session: "WebBrowserSession", body: str) -> str:
    parts = [
        title,
        f"Workspace root: {workspace_root}",
        f"Browser: {session.browser_name}",
        f"Headless: {'yes' if session.headless else 'no'}",
        "",
        body,
    ]
    return "\n".join(parts)


def format_page_summary(page_title: str, page_url: str, workspace_root: Path, session: "WebBrowserSession", note: str | None = None) -> str:
    parts = [
        "Web browser session",
        f"Workspace root: {workspace_root}",
        f"Page title: {page_title}",
        f"Page url: {page_url}",
        f"Browser: {session.browser_name}",
        f"Headless: {'yes' if session.headless else 'no'}",
    ]
    if note:
        parts.append(note)
    if session.last_error:
        parts.append(f"Last error: {session.last_error}")
    return "\n".join(parts)


@dataclass
class WebBrowserSession:
    workspace_root: Path
    headless: bool = True
    browser_name: str = "chromium"
    viewport_width: int = DEFAULT_VIEWPORT_WIDTH
    viewport_height: int = DEFAULT_VIEWPORT_HEIGHT
    playwright: Playwright | None = None
    browser: Browser | None = None
    context: BrowserContext | None = None
    page: Page | None = None
    last_error: str | None = None
    created_at: float = field(default_factory=time.time)

    async def ensure_browser(self) -> None:
        if self.browser is not None and not self.browser.is_connected():
            await self.close()

        if self.browser is not None:
            return

        self.playwright = await async_playwright().start()
        browser_kind = self.browser_name.strip().lower()
        launch_kwargs: dict[str, Any] = {"headless": self.headless}

        try:
            if browser_kind == "firefox":
                self.browser = await self.playwright.firefox.launch(**launch_kwargs)
            elif browser_kind == "webkit":
                self.browser = await self.playwright.webkit.launch(**launch_kwargs)
            else:
                if browser_kind in {"chrome", "msedge", "edge"}:
                    launch_kwargs["channel"] = self.browser_name
                elif browser_kind not in {"chromium", "chrome", "msedge", "edge"}:
                    launch_kwargs["channel"] = self.browser_name
                self.browser = await self.playwright.chromium.launch(**launch_kwargs)
        except Exception as error:  # noqa: BLE001
            self.last_error = str(error)
            if self.playwright is not None:
                await self.playwright.stop()
                self.playwright = None
            raise

        self.context = await self.browser.new_context(
            viewport={"width": self.viewport_width, "height": self.viewport_height},
            ignore_https_errors=True,
        )
        self.context.set_default_timeout(DEFAULT_TIMEOUT_SECONDS * 1000)
        self.context.set_default_navigation_timeout(DEFAULT_TIMEOUT_SECONDS * 1000)
        self.page = await self.context.new_page()

    async def ensure_page(self) -> Page:
        await self.ensure_browser()
        if self.context is None:
            raise RuntimeError("Browser context is not available.")

        if self.page is None or self.page.is_closed():
            self.page = await self.context.new_page()

        return self.page

    async def page_info(self) -> dict[str, Any]:
        page = await self.ensure_page()
        return {
            "title": await page.title(),
            "url": page.url,
            "browser": self.browser_name,
            "headless": self.headless,
            "viewport": {"width": self.viewport_width, "height": self.viewport_height},
        }

    async def summary(self) -> str:
        page_title = "<no page>"
        page_url = "<no page>"
        if self.page is not None and not self.page.is_closed():
            try:
                page_title = await self.page.title()
            except PlaywrightError:
                page_title = "<unavailable>"
            page_url = self.page.url

        parts = [
            "Web browser session",
            f"Workspace root: {self.workspace_root}",
            f"Browser: {self.browser_name}",
            f"Headless: {'yes' if self.headless else 'no'}",
            f"Page title: {page_title}",
            f"Page url: {page_url}",
            f"Created: {time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(self.created_at))}",
        ]
        if self.last_error:
            parts.append(f"Last error: {self.last_error}")
        if self.browser is None:
            parts.append("Browser: not started")
        return "\n".join(parts)

    async def open_url(self, url: str, wait_until: str = "domcontentloaded", timeout_seconds: int = DEFAULT_TIMEOUT_SECONDS) -> Page:
        page = await self.ensure_page()
        resolved_url = normalize_url(url)
        await page.goto(resolved_url, wait_until=wait_until, timeout=timeout_seconds * 1000)
        return page

    async def page_text(self, selector: str = "body", timeout_seconds: int = DEFAULT_TIMEOUT_SECONDS) -> str:
        page = await self.ensure_page()
        locator = page.locator(selector)
        text = await locator.inner_text(timeout=timeout_seconds * 1000)
        return text.strip()

    async def page_html(self) -> str:
        page = await self.ensure_page()
        return (await page.content()).strip()

    async def click(self, locator: str, timeout_seconds: int = DEFAULT_TIMEOUT_SECONDS) -> None:
        page = await self.ensure_page()
        await page.locator(locator).first.click(timeout=timeout_seconds * 1000)

    async def click_text(self, text: str, exact: bool = False, timeout_seconds: int = DEFAULT_TIMEOUT_SECONDS) -> None:
        page = await self.ensure_page()
        await page.get_by_text(text, exact=exact).first.click(timeout=timeout_seconds * 1000)

    async def fill(self, locator: str, value: str, timeout_seconds: int = DEFAULT_TIMEOUT_SECONDS) -> None:
        page = await self.ensure_page()
        await page.locator(locator).first.fill(value, timeout=timeout_seconds * 1000)

    async def type_text(self, locator: str, value: str, delay_ms: int = 0, timeout_seconds: int = DEFAULT_TIMEOUT_SECONDS) -> None:
        page = await self.ensure_page()
        await page.locator(locator).first.type(value, delay=delay_ms, timeout=timeout_seconds * 1000)

    async def press(self, key: str) -> None:
        page = await self.ensure_page()
        await page.keyboard.press(key)

    async def scroll(self, delta_x: int = 0, delta_y: int = 900) -> None:
        page = await self.ensure_page()
        await page.mouse.wheel(delta_x, delta_y)

    async def wait_for_selector(self, selector: str, timeout_seconds: int = DEFAULT_TIMEOUT_SECONDS) -> None:
        page = await self.ensure_page()
        await page.wait_for_selector(selector, timeout=timeout_seconds * 1000)

    async def wait_for_text(self, text: str, timeout_seconds: int = DEFAULT_TIMEOUT_SECONDS, exact: bool = False) -> None:
        page = await self.ensure_page()
        await page.get_by_text(text, exact=exact).first.wait_for(timeout=timeout_seconds * 1000)

    async def extract_links(self, limit: int = 20) -> list[dict[str, str]]:
        page = await self.ensure_page()
        raw_links = await page.locator("a[href]").evaluate_all(
            """
            elements => elements.map(el => ({
              text: (el.innerText || el.textContent || '').trim(),
              href: el.href || '',
            }))
            """
        )

        seen: set[str] = set()
        links: list[dict[str, str]] = []
        for item in raw_links:
            if not isinstance(item, dict):
                continue
            text = str(item.get("text", "")).strip()
            href = decode_bing_redirect_url(str(item.get("href", "")).strip())
            if not text or not href:
                continue
            parsed = urlparse(href)
            if parsed.scheme not in {"http", "https"}:
                continue
            if href in seen:
                continue
            seen.add(href)
            links.append({"text": text, "href": href})
            if len(links) >= limit:
                break
        return links

    async def screenshot(self, output_path: str | None = None, full_page: bool = True) -> Path:
        page = await self.ensure_page()
        page_title = await page.title()
        target_path = build_output_path(self.workspace_root, page_title, output_path)
        await page.screenshot(path=str(target_path), full_page=full_page)
        return target_path

    async def back(self, timeout_seconds: int = DEFAULT_TIMEOUT_SECONDS) -> None:
        page = await self.ensure_page()
        await page.go_back(wait_until="domcontentloaded", timeout=timeout_seconds * 1000)

    async def forward(self, timeout_seconds: int = DEFAULT_TIMEOUT_SECONDS) -> None:
        page = await self.ensure_page()
        await page.go_forward(wait_until="domcontentloaded", timeout=timeout_seconds * 1000)

    async def reload(self, timeout_seconds: int = DEFAULT_TIMEOUT_SECONDS) -> None:
        page = await self.ensure_page()
        await page.reload(wait_until="domcontentloaded", timeout=timeout_seconds * 1000)

    async def close(self) -> str:
        page_closed = False
        context_closed = False
        browser_closed = False

        if self.page is not None:
            try:
                if not self.page.is_closed():
                    await self.page.close()
                    page_closed = True
            except PlaywrightError:
                pass
            self.page = None

        if self.context is not None:
            try:
                await self.context.close()
                context_closed = True
            except PlaywrightError:
                pass
            self.context = None

        if self.browser is not None:
            try:
                await self.browser.close()
                browser_closed = True
            except PlaywrightError:
                pass
            self.browser = None

        if self.playwright is not None:
            try:
                await self.playwright.stop()
            except PlaywrightError:
                pass
            self.playwright = None

        return json.dumps(
            {
                "browser_closed": browser_closed,
                "context_closed": context_closed,
                "page_closed": page_closed,
            },
            ensure_ascii=False,
            indent=2,
            sort_keys=True,
        )


_SESSION_LOCK = threading.RLock()
_SESSIONS: dict[str, WebBrowserSession] = {}


def workspace_key(workspace_root: Path) -> str:
    return str(workspace_root.resolve())


def get_session(workspace_root: Path) -> WebBrowserSession | None:
    key = workspace_key(workspace_root)
    with _SESSION_LOCK:
        return _SESSIONS.get(key)


def store_session(workspace_root: Path, session: WebBrowserSession) -> None:
    with _SESSION_LOCK:
        _SESSIONS[workspace_key(workspace_root)] = session


def remove_session(workspace_root: Path, session: WebBrowserSession | None = None) -> None:
    key = workspace_key(workspace_root)
    with _SESSION_LOCK:
        if session is None:
            _SESSIONS.pop(key, None)
            return
        current = _SESSIONS.get(key)
        if current is session:
            _SESSIONS.pop(key, None)


def get_or_create_session(
    project_root: str | None,
    headless: bool = True,
    browser_name: str = "chromium",
    viewport_width: int = DEFAULT_VIEWPORT_WIDTH,
    viewport_height: int = DEFAULT_VIEWPORT_HEIGHT,
) -> tuple[Path, WebBrowserSession]:
    workspace_root = resolve_workspace_root(project_root)

    with _SESSION_LOCK:
        session = _SESSIONS.get(workspace_key(workspace_root))
        if session is None:
            session = WebBrowserSession(
                workspace_root=workspace_root,
                headless=headless,
                browser_name=browser_name,
                viewport_width=viewport_width,
                viewport_height=viewport_height,
            )
            _SESSIONS[workspace_key(workspace_root)] = session

    return workspace_root, session


def session_or_error(project_root: str | None) -> tuple[Path, WebBrowserSession] | str:
    workspace_root = resolve_workspace_root(project_root)
    session = get_session(workspace_root)
    if session is None:
        return f"No active browser session for {workspace_root}. Start one with web_open_url or web_search first."
    return workspace_root, session


async def close_all_sessions() -> None:
    with _SESSION_LOCK:
        sessions = list(_SESSIONS.values())
        _SESSIONS.clear()

    for session in sessions:
        try:
            await session.close()
        except Exception:  # noqa: BLE001
            pass


def close_all_sessions_sync() -> None:
    try:
        asyncio.run(close_all_sessions())
    except RuntimeError:
        pass


atexit.register(close_all_sessions_sync)


@mcp.tool()
async def web_session_status(project_root: str | None = None) -> str:
    """Return the current browser session status."""
    workspace_root = resolve_workspace_root(project_root)
    session = get_session(workspace_root)
    if session is None:
        return f"No active browser session for {workspace_root}."

    return await session.summary()


@mcp.tool()
async def web_open_url(
    url: str,
    project_root: str | None = None,
    headless: bool = True,
    browser_name: str = "chromium",
    wait_until: str = "domcontentloaded",
    timeout_seconds: int = DEFAULT_TIMEOUT_SECONDS,
) -> str:
    """Open a URL in a persistent Playwright session."""
    workspace_root, session = get_or_create_session(
        project_root,
        headless=headless,
        browser_name=browser_name,
    )

    page = await session.open_url(url, wait_until=wait_until, timeout_seconds=timeout_seconds)
    return format_page_summary(await page.title(), page.url, workspace_root, session, note=f"Opened {normalize_url(url)}")


@mcp.tool()
async def web_search(
    query: str,
    project_root: str | None = None,
    headless: bool = True,
    browser_name: str = "chromium",
    timeout_seconds: int = DEFAULT_TIMEOUT_SECONDS,
    max_results: int = 10,
) -> str:
    """Search the web via Bing and return the top result links.

    The search prefers Bing RSS first because it is faster and less fragile than rendering the
    full search page. If RSS returns nothing useful, it falls back to a short Playwright query and
    broadens the query only if needed.
    """
    workspace_root, session = get_or_create_session(
        project_root,
        headless=headless,
        browser_name=browser_name,
    )

    attempt_timeout_seconds = max(4, min(timeout_seconds, 8))
    search_attempts: list[dict[str, Any]] = []
    filtered_results: list[dict[str, str]] = []
    page_title = f"Bing: {normalize_search_query(query)}"
    page_url = f"https://www.bing.com/search?format=rss&q={quote_plus(normalize_search_query(query))}"
    search_url = ""
    effective_query = normalize_search_query(query)

    for search_query in build_search_query_variants(query, limit=3):
        allowed_domains = get_allowed_result_domains(search_query)
        search_url, filtered_results = await asyncio.to_thread(
            fetch_bing_rss_results,
            search_query,
            attempt_timeout_seconds,
            max_results,
            allowed_domains,
        )
        search_attempts.append(
            {
                "query": search_query,
                "mode": "rss",
                "result_count": len(filtered_results),
                "search_url": search_url,
            }
        )
        effective_query = search_query
        if filtered_results:
            page_title = f"Bing RSS: {search_query}"
            page_url = search_url
            break

    if not filtered_results:
        for search_query in build_search_query_variants(query, limit=2):
            allowed_domains = get_allowed_result_domains(search_query)
            search_url, page, filtered_results = await fetch_bing_search_results(
                session,
                search_query,
                attempt_timeout_seconds,
                max_results,
                allowed_domains,
            )
            search_attempts.append(
                {
                    "query": search_query,
                    "mode": "browser",
                    "result_count": len(filtered_results),
                    "search_url": search_url,
                }
            )
            effective_query = search_query
            page_title = await page.title()
            page_url = page.url
            if filtered_results:
                break

    payload = {
        "query": query,
        "effective_query": effective_query,
        "search_attempts": search_attempts,
        "search_url": search_url,
        "page_title": page_title,
        "page_url": page_url,
        "results": filtered_results,
    }
    return format_json_block("Web search results", workspace_root, session, payload)


@mcp.tool()
async def web_page_info(project_root: str | None = None) -> str:
    """Return basic information about the current page."""
    session_context = session_or_error(project_root)
    if isinstance(session_context, str):
        return session_context

    workspace_root, session = session_context
    info = await session.page_info()
    return format_json_block("Web page info", workspace_root, session, info)


@mcp.tool()
async def web_page_text(
    selector: str = "body",
    project_root: str | None = None,
    max_chars: int = 12000,
    timeout_seconds: int = DEFAULT_TIMEOUT_SECONDS,
) -> str:
    """Return visible text from the current page or a selector."""
    session_context = session_or_error(project_root)
    if isinstance(session_context, str):
        return session_context

    workspace_root, session = session_context
    text = await session.page_text(selector=selector, timeout_seconds=timeout_seconds)
    return format_text_block(
        f"Web page text for selector: {selector}",
        workspace_root,
        session,
        truncate_text(text, max_chars),
    )


@mcp.tool()
async def web_page_html(
    project_root: str | None = None,
    max_chars: int = 12000,
) -> str:
    """Return the current page HTML."""
    session_context = session_or_error(project_root)
    if isinstance(session_context, str):
        return session_context

    workspace_root, session = session_context
    html = await session.page_html()
    return format_text_block("Web page HTML", workspace_root, session, truncate_text(html, max_chars))


@mcp.tool()
async def web_click(
    locator: str,
    project_root: str | None = None,
    timeout_seconds: int = DEFAULT_TIMEOUT_SECONDS,
) -> str:
    """Click an element using a Playwright locator expression."""
    session_context = session_or_error(project_root)
    if isinstance(session_context, str):
        return session_context

    workspace_root, session = session_context
    await session.click(locator, timeout_seconds=timeout_seconds)
    info = await session.page_info()
    return format_page_summary(info["title"], info["url"], workspace_root, session, note=f"Clicked locator: {locator}")


@mcp.tool()
async def web_click_text(
    text: str,
    project_root: str | None = None,
    exact: bool = False,
    timeout_seconds: int = DEFAULT_TIMEOUT_SECONDS,
) -> str:
    """Click the first element matching visible text."""
    session_context = session_or_error(project_root)
    if isinstance(session_context, str):
        return session_context

    workspace_root, session = session_context
    await session.click_text(text, exact=exact, timeout_seconds=timeout_seconds)
    info = await session.page_info()
    return format_page_summary(info["title"], info["url"], workspace_root, session, note=f"Clicked text: {text}")


@mcp.tool()
async def web_fill(
    locator: str,
    value: str,
    project_root: str | None = None,
    timeout_seconds: int = DEFAULT_TIMEOUT_SECONDS,
) -> str:
    """Fill an input using a Playwright locator expression."""
    session_context = session_or_error(project_root)
    if isinstance(session_context, str):
        return session_context

    workspace_root, session = session_context
    await session.fill(locator, value, timeout_seconds=timeout_seconds)
    info = await session.page_info()
    return format_page_summary(info["title"], info["url"], workspace_root, session, note=f"Filled locator: {locator}")


@mcp.tool()
async def web_type(
    locator: str,
    value: str,
    project_root: str | None = None,
    delay_ms: int = 0,
    timeout_seconds: int = DEFAULT_TIMEOUT_SECONDS,
) -> str:
    """Type text into an input using a Playwright locator expression."""
    session_context = session_or_error(project_root)
    if isinstance(session_context, str):
        return session_context

    workspace_root, session = session_context
    await session.type_text(locator, value, delay_ms=delay_ms, timeout_seconds=timeout_seconds)
    info = await session.page_info()
    return format_page_summary(info["title"], info["url"], workspace_root, session, note=f"Typed into locator: {locator}")


@mcp.tool()
async def web_press(key: str, project_root: str | None = None) -> str:
    """Press a keyboard key or shortcut on the current page."""
    session_context = session_or_error(project_root)
    if isinstance(session_context, str):
        return session_context

    workspace_root, session = session_context
    await session.press(key)
    info = await session.page_info()
    return format_page_summary(info["title"], info["url"], workspace_root, session, note=f"Pressed key: {key}")


@mcp.tool()
async def web_scroll(
    delta_y: int = 900,
    delta_x: int = 0,
    project_root: str | None = None,
) -> str:
    """Scroll the current page."""
    session_context = session_or_error(project_root)
    if isinstance(session_context, str):
        return session_context

    workspace_root, session = session_context
    await session.scroll(delta_x=delta_x, delta_y=delta_y)
    info = await session.page_info()
    return format_page_summary(info["title"], info["url"], workspace_root, session, note=f"Scrolled dx={delta_x}, dy={delta_y}")


@mcp.tool()
async def web_wait_for_selector(
    selector: str,
    project_root: str | None = None,
    timeout_seconds: int = DEFAULT_TIMEOUT_SECONDS,
) -> str:
    """Wait for a selector to appear on the current page."""
    session_context = session_or_error(project_root)
    if isinstance(session_context, str):
        return session_context

    workspace_root, session = session_context
    await session.wait_for_selector(selector, timeout_seconds=timeout_seconds)
    info = await session.page_info()
    return format_page_summary(info["title"], info["url"], workspace_root, session, note=f"Selector ready: {selector}")


@mcp.tool()
async def web_wait_for_text(
    text: str,
    project_root: str | None = None,
    exact: bool = False,
    timeout_seconds: int = DEFAULT_TIMEOUT_SECONDS,
) -> str:
    """Wait for text to appear on the current page."""
    session_context = session_or_error(project_root)
    if isinstance(session_context, str):
        return session_context

    workspace_root, session = session_context
    await session.wait_for_text(text, timeout_seconds=timeout_seconds, exact=exact)
    info = await session.page_info()
    return format_page_summary(info["title"], info["url"], workspace_root, session, note=f"Text ready: {text}")


@mcp.tool()
async def web_extract_links(
    project_root: str | None = None,
    limit: int = 20,
) -> str:
    """Return a JSON list of links from the current page."""
    session_context = session_or_error(project_root)
    if isinstance(session_context, str):
        return session_context

    workspace_root, session = session_context
    links = await session.extract_links(limit=limit)
    return format_json_block("Web page links", workspace_root, session, {"links": links})


@mcp.tool()
async def web_screenshot(
    project_root: str | None = None,
    output_path: str | None = None,
    full_page: bool = True,
) -> str:
    """Capture a PNG screenshot of the current page."""
    session_context = session_or_error(project_root)
    if isinstance(session_context, str):
        return session_context

    workspace_root, session = session_context
    screenshot_path = await session.screenshot(output_path=output_path, full_page=full_page)
    info = await session.page_info()
    return format_page_summary(
        info["title"],
        info["url"],
        workspace_root,
        session,
        note=f"Screenshot saved to: {screenshot_path}",
    )


@mcp.tool()
async def web_back(project_root: str | None = None, timeout_seconds: int = DEFAULT_TIMEOUT_SECONDS) -> str:
    """Navigate back in the current browser history."""
    session_context = session_or_error(project_root)
    if isinstance(session_context, str):
        return session_context

    workspace_root, session = session_context
    await session.back(timeout_seconds=timeout_seconds)
    info = await session.page_info()
    return format_page_summary(info["title"], info["url"], workspace_root, session, note="Navigated back")


@mcp.tool()
async def web_forward(project_root: str | None = None, timeout_seconds: int = DEFAULT_TIMEOUT_SECONDS) -> str:
    """Navigate forward in the current browser history."""
    session_context = session_or_error(project_root)
    if isinstance(session_context, str):
        return session_context

    workspace_root, session = session_context
    await session.forward(timeout_seconds=timeout_seconds)
    info = await session.page_info()
    return format_page_summary(info["title"], info["url"], workspace_root, session, note="Navigated forward")


@mcp.tool()
async def web_reload(project_root: str | None = None, timeout_seconds: int = DEFAULT_TIMEOUT_SECONDS) -> str:
    """Reload the current page."""
    session_context = session_or_error(project_root)
    if isinstance(session_context, str):
        return session_context

    workspace_root, session = session_context
    await session.reload(timeout_seconds=timeout_seconds)
    info = await session.page_info()
    return format_page_summary(info["title"], info["url"], workspace_root, session, note="Reloaded page")


@mcp.tool()
async def web_close(project_root: str | None = None) -> str:
    """Close the current browser session."""
    workspace_root = resolve_workspace_root(project_root)
    session = get_session(workspace_root)
    if session is None:
        return f"No active browser session for {workspace_root}."

    summary = await session.close()
    remove_session(workspace_root, session)
    return f"Browser session closed.\n{summary}"


if __name__ == "__main__":
    mcp.run()
