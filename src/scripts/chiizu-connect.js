// chiizu-loader.js
(async () => {
    // Load ESM dynamically
    const { ChiizuJS } = await import('https://js.chiizu.dev');

    const { initialize, bank, card } = ChiizuJS({

    });

    card();
    initialize();
})();
