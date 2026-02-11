// ==UserScript==
// @name         STF Position Measurement Tool
// @namespace    http://tampermonkey.net/
// @version      1.0
// @description  Outil de mesure de position pour STF - Clic et sélection avec coordonnées en px et %
// @author       DevTools
// @match        http://stf.local/*
// @match        https://stf.local/*
// @match        http://localhost:*/
// @match        https://localhost:*/
// @icon         📏
// @grant        none
// @run-at       document-idle
// ==/UserScript==

/**
 * CONFIGURATION
 * Modifiez la ligne @match ci-dessus pour correspondre à votre URL STF
 * Exemples:
 * @match        http://stf.example.com/*
 * @match        http://192.168.1.100:*/*
 */

(function() {
    'use strict';

    // Configuration
    const CONFIG = {
        buttonPosition: 'bottom-right', // top-left, top-right, bottom-left, bottom-right
        copyToClipboard: true,
        showTooltip: true,
        colors: {
            primary: '#4CAF50',
            overlay: 'rgba(76, 175, 80, 0.3)',
            border: '#4CAF50',
            text: '#000000'
        }
    };

    // État global
    let isActive = false;
    let isSelecting = false;
    let startX = 0;
    let startY = 0;
    let deviceScreen = null;
    let overlay = null;
    let selectionBox = null;
    let infoBox = null;
    let toggleButton = null;

    /**
     * Trouve l'écran du device dans l'interface STF
     */
    function findDeviceScreen() {
        // Cherche les éléments communs pour l'affichage du device
        const selectors = [
            'canvas.screen',
            'canvas[class*="device"]',
            'canvas[class*="screen"]',
            'img.device-screen',
            'video.device-screen',
            '.device-screen canvas',
            '.screen-container canvas',
            'canvas',
            '.device-view img',
            '.screen img'
        ];

        for (const selector of selectors) {
            const element = document.querySelector(selector);
            if (element && element.offsetWidth > 200 && element.offsetHeight > 200) {
                return element;
            }
        }

        // Fallback: cherche le plus grand canvas/img
        const canvases = Array.from(document.querySelectorAll('canvas, img'));
        canvases.sort((a, b) => {
            const areaA = a.offsetWidth * a.offsetHeight;
            const areaB = b.offsetWidth * b.offsetHeight;
            return areaB - areaA;
        });

        return canvases[0] || null;
    }

    /**
     * Crée le bouton toggle
     */
    function createToggleButton() {
        toggleButton = document.createElement('button');
        toggleButton.id = 'stf-position-toggle';
        toggleButton.innerHTML = '📏';
        toggleButton.title = 'Toggle Position Measurement Tool';

        // Style du bouton
        const positions = {
            'top-left': 'top: 20px; left: 20px;',
            'top-right': 'top: 20px; right: 20px;',
            'bottom-left': 'bottom: 20px; left: 20px;',
            'bottom-right': 'bottom: 20px; right: 20px;'
        };

        toggleButton.style.cssText = `
            position: fixed;
            ${positions[CONFIG.buttonPosition]}
            z-index: 10000;
            width: 50px;
            height: 50px;
            border-radius: 50%;
            background: ${CONFIG.colors.primary};
            color: white;
            border: none;
            font-size: 24px;
            cursor: pointer;
            box-shadow: 0 4px 8px rgba(0,0,0,0.3);
            transition: all 0.3s ease;
        `;

        toggleButton.addEventListener('click', toggleMeasurementMode);
        toggleButton.addEventListener('mouseenter', function() {
            this.style.transform = 'scale(1.1)';
        });
        toggleButton.addEventListener('mouseleave', function() {
            this.style.transform = 'scale(1)';
        });

        document.body.appendChild(toggleButton);
    }

    /**
     * Crée l'overlay sur l'écran du device
     */
    function createOverlay() {
        if (!deviceScreen) return;

        const rect = deviceScreen.getBoundingClientRect();

        overlay = document.createElement('div');
        overlay.id = 'stf-measurement-overlay';
        overlay.style.cssText = `
            position: absolute;
            top: ${rect.top + window.scrollY}px;
            left: ${rect.left + window.scrollX}px;
            width: ${rect.width}px;
            height: ${rect.height}px;
            z-index: 9999;
            cursor: crosshair;
            pointer-events: auto;
        `;

        overlay.addEventListener('mousedown', handleMouseDown);
        overlay.addEventListener('mousemove', handleMouseMove);
        overlay.addEventListener('mouseup', handleMouseUp);
        overlay.addEventListener('click', handleClick);

        document.body.appendChild(overlay);

        // Crée la box de sélection
        selectionBox = document.createElement('div');
        selectionBox.id = 'stf-selection-box';
        selectionBox.style.cssText = `
            position: absolute;
            border: 2px solid ${CONFIG.colors.border};
            background: ${CONFIG.colors.overlay};
            display: none;
            pointer-events: none;
        `;
        overlay.appendChild(selectionBox);

        // Crée l'info box
        infoBox = document.createElement('div');
        infoBox.id = 'stf-info-box';
        infoBox.style.cssText = `
            position: absolute;
            background: rgba(0, 0, 0, 0.8);
            color: white;
            padding: 8px 12px;
            border-radius: 4px;
            font-family: monospace;
            font-size: 12px;
            display: none;
            pointer-events: none;
            white-space: pre;
            z-index: 10001;
        `;
        overlay.appendChild(infoBox);
    }

    /**
     * Supprime l'overlay
     */
    function removeOverlay() {
        if (overlay) {
            overlay.remove();
            overlay = null;
            selectionBox = null;
            infoBox = null;
        }
    }

    /**
     * Toggle le mode mesure
     */
    function toggleMeasurementMode() {
        isActive = !isActive;

        if (isActive) {
            deviceScreen = findDeviceScreen();
            if (!deviceScreen) {
                alert('Impossible de trouver l\'écran du device. Assurez-vous d\'être sur une page STF avec un device actif.');
                isActive = false;
                return;
            }
            createOverlay();
            toggleButton.style.background = '#f44336';
            toggleButton.innerHTML = '✖️';
            console.log('[STF Position Tool] Mode mesure activé');
        } else {
            removeOverlay();
            toggleButton.style.background = CONFIG.colors.primary;
            toggleButton.innerHTML = '📏';
            console.log('[STF Position Tool] Mode mesure désactivé');
        }
    }

    /**
     * Gestionnaire mousedown - commence la sélection
     */
    function handleMouseDown(e) {
        if (e.button !== 0) return; // Seulement clic gauche

        isSelecting = true;
        const rect = overlay.getBoundingClientRect();
        startX = e.clientX - rect.left;
        startY = e.clientY - rect.top;

        selectionBox.style.left = startX + 'px';
        selectionBox.style.top = startY + 'px';
        selectionBox.style.width = '0px';
        selectionBox.style.height = '0px';
        selectionBox.style.display = 'block';

        e.preventDefault();
        e.stopPropagation();
    }

    /**
     * Gestionnaire mousemove - met à jour la sélection
     */
    function handleMouseMove(e) {
        if (!isSelecting) return;

        const rect = overlay.getBoundingClientRect();
        const currentX = e.clientX - rect.left;
        const currentY = e.clientY - rect.top;

        const width = Math.abs(currentX - startX);
        const height = Math.abs(currentY - startY);
        const left = Math.min(currentX, startX);
        const top = Math.min(currentY, startY);

        selectionBox.style.left = left + 'px';
        selectionBox.style.top = top + 'px';
        selectionBox.style.width = width + 'px';
        selectionBox.style.height = height + 'px';

        // Affiche les dimensions pendant la sélection
        showSelectionInfo(left, top, width, height);

        e.preventDefault();
    }

    /**
     * Gestionnaire mouseup - termine la sélection
     */
    function handleMouseUp(e) {
        if (!isSelecting) return;

        isSelecting = false;

        const rect = overlay.getBoundingClientRect();
        const currentX = e.clientX - rect.left;
        const currentY = e.clientY - rect.top;

        const width = Math.abs(currentX - startX);
        const height = Math.abs(currentY - startY);
        const left = Math.min(currentX, startX);
        const top = Math.min(currentY, startY);

        // Si la sélection est trop petite, on considère que c'est un clic
        if (width < 5 && height < 5) {
            handleClick(e);
            selectionBox.style.display = 'none';
            infoBox.style.display = 'none';
            return;
        }

        // Affiche les infos de la zone
        showSelectionInfo(left, top, width, height, true);

        e.preventDefault();
        e.stopPropagation();
    }

    /**
     * Gestionnaire click - affiche la position du point
     */
    function handleClick(e) {
        if (isSelecting) return;

        const rect = overlay.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;

        showPointInfo(x, y);

        e.preventDefault();
        e.stopPropagation();
    }

    /**
     * Affiche les infos d'un point
     */
    function showPointInfo(x, y) {
        const deviceRect = deviceScreen.getBoundingClientRect();
        const percentX = ((x / deviceRect.width) * 100).toFixed(2);
        const percentY = ((y / deviceRect.height) * 100).toFixed(2);

        const info = `📍 Position
X: ${Math.round(x)}px (${percentX}%)
Y: ${Math.round(y)}px (${percentY}%)

Device: ${Math.round(deviceRect.width)}x${Math.round(deviceRect.height)}px`;

        infoBox.textContent = info;
        infoBox.style.left = (x + 10) + 'px';
        infoBox.style.top = (y + 10) + 'px';
        infoBox.style.display = 'block';

        // Log dans la console
        const consoleInfo = {
            x: Math.round(x),
            y: Math.round(y),
            percentX: parseFloat(percentX),
            percentY: parseFloat(percentY),
            deviceWidth: Math.round(deviceRect.width),
            deviceHeight: Math.round(deviceRect.height)
        };
        console.log('[STF Position Tool] Point:', consoleInfo);

        // Copie dans le presse-papier
        if (CONFIG.copyToClipboard) {
            const clipboardText = `x=${Math.round(x)}, y=${Math.round(y)} (${percentX}%, ${percentY}%)`;
            copyToClipboard(clipboardText);
        }

        // Cache après 3 secondes
        setTimeout(() => {
            if (infoBox) infoBox.style.display = 'none';
        }, 3000);
    }

    /**
     * Affiche les infos de la sélection
     */
    function showSelectionInfo(left, top, width, height, final = false) {
        const deviceRect = deviceScreen.getBoundingClientRect();
        const percentX = ((left / deviceRect.width) * 100).toFixed(2);
        const percentY = ((top / deviceRect.height) * 100).toFixed(2);
        const percentW = ((width / deviceRect.width) * 100).toFixed(2);
        const percentH = ((height / deviceRect.height) * 100).toFixed(2);

        const info = `📐 Sélection
Position:
  X: ${Math.round(left)}px (${percentX}%)
  Y: ${Math.round(top)}px (${percentY}%)

Dimensions:
  W: ${Math.round(width)}px (${percentW}%)
  H: ${Math.round(height)}px (${percentH}%)

Device: ${Math.round(deviceRect.width)}x${Math.round(deviceRect.height)}px`;

        infoBox.textContent = info;
        infoBox.style.left = (left + width + 10) + 'px';
        infoBox.style.top = (top) + 'px';
        infoBox.style.display = 'block';

        if (final) {
            // Log dans la console
            const consoleInfo = {
                x: Math.round(left),
                y: Math.round(top),
                width: Math.round(width),
                height: Math.round(height),
                percentX: parseFloat(percentX),
                percentY: parseFloat(percentY),
                percentW: parseFloat(percentW),
                percentH: parseFloat(percentH),
                deviceWidth: Math.round(deviceRect.width),
                deviceHeight: Math.round(deviceRect.height)
            };
            console.log('[STF Position Tool] Zone:', consoleInfo);

            // Copie dans le presse-papier
            if (CONFIG.copyToClipboard) {
                const clipboardText = `x=${Math.round(left)}, y=${Math.round(top)}, w=${Math.round(width)}, h=${Math.round(height)} (${percentX}%, ${percentY}%, ${percentW}%, ${percentH}%)`;
                copyToClipboard(clipboardText);
            }

            // Cache après 5 secondes
            setTimeout(() => {
                if (selectionBox) selectionBox.style.display = 'none';
                if (infoBox) infoBox.style.display = 'none';
            }, 5000);
        }
    }

    /**
     * Copie du texte dans le presse-papier
     */
    function copyToClipboard(text) {
        if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(text).then(() => {
                console.log('[STF Position Tool] Copié dans le presse-papier:', text);
            }).catch(err => {
                console.error('[STF Position Tool] Erreur de copie:', err);
            });
        }
    }

    /**
     * Gestion du redimensionnement de la fenêtre
     */
    function handleResize() {
        if (isActive && overlay) {
            removeOverlay();
            createOverlay();
        }
    }

    /**
     * Initialisation
     */
    function init() {
        // Vérifie si déjà initialisé
        if (document.getElementById('stf-position-toggle')) {
            console.log('[STF Position Tool] Déjà initialisé');
            return;
        }

        createToggleButton();
        window.addEventListener('resize', handleResize);

        console.log('[STF Position Tool] Initialisé. Cliquez sur le bouton 📏 pour activer.');
    }

    // Lance l'initialisation
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
