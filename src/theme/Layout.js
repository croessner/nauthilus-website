import React, { useEffect } from 'react';
import Layout from '@theme-original/Layout';
import panzoom from 'panzoom';

export default function CustomLayout(props) {
  useEffect(() => {
    // Use MutationObserver to monitor dynamically added Mermaid containers
    const observer = new MutationObserver(() => {
      // Find all dynamically added Mermaid containers
      const mermaidElements = document.querySelectorAll(
        '.docusaurus-mermaid-container'
      );

      // If Mermaid elements are found, process each container
      if (mermaidElements.length > 0) {
        mermaidElements.forEach((container) => {
          const svg = container.querySelector('svg'); // Locate the SVG inside the container
          if (!svg) {
            console.warn('No SVG found inside Mermaid container.');
            return;
          }

          // Dynamically get the original height of the SVG
          let originalHeight = 500; // Default fallback height in case nothing is found
          const viewBox = svg.getAttribute('viewBox'); // Check if the SVG has a viewBox attribute

          if (viewBox) {
            // If a viewBox exists, calculate the height from its values (e.g., "0 0 800 400")
            const viewBoxValues = viewBox.split(' ');
            if (viewBoxValues.length >= 4) {
              originalHeight = Number(viewBoxValues[3]); // The fourth value represents the height
            }
          } else if (svg.getAttribute('height')) {
            // If no viewBox, fallback to the 'height' attribute if available
            originalHeight = parseInt(svg.getAttribute('height'), 10);
          }

          // Apply max-height to the container dynamically
          container.style.maxHeight = `${originalHeight}px`;

          // Configure maximum and minimum zoom levels dynamically
          const maxZoomFactor = 4; // Allow up to 4x the original size
          const minZoomFactor = 0.5; // Allow down to 50% of the original size
          const maxZoom = maxZoomFactor * (originalHeight / originalHeight); // Allow 2x zoom (default)
          const minZoom = minZoomFactor * (originalHeight / originalHeight); // Allow 0.5x zoom (default)

          // Apply Panzoom functionality to the SVG
          panzoom(svg, {
            zoomSpeed: 0.065,       // Adjust the zoom speed for smoother interaction
            maxZoom: maxZoom,       // Allow doubling the zoom beyond the original size
            minZoom: minZoom,       // Allow zooming out to 50% of the original size
            contain: 'inside',      // Restrict panning to remain inside the container
          });

          // Add a description ABOVE the Mermaid diagram, only once
          if (!container.querySelector('.mermaid-description')) {
            container.insertAdjacentHTML(
              'afterbegin',
              `<div class="mermaid-description">
                Use your mouse to zoom and pan this diagram.
              </div>`
            );
          }

          console.log(
            `Processed Mermaid diagram with original height: ${originalHeight}px (Max Zoom: ${maxZoom}, Min Zoom: ${minZoom})`
          );
        });

        // Stop observing changes after diagrams are processed
        observer.disconnect();
      }
    });

    // Start observing the DOM for new elements (e.g., Mermaid diagrams rendered asynchronously)
    observer.observe(document.body, {
      childList: true, // Monitor when child nodes are added
      subtree: true,   // Observe changes deeply within the DOM tree
    });
  }, []);

  return <Layout {...props} />;
}
