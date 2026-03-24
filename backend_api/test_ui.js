const puppeteer = require('puppeteer');
const fs = require('fs');

(async () => {
  try {
    const browser = await puppeteer.launch({ 
      headless: false,
      args: ['--no-sandbox', '--disable-web-security', '--ignore-certificate-errors', '--window-size=400,800'] 
    });
    const page = await browser.newPage();
    page.on('console', msg => console.log('PAGE LOG:', msg.text()));
    page.on('pageerror', error => console.log('PAGE ERROR:', error.message));
    await page.setViewport({ width: 414, height: 896 });
    console.log("Navigating to app...");
    await page.goto('http://localhost:8083', { waitUntil: 'networkidle2', timeout: 60000 });
    
    // Give Flutter CanvasKit a moment to paint the first frame
    console.log("Waiting for app to paint...");
    await new Promise(r => setTimeout(r, 15000));

    // Try to click anywhere in case it helps wake up the UI
    await page.mouse.click(200, 400);
    await new Promise(r => setTimeout(r, 2000));

    const outPath = 'C:\\Users\\savya\\.gemini\\antigravity\\brain\\bb3d60ac-ee8d-4f98-87d2-ee8d73f95e42\\flutter_feed_2.png';
    await page.screenshot({ path: outPath });
    console.log("Screenshot saved to " + outPath);
    await browser.close();
    process.exit(0);
  } catch (error) {
    console.error("Puppeteer error:", error);
  }
})();
