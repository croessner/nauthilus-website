import {useRef, useState} from 'react';
import clsx from 'clsx';
import useBaseUrl from '@docusaurus/useBaseUrl';
import styles from './styles.module.css';

export default function PromoVideo() {
  const videoRef = useRef(null);
  const [started, setStarted] = useState(false);
  const src = useBaseUrl('/img/nauthilus_promo_16x9.mp4');
  const poster = useBaseUrl('/img/nauthilus_promo_poster.jpg');

  const start = () => {
    const video = videoRef.current;
    if (!video) {
      return;
    }
    setStarted(true);
    video.play().catch(() => {
      // Playback was refused (e.g. by a browser policy); the native controls stay available.
    });
  };

  return (
    <div className={styles.frame}>
      <video
        ref={videoRef}
        className={styles.video}
        poster={poster}
        preload="none"
        playsInline
        controls={started}
        onPlay={() => setStarted(true)}
        aria-label="Nauthilus in 76 seconds: one central policy engine for mail, web and identity">
        <source src={src} type="video/mp4" />
        Your browser does not support embedded video. <a href={src}>Download the Nauthilus video</a>.
      </video>
      {!started && (
        <button type="button" className={clsx(styles.overlay)} onClick={start} aria-label="Play the Nauthilus video (1:16, with sound)">
          <span className={styles.playButton} aria-hidden="true">
            <svg viewBox="0 0 24 24" width="34" height="34" focusable="false">
              <path d="M8 5.14v13.72a1 1 0 0 0 1.52.85l10.76-6.86a1 1 0 0 0 0-1.7L9.52 4.29A1 1 0 0 0 8 5.14Z" fill="currentColor" />
            </svg>
          </span>
          <span className={styles.duration}>Play · 1:16 · with sound</span>
        </button>
      )}
    </div>
  );
}
