const config = require('../config.json');

/**
 * Middleware to check for the X-API-KEY header.
 * This prevents unauthorized access to the backend endpoints.
 */
module.exports = (req, res, next) => {
    const apiKey = req.header('X-API-KEY');

    // Check if API Key is present and matches the one in config
    if (!apiKey || apiKey !== config.api_key) {
        console.warn(`[Auth] Unauthorized access attempt from ${req.ip} - Path: ${req.path}`);
        return res.status(401).json({
            status: '0',
            message: 'Unauthorized: Invalid or missing API Key'
        });
    }

    next();
};
