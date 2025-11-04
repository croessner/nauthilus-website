import React, { useEffect, useRef } from 'react';
import Layout from '@theme-original/Layout';
import panzoom from 'panzoom';

export default function CustomLayout(props) {
  const lightboxRef = useRef(null);
  const pzRef = useRef(null);

  useEffect(() => {
    const containerSelector = '.docusaurus-mermaid-container';

    // Install global lightbox once
    const ensureLightbox = () => {
      if (lightboxRef.current) return lightboxRef.current;
      const overlay = document.createElement('div');
      overlay.className = 'mermaid-lightbox-overlay';
      overlay.setAttribute('role', 'dialog');
      overlay.setAttribute('aria-modal', 'true');
      overlay.style.display = 'none';

      overlay.innerHTML = `
        <div class="mermaid-lightbox" tabindex="-1">
          <button class="mermaid-lightbox__close" aria-label="Close (Esc)">✕</button>
          <div class="mermaid-lightbox__stage">
            <div class="mermaid-lightbox__canvas"></div>
          </div>
          <div class="mermaid-lightbox__controls" aria-label="Diagram controls">
            <button class="mlb-btn" data-action="zoom-in" title="Zoom in">＋</button>
            <button class="mlb-btn" data-action="zoom-out" title="Zoom out">－</button>
          </div>
        </div>`;

      document.body.appendChild(overlay);
      lightboxRef.current = overlay;
      return overlay;
    };

    const openLightboxWithSvg = (sourceSvg) => {
      const overlay = ensureLightbox();
      const canvas = overlay.querySelector('.mermaid-lightbox__canvas');

      // Cleanup previous content / Panzoom
      if (pzRef.current) {
        try { pzRef.current.dispose?.(); } catch {}
        pzRef.current = null;
      }
      canvas.innerHTML = '';

      // Clone SVG so it's independent from original
      const svgClone = sourceSvg.cloneNode(true);
      // Remove width/height so viewBox drives responsive sizing
      svgClone.removeAttribute('width');
      svgClone.removeAttribute('height');
      svgClone.style.maxWidth = 'none';
      svgClone.style.maxHeight = 'none';

      canvas.appendChild(svgClone);

      // Show overlay
      overlay.style.display = 'block';
      document.documentElement.style.overflow = 'hidden'; // Scroll lock
      setTimeout(() => overlay.classList.add('is-open'), 0);

      // Init panzoom in lightbox
      const pz = panzoom(svgClone, {
        maxZoom: 8,
        minZoom: 0.2,
        zoomSpeed: 0.06,
        bounds: false,
        smoothScroll: false,
      });
      pzRef.current = pz;

      // Fit after render
      requestAnimationFrame(() => {
        fitToView(svgClone, pz);
      });

      // Controls
      const controls = overlay.querySelector('.mermaid-lightbox__controls');
      const onControl = (e) => {
        const btn = e.target.closest('[data-action]');
        if (!btn) return;
        e.preventDefault();
        const action = btn.getAttribute('data-action');
        switch (action) {
          case 'zoom-in':
            pz.smoothZoom(svgClone.clientWidth / 2, svgClone.clientHeight / 2, 1.2);
            break;
          case 'zoom-out':
            pz.smoothZoom(svgClone.clientWidth / 2, svgClone.clientHeight / 2, 1 / 1.2);
            break;
        }
      };
      controls.addEventListener('click', onControl, { once: false });

      // Refit on window resize while lightbox is open (debounced)
      let resizeRaf = null;
      const onResize = () => {
        if (resizeRaf) cancelAnimationFrame(resizeRaf);
        resizeRaf = requestAnimationFrame(() => fitToView(svgClone, pz));
      };
      window.addEventListener('resize', onResize);

      // Close handlers
      const closeBtn = overlay.querySelector('.mermaid-lightbox__close');
      const onClose = () => closeLightbox();
      closeBtn.addEventListener('click', onClose, { once: true });

      const onBackdrop = (e) => {
        if (e.target === overlay) closeLightbox();
      };
      overlay.addEventListener('mousedown', onBackdrop);

      const onKey = (e) => {
        if (e.key === 'Escape') closeLightbox();
      };
      document.addEventListener('keydown', onKey, { once: true });

      function closeLightbox() {
        overlay.classList.remove('is-open');
        setTimeout(() => {
          overlay.style.display = 'none';
          document.documentElement.style.overflow = '';
          canvas.innerHTML = '';
          try { pz.dispose?.(); } catch {}
          pzRef.current = null;
          overlay.removeEventListener('mousedown', onBackdrop);
          // Cleanup listeners added on open
          controls.removeEventListener('click', onControl);
          window.removeEventListener('resize', onResize);
        }, 150);
      }

      function fitToView(svgEl, pzInst) {
        try {
          const vbParts = (svgEl.getAttribute('viewBox') || '').split(/\s+/).map(Number);
          const stage = overlay.querySelector('.mermaid-lightbox__stage');
          const stageRect = stage.getBoundingClientRect();

          // Determine content bounds (x, y, width, height)
          let x = 0, y = 0, contentW, contentH;
          if (vbParts.length === 4 && vbParts.every((n) => !isNaN(n))) {
            x = vbParts[0];
            y = vbParts[1];
            contentW = vbParts[2];
            contentH = vbParts[3];
          } else {
            const r = svgEl.getBBox?.();
            x = (r?.x ?? 0);
            y = (r?.y ?? 0);
            contentW = (r?.width || svgEl.clientWidth || 800);
            contentH = (r?.height || svgEl.clientHeight || 600);
          }

          // Available space minus a small padding
          const padding = 24;
          const availW = Math.max(0, stageRect.width - padding);
          const availH = Math.max(0, stageRect.height - padding);

          // Compute target scale to fit entirely
          let scale = Math.min(availW / contentW, availH / contentH);
          // Clamp to the same min/max used by panzoom
          const MIN = 0.2; // must match panzoom options
          const MAX = 8;   // must match panzoom options
          const targetScale = Math.max(MIN, Math.min(MAX, scale));

          // Zoom around the visual center of the SVG in the stage
          const svgRect = svgEl.getBoundingClientRect();
          const cx = svgRect.left + svgRect.width / 2;
          const cy = svgRect.top + svgRect.height / 2;

          // Apply absolute zoom, then translate so that content is centered
          pzInst.zoomAbs(cx, cy, targetScale);
          const dx = (stageRect.width - contentW * targetScale) / 2 - x * targetScale;
          const dy = (stageRect.height - contentH * targetScale) / 2 - y * targetScale;
          pzInst.moveTo(dx, dy);
        } catch {}
      }
    };

    // Setup click handlers on all Mermaid containers
    const initPreviewContainers = () => {
      document.querySelectorAll(containerSelector).forEach((container) => {
        if (container.dataset.lbInit === 'true') return;
        container.style.cursor = 'zoom-in';
        container.addEventListener('click', (e) => {
          const svg = container.querySelector('svg');
          if (!svg) return;
          if (e.button === 0) {
            openLightboxWithSvg(svg);
          }
        });
        container.dataset.lbInit = 'true';
      });
    };

    // Initial and observe for dynamically inserted diagrams
    initPreviewContainers();
    const mo = new MutationObserver(() => initPreviewContainers());
    mo.observe(document.body, { childList: true, subtree: true });

    return () => {
      mo.disconnect();
      if (pzRef.current) {
        try { pzRef.current.dispose?.(); } catch {}
        pzRef.current = null;
      }
    };
  }, []);

  return <Layout {...props} />;
}
