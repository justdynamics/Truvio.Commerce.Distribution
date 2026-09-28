// Truvio gallery zoom: opens the Swift 2 ProductMedia / ProductMediaGallery images in PhotoSwipe
// instead of the stock Bootstrap modal. Progressive: when this script or PhotoSwipe fails to load,
// the stock modal still opens. Markup contract (Swift 2.4.0): a slide link carries
// data-bs-toggle="modal" data-bs-target="#modal_<ID>", and its inner element carries
// data-bs-slide-to="<index into #ModalCarousel_<ID> .carousel-item>".
(() => {
	const script = document.currentScript;
	const base = script && script.src
		? script.src.replace(/[^/?#]*([?#].*)?$/, '')
		: '/Files/Templates/Designs/Swift-v2/Custom/Addons/gallery-zoom/';
	const GALLERY = '[class*="item_swift-v2_productmedia"]';
	const TRIGGER = '[data-bs-toggle="modal"][data-bs-target^="#modal_"]';
	const LARGE_WIDTH = 2400;
	let lightboxModule = null;

	// The PhotoSwipe sheet and both modules load on first use only; a page that never opens
	// the lightbox pays for this file alone.
	const loadLightbox = () => {
		if (!lightboxModule) {
			const link = document.createElement('link');
			link.rel = 'stylesheet';
			link.href = base + 'photoswipe/photoswipe.css';
			document.head.appendChild(link);
			lightboxModule = import(base + 'photoswipe/photoswipe-lightbox.esm.min.js');
		}
		return lightboxModule;
	};

	// The original file path from a GetImage URL, or the URL itself when GetImage is disabled.
	const originalOf = (url) => {
		try {
			const u = new URL(url, location.href);
			return u.pathname.toLowerCase().endsWith('/getimage.ashx') ? u.searchParams.get('image') : u.pathname;
		} catch { return null; }
	};
	const largeUrl = (path) => '/Admin/Public/GetImage.ashx?image=' + encodeURIComponent(path) + '&width=' + LARGE_WIDTH + '&format=webp';

	// Build the slide list from the stock modal carousel, so the order matches data-bs-slide-to.
	const slidesFor = (modal) => [...modal.querySelectorAll('.carousel-inner > .carousel-item')].map((item) => {
		const img = item.querySelector('img');
		const video = item.querySelector('video, iframe, [data-asset-value]');
		if (img) {
			const srcset = img.getAttribute('srcset') || '';
			const first = srcset.trim().split(/\s+/)[0] || img.getAttribute('src');
			const path = originalOf(first);
			const ratio = img.naturalWidth ? img.naturalHeight / img.naturalWidth : 1;
			return {
				src: path ? largeUrl(path) : img.currentSrc || img.src,
				msrc: img.currentSrc || img.src,
				width: LARGE_WIDTH,
				height: Math.round(LARGE_WIDTH * ratio),
				alt: img.alt || ''
			};
		}
		// Video and other non-image slides keep their stock markup inside PhotoSwipe.
		const clone = item.cloneNode(true);
		clone.classList.remove('carousel-item', 'active');
		return { html: '<div class="tcg-html-slide">' + clone.innerHTML + '</div>', video: !!video };
	});

	// PhotoSwipe needs a size up front; GetImage keeps the source ratio and never upscales,
	// so the real size is known once the large image has loaded. Two routes, because PhotoSwipe
	// dispatches loadComplete only when the content already has a slide: the first image is
	// preloaded before its slide exists, and without the slide route it keeps the declared
	// 2400px, so zoom level 2 rendered a 480px source at 4800px (measured at 390, 2026-09-28).
	const fitToLoaded = ({ content, slide }) => {
		const el = content && content.element;
		if (!el || el.tagName !== 'IMG' || !el.naturalWidth) return;
		content.width = content.data.width = el.naturalWidth;
		content.height = content.data.height = el.naturalHeight;
		if (!slide || (slide.width === content.width && slide.height === content.height)) return;
		slide.width = content.width;
		slide.height = content.height;
		slide.calculateSize();
		slide.currentResolution = 0;
		slide.zoomAndPanToInitial();
		slide.applyCurrentZoomPan();
		slide.updateContentSize(true);
	};

	const open = async (trigger) => {
		const modal = document.querySelector(trigger.getAttribute('data-bs-target'));
		if (!modal) return false;
		const indexEl = trigger.querySelector('[data-bs-slide-to]') || trigger;
		const index = parseInt(indexEl.getAttribute('data-bs-slide-to'), 10) || 0;
		const dataSource = slidesFor(modal);
		if (!dataSource.length) return false;
		const { default: PhotoSwipeLightbox } = await loadLightbox();
		const lightbox = new PhotoSwipeLightbox({
			dataSource,
			pswpModule: () => import(base + 'photoswipe/photoswipe.esm.min.js'),
			showHideAnimationType: 'fade',
			bgOpacity: 0.95,
			wheelToZoom: true,
			secondaryZoomLevel: 2,
			maxZoomLevel: 4,
			initialZoomLevel: 'fit',
			imageClickAction: 'zoom-or-close',
			tapAction: 'toggle-controls',
			doubleTapAction: 'zoom',
			closeTitle: 'Close',
			zoomTitle: 'Zoom',
			arrowPrevTitle: 'Previous',
			arrowNextTitle: 'Next',
			errorMsg: 'The image could not be loaded.'
		});
		lightbox.on('loadComplete', fitToLoaded);
		const fitSlide = (slide) => {
			const el = slide && slide.content && slide.content.element;
			if (!el || el.tagName !== 'IMG') return;
			if (el.complete && el.naturalWidth) fitToLoaded({ content: slide.content, slide });
			else el.addEventListener('load', () => fitToLoaded({ content: slide.content, slide }), { once: true });
		};
		// The opening slide is created active, so it gets afterInit and no slideActivate.
		lightbox.on('afterInit', () => fitSlide(lightbox.pswp.currSlide));
		lightbox.on('slideActivate', ({ slide }) => fitSlide(slide));
		lightbox.on('uiRegister', () => {
			lightbox.pswp.ui.registerElement({
				name: 'tcg-download',
				order: 8,
				isButton: true,
				tagName: 'a',
				title: 'Open original',
				html: '<svg class="pswp__icn" viewBox="0 0 32 32" width="32" height="32" aria-hidden="true"><path d="M16 5v14m0 0-5-5m5 5 5-5M8 24h16" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg>',
				onInit: (el, pswp) => {
					el.setAttribute('target', '_blank');
					el.setAttribute('rel', 'noopener');
					const update = () => {
						const src = pswp.currSlide && pswp.currSlide.data.src;
						const path = src && originalOf(src);
						el.hidden = !path;
						if (path) el.href = path;
					};
					pswp.on('change', update);
					update();
				}
			});
		});
		lightbox.on('destroy', () => trigger.focus({ preventScroll: true }));
		lightbox.init();
		lightbox.loadAndOpen(index);
		return true;
	};

	// Capture phase on window, so this runs before Bootstrap's delegated data-api handler opens the
	// modal. defaultPrevented is not a reason to stand down: Swift itself prevents the default on the
	// slide anchor (so the href never navigates) before Bootstrap opens the modal (measured 2026-09-28).
	window.addEventListener('click', (event) => {
		if (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey) return;
		const trigger = event.target.closest(TRIGGER);
		if (!trigger || !trigger.closest(GALLERY)) return;
		if (trigger.querySelector('video, .icon-5')) return; // video slides keep the stock modal player
		event.preventDefault();
		event.stopPropagation();
		open(trigger).then((opened) => {
			if (!opened && window.bootstrap) window.bootstrap.Modal.getOrCreateInstance(document.querySelector(trigger.getAttribute('data-bs-target'))).show();
		}).catch((error) => {
			console.error('[gallery-zoom] falling back to the stock modal:', error);
			const modal = document.querySelector(trigger.getAttribute('data-bs-target'));
			if (modal && window.bootstrap) window.bootstrap.Modal.getOrCreateInstance(modal).show();
		});
	}, true);

	// Warm the lightbox module when the pointer or finger reaches a gallery, so the first open is instant.
	const warm = (event) => { if (event.target.closest && event.target.closest(GALLERY)) loadLightbox(); };
	document.addEventListener('pointerover', warm, { passive: true });
	document.addEventListener('touchstart', warm, { passive: true });
})();
