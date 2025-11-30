const TILT_DEGREES = 2;
const RESOURCE_NAME = 'fd-pausemenu';

let pauseMenu = null;
let root = null;
let isMenuActive = false;

document.addEventListener('DOMContentLoaded', () => {
    pauseMenu = document.querySelector('.pausemenu');
    root = document.querySelector('.root');
    
    if (!pauseMenu || !root) {
        console.error('Required elements not found!');
        return;
    }

    setupTiltEffect();

    setupButtonListeners();

    setupKeyboardListener();
});

function setupTiltEffect() {
    let tiltTimeout = null;
    
    pauseMenu.addEventListener('mousemove', (e) => {
        const rect = pauseMenu.getBoundingClientRect();
        const x = (e.clientY - rect.top) / rect.height;
        const y = (e.clientX - rect.left) / rect.width;
        
        const rotX = x * TILT_DEGREES;
        const rotY = y * -TILT_DEGREES;
        
        pauseMenu.style.transform = `rotateX(${rotX}deg) rotateY(${rotY}deg)`;
    });
    
    pauseMenu.addEventListener('mouseleave', () => {
        pauseMenu.style.transform = 'rotateX(0deg) rotateY(0deg)';
    });
}

function setupButtonListeners() {
    const buttons = {
        'continue-btn': 'continue',
        'map-btn': 'map',
        'settings-btn': 'settings',
        'logout-btn': 'logout'
    };
    
    Object.entries(buttons).forEach(([btnId, callback]) => {
        const btn = document.getElementById(btnId);
        if (btn) {
            btn.addEventListener('click', () => sendCallback(callback));
        }
    });
}

function setupKeyboardListener() {
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && isMenuActive) {
            sendCallback('continue');
        }
    });
}

function sendCallback(callback) {
    fetch(`https://${RESOURCE_NAME}/${callback}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    }).catch(err => console.error(`Callback error (${callback}):`, err));
}

function updateLocale(locale) {
    const textMap = {
        'continue-btn': locale.resume,
        'map-btn': locale.map,
        'settings-btn': locale.settings,
        'logout-btn': locale.quit
    };
    
    Object.entries(textMap).forEach(([btnId, text]) => {
        const btn = document.getElementById(btnId);
        if (btn) {
            const icon = btn.querySelector('.button-icon');
            const span = btn.querySelector('span');
            if (span) {
                span.textContent = text;
            }
        }
    });
}

window.addEventListener('message', (event) => {
    const { type, data } = event.data;
    
    switch(type) {
        case 'openMenu':
            openMenu(event.data);
            break;
            
        case 'closeMenu':
            closeMenu();
            break;
            
        case 'updatePosition':
            updateMenuPosition(event.data);
            break;
    }
});

function openMenu(data) {
    if (!root || !pauseMenu) return;
    
    isMenuActive = true;

    const nameElement = document.getElementById('charactername');
    if (nameElement && data.name) {
        nameElement.textContent = data.name;
    }

    if (data.locale) {
        updateLocale(data.locale);
    }

    if (data.x && data.y) {
        pauseMenu.style.left = `${data.x * window.innerWidth}px`;
        pauseMenu.style.top = `${data.y * window.innerHeight}px`;
    }

    root.style.display = 'block';
    requestAnimationFrame(() => {
        root.classList.add('active');
    });
}

function closeMenu() {
    if (!root) return;
    
    isMenuActive = false;
    root.classList.remove('active');

    setTimeout(() => {
        root.style.display = 'none';
    }, 300);
}

function updateMenuPosition(data) {
    if (!pauseMenu || !data.x || !data.y) return;
    
    const x = data.x * window.innerWidth;
    const y = data.y * window.innerHeight;
    
    pauseMenu.style.left = `${x}px`;
    pauseMenu.style.top = `${y}px`;
}
