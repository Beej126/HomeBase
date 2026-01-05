const $_ = selector => document.querySelector(selector);
const $$_ = selector => [...document.querySelectorAll(selector)];

// just constantly try clicking the first "Memories" link after every 2 seconds
setInterval(() => {
    if (!$_('a[aria-label="Back"]')) $_('a[href^="./memory"]')?.click();
}, 2000);