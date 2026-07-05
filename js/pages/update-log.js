/* update-log.js — page-specific scripts for update-log page */

(function () {
	'use strict';

	document.querySelectorAll('.log-entry-card').forEach(card => {
		const summary = card.querySelector('.log-entry-summary');
		if (!summary) return;

		const flash = () => {
			card.classList.remove('is-clicked');
			void card.offsetWidth;
			card.classList.add('is-clicked');
		};

		summary.addEventListener('click', flash);
		card.addEventListener('animationend', event => {
			if (event.animationName === 'log-card-click') {
				card.classList.remove('is-clicked');
			}
		});
	});
})();
