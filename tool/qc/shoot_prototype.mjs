// Screenshot every prototype screen at device-pixel parity (390x844 @2x).
import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';

const BASE = 'http://127.0.0.1:8787/Medibook%20App.dc.html';
const OUT = '/tmp/claude-0/-home-claude/041cf55d-8a3e-5ae8-a8cb-1e4e23d9fc61/scratchpad/shots/proto';

// Jump-menu labels -> output names (menu defined in the prototype's `jumps`).
const SCREENS = [
  ['Login', 'login'], ['Sign Up', 'signup'], ['Forgot', 'forgot'],
  ['Verify', 'verify'], ['New Password', 'reset'], ['Home', 'home'],
  ['Search', 'search'], ['Notifications', 'notifications'],
  ['Booking', 'booking_step1'], ['Doctor', 'doctor'],
  ['Appointments', 'appointments'], ['Appt Detail', 'appt_detail'],
  ['Reschedule', 'reschedule'], ['Records', 'records'], ['Profile', 'profile'],
];

const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
const page = await browser.newPage({ viewport: { width: 700, height: 1000 }, deviceScaleFactor: 2 });
page.on('console', m => { if (m.type() === 'error') console.log('[console.error]', m.text()); });
await page.goto(BASE, { waitUntil: 'networkidle' });
await page.waitForTimeout(2500); // fonts + React mount

// The 390x844 device frame is the fixed-size rounded div.
const frame = page.locator('div[style*="width: 390px"][style*="height: 844px"]').first();
await frame.waitFor({ state: 'visible', timeout: 15000 });

for (const [label, name] of SCREENS) {
  const btn = page.locator('button', { hasText: new RegExp(`^${label.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`) }).last();
  await btn.click();
  await page.waitForTimeout(700); // enter animation (220-250ms) + settle
  await frame.screenshot({ path: `${OUT}/${name}.png` });
  console.log('shot', name);
}

// Deeper states: booking steps 2-4 via clicks (General dept -> doctor -> continue).
const clickText = async (t, wait = 600) => { await page.locator(`text=${t}`).last().click(); await page.waitForTimeout(wait); };
try {
  await page.locator('button', { hasText: /^Booking$/ }).last().click();
  await page.waitForTimeout(700);
  await clickText('General');                       // select dept card
  await clickText('Continue');
  await frame.screenshot({ path: `${OUT}/booking_step2.png` });  console.log('shot booking_step2');
  await clickText('Dr. Anil Kumar');                // -> doctor detail
  await clickText('Book an appointment');           // -> step 3 prefilled
  await frame.screenshot({ path: `${OUT}/booking_step3.png` });  console.log('shot booking_step3');
  await clickText('Continue');
  await frame.screenshot({ path: `${OUT}/booking_step4.png` });  console.log('shot booking_step4');
  await clickText('Confirm and Pay', 900);
  await frame.screenshot({ path: `${OUT}/success.png` });        console.log('shot success');
} catch (e) { console.log('deep-flow error:', e.message); }

// Logout sheet on profile.
try {
  await page.locator('button', { hasText: /^Profile$/ }).last().click();
  await page.waitForTimeout(700);
  await clickText('Logout', 800);
  await frame.screenshot({ path: `${OUT}/sheet_logout.png` });   console.log('shot sheet_logout');
} catch (e) { console.log('sheet error:', e.message); }

await browser.close();
console.log('DONE');
