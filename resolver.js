import { chromium } from 'playwright';

/**
 * Resolves a direct .m3u8 stream link from a given embed URL.
 * @param {string} url - The embed URL to scrape.
 * @param {number} timeout - Maximum time to wait in ms.
 * @returns {Promise<string>} - The captured stream URL.
 */
export const resolveStream = async (url, timeout = 45000) => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
    viewport: { width: 1280, height: 720 },
    deviceScaleFactor: 1,
    hasTouch: false,
    locale: 'en-US',
    timezoneId: 'America/New_York'
  });

  // Mask webdriver
  await context.addInitScript(() => {
    Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
  });

  const page = await context.newPage();

  return new Promise(async (resolve, reject) => {
    let resolved = false;

    // Set a safety timeout
    const timer = setTimeout(async () => {
      if (!resolved) {
        resolved = true;
        try {
          // Take a screenshot before closing on timeout
          await page.screenshot({ path: 'extraction_timeout.png' });
        } catch (sError) {}
        await browser.close().catch(() => {});
        reject(new Error(`Timeout reached after ${timeout/1000}s while waiting for stream link.`));
      }
    }, timeout);

    try {
      // Listen for network requests
      page.on('request', (request) => {
        const reqUrl = request.url();
        // Look for master.m3u8 or large .mp4 links
        if (reqUrl.includes('.m3u8') || (reqUrl.includes('.mp4') && !reqUrl.includes('ads'))) {
          if (!resolved) {
            resolved = true;
            clearTimeout(timer);
            browser.close().then(() => resolve(reqUrl)).catch(() => resolve(reqUrl));
          }
        }
      });

      // Navigate to the page
      // Use networkidle to ensure player scripts are loaded
      await page.goto(url, { waitUntil: 'networkidle', timeout: 60000 });

      // Wait for player to potentially initialize
      await page.waitForTimeout(8000);
      
      const viewport = page.viewportSize() || { width: 1280, height: 720 };
      const center = { x: viewport.width / 2, y: viewport.height / 2 };

      // Log status
      console.log('  Triggering player clicks...');

      // Multi-point clicking strategy
      const clickPoints = [
        { x: center.x, y: center.y },           // Direct center
        { x: center.x + 10, y: center.y + 10 }, // Offset
        { x: center.x - 10, y: center.y - 10 }, // Offset
        { x: center.x, y: center.y }            // Final center
      ];

      for (const point of clickPoints) {
        if (resolved) break;
        await page.mouse.click(point.x, point.y);
        await page.waitForTimeout(2000);
      }

    } catch (error) {
      if (!resolved) {
        resolved = true;
        clearTimeout(timer);
        try {
          // Save screenshot to project dir for debugging
          await page.screenshot({ path: 'extraction_error.png' });
        } catch (sError) {}
        await browser.close().catch(() => {});
        reject(error);
      }
    }
  });
};
