# Web Browser Guidance

When a task needs internet access or live page interaction:

- Use `web_search` first when you need to find a page or compare sources.
- Use `web_open_url` to visit a specific site and keep the browser session alive.
- Use `web_page_text`, `web_extract_links`, and `web_page_html` to read what the page actually contains.
- Use `web_click`, `web_click_text`, `web_fill`, `web_press`, and `web_scroll` for interactive sites.
- Use `web_wait_for_selector` or `web_wait_for_text` before assuming a dynamic page has finished loading.
- Use `web_screenshot` when visual confirmation matters.
- Prefer the browser MCP over guessing from memory when the answer depends on current web content.