const neo4jService = require('./neo4jService');

const preferencesController = {
    async updateUserPreferences(req, res) {
        const { uid } = req.params;
        const { favoriteGenres, streamingServices, dailyRecommendationsEnabled } = req.body;

        // Validate user is updating their own preferences
        if (req.user.sub !== uid) {
            return res.status(403).json({ error: 'Cannot update other user preferences' });
        }

        try {
            // Find or create User node and attach/update preferences
            const cypher = `
        MATCH (u:User {userId: $uid})
        SET u.favoriteGenres = $favoriteGenres,
            u.streamingServices = $streamingServices,
            u.dailyRecommendationsEnabled = $dailyRecommendationsEnabled,
            u.preferencesUpdatedAt = datetime()
        RETURN u
      `;

            const result = await neo4jService.run(cypher, {
                uid,
                favoriteGenres,
                streamingServices,
                dailyRecommendationsEnabled,
            });

            if (result.records.length === 0) {
                return res.status(404).json({ error: 'User not found' });
            }

            const userRecord = result.records[0].get('u').properties;
            console.log('[PreferencesController] User preferences updated:', uid);

            res.json({
                success: true,
                user: userRecord,
            });
        } catch (e) {
            console.error('[PreferencesController] Error updating preferences:', e);
            res.status(500).json({ error: e.message });
        }
    },

    async getUserPreferences(req, res) {
        const { uid } = req.params;

        // Validate user is reading their own preferences
        if (req.user.sub !== uid) {
            return res.status(403).json({ error: 'Cannot read other user preferences' });
        }

        try {
            const cypher = `
        MATCH (u:User {userId: $uid})
        RETURN {
          favoriteGenres: u.favoriteGenres,
          streamingServices: u.streamingServices,
          dailyRecommendationsEnabled: u.dailyRecommendationsEnabled,
          preferencesUpdatedAt: u.preferencesUpdatedAt
        } as preferences
      `;

            const result = await neo4jService.run(cypher, { uid });

            if (result.records.length === 0) {
                return res.status(404).json({ error: 'User not found' });
            }

            const preferences = result.records[0].get('preferences');
            console.log('[PreferencesController] User preferences retrieved:', uid);

            res.json({
                success: true,
                preferences,
            });
        } catch (e) {
            console.error('[PreferencesController] Error retrieving preferences:', e);
            res.status(500).json({ error: e.message });
        }
    },
};

module.exports = preferencesController;
