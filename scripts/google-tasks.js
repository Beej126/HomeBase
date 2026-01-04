// Auto-click the main menu to expand the sidebar
console.log('Google Tasks script loaded');

function tryClickMenu(attempts = 0) {
    console.log(`Attempt ${attempts + 1}: Looking for Main menu button...`);
    const menuButton = document.querySelector('[aria-label="Main menu"]');
    
    if (menuButton) {
        menuButton.click();
        console.log('✓ Clicked Main menu button');
        return true;
    } else {
        console.log('Main menu button not found');
        if (attempts < 10) {
            setTimeout(() => tryClickMenu(attempts + 1), 500);
        } else {
            console.log('Gave up after 10 attempts');
        }
        return false;
    }
}

// Start trying after a short delay
const intervalHandle = setInterval(() => {
    console.log('Starting menu click attempts...');
    if (tryClickMenu()) clearInterval(intervalHandle);
}, 100);
