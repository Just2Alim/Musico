const { ApolloServer } = require('@apollo/server');
const { expressMiddleware } = require('@apollo/server/express4');
const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const { GraphQLError } = require('graphql');
const sql = require('mssql');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const path = require('path');
require('dotenv').config();
const { gql } = require('graphql-tag');

const dbConfig = {
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  server: process.env.DB_SERVER,
  database: process.env.DB_NAME,
  options: {
    encrypt: true,
    trustServerCertificate: true,
  },
};

const JWT_SECRET = process.env.JWT_SECRET || 'justify-music-secret-key';

const generateToken = (user) => {
  return jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: '7d' });
};

const hashPassword = async (password) => {
  const saltRounds = 10;
  return await bcrypt.hash(password, saltRounds);
};

const comparePasswords = async (password, hashedPassword) => {
  return await bcrypt.compare(password, hashedPassword);
};

const getUserIdFromToken = (token) => {
  if (!token) return null;
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    return decoded.userId;
  } catch (error) {
    return null;
  }
};

const typeDefs = gql`
  type User {
  id: Int!
  name: String!
  email: String!
  createdAt: String
}

type UserProfile {
  id: Int!
  name: String!
  email: String!
  settings: UserSettings
  createdAt: String
}

type UserSettings {
  language: String!
  darkMode: Boolean!
  audioQuality: String!
}

type AuthPayload {
  token: String!
  user: User!
}

type Playlist {
  id: Int!
  name: String!
  subtitle: String
  artist: String
  imageUrl: String
  userId: Int!
  createdAt: String
  trackCount: Int
  tracks: [Track]
  user: User
}

type Track {
  id: Int!
  name: String!
  artist: String!
  genre: String
  duration: Int!
  coverImageUrl: String
  audioFileUrl: String!
  isLiked: Boolean
}

type FavoriteTrack {
  id: Int!
  track: Track!
  addedAt: String!
}

type ListeningHistoryEntry {
  id: Int!
  track: Track!
  listenedAt: String!
  completed: Boolean!
}

type SearchResults {
  tracks: [Track]
  playlists: [Playlist]
  artists: [String]
}

type Query {
  # User queries
  me: UserProfile
  user(userId: Int!): User
  
  # Playlist queries
  playlist(playlistId: Int!): Playlist
  playlists(userId: Int!): [Playlist]
  featuredPlaylists: [Playlist]
  newReleases: [Playlist]
  
  # Track queries
  track(trackId: Int!): Track
  tracks(playlistId: Int): [Track]
  recentlyPlayed(limit: Int): [ListeningHistoryEntry]
  favoriteTracks(userId: Int): [FavoriteTrack]
  
  # Search
  search(query: String!, type: String): SearchResults
  
  # Localization
  getLocalizedStrings(language: String!): [LocalizedString]
}

type LocalizedString {
  key: String!
  value: String!
}

type Mutation {
  # Authentication
  register(name: String!, email: String!, password: String!): AuthPayload
  login(email: String!, password: String!): AuthPayload
  updateProfile(name: String, email: String): UserProfile
  updatePassword(oldPassword: String!, newPassword: String!): Boolean
  
  # User settings
  updateUserSettings(language: String, darkMode: Boolean, audioQuality: String): UserSettings
  
  # Playlist management
  createPlaylist(name: String!, subtitle: String, imageUrl: String): Playlist
  updatePlaylist(playlistId: Int!, name: String, subtitle: String, imageUrl: String): Playlist
  deletePlaylist(playlistId: Int!): Boolean
  
  # Track interactions
  addTrackToPlaylist(playlistId: Int!, trackId: Int!): Boolean
  removeTrackFromPlaylist(playlistId: Int!, trackId: Int!): Boolean
  likeTrack(trackId: Int!): Boolean
  unlikeTrack(trackId: Int!): Boolean
  recordListening(trackId: Int!, completed: Boolean): ListeningHistoryEntry
}

schema {
  query: Query
  mutation: Mutation
}
`;

const resolvers = {
  Query: {
    me: async (_, __, { userId }) => {
      if (!userId) throw new GraphQLError('Not authenticated');
      
      try {
        const pool = await sql.connect(dbConfig);
        const userResult = await pool
          .request()
          .input('userId', sql.Int, userId)
          .query('SELECT user_id as id, name, email FROM users WHERE user_id = @userId');
        
        if (userResult.recordset.length === 0) {
          throw new GraphQLError('User not found');
        }
        
        const user = userResult.recordset[0];
        
        const settingsResult = await pool
          .request()
          .input('userId', sql.Int, userId)
          .query('SELECT language, darkMode, audioQuality FROM user_settings WHERE userId = @userId');
        
        if (settingsResult.recordset.length > 0) {
          user.settings = settingsResult.recordset[0];
        } else {
          user.settings = {
            language: 'en',
            darkMode: true,
            audioQuality: 'normal'
          };
        }
        
        return user;
      } catch (error) {
        console.error('Error in me query:', error);
        throw new GraphQLError('Failed to fetch user profile');
      }
    },
    
    user: async (_, { userId }) => {
      try {
        const pool = await sql.connect(dbConfig);
        const result = await pool
          .request()
          .input('userId', sql.Int, userId)
          .query('SELECT user_id as id, name, email FROM users WHERE user_id = @userId');
        
        if (result.recordset.length === 0) {
          throw new GraphQLError('User not found');
        }
        
        return result.recordset[0];
      } catch (error) {
        console.error('Error in user query:', error);
        throw new GraphQLError('Failed to fetch user data');
      }
    },
    
    playlist: async (_, { playlistId }, { userId }) => {
      try {
        const pool = await sql.connect(dbConfig);
        const result = await pool
          .request()
          .input('playlistId', sql.Int, playlistId)
          .query(`
            SELECT p.id, p.name, p.subtitle, p.artist, p.imageUrl, p.userId, p.CreatedAt,
                   COUNT(pt.trackId) as trackCount
            FROM playlists p
            LEFT JOIN playlist_tracks pt ON p.id = pt.playlistId
            WHERE p.id = @playlistId
            GROUP BY p.id, p.name, p.subtitle, p.artist, p.imageUrl, p.userId, p.CreatedAt
          `);
        
        if (result.recordset.length === 0) {
          throw new GraphQLError('Playlist not found');
        }
        
        return result.recordset[0];
      } catch (error) {
        console.error('Error in playlist query:', error);
        throw new GraphQLError('Failed to fetch playlist data');
      }
    },
    
    playlists: async (_, { userId }) => {
      try {
        const pool = await sql.connect(dbConfig);
        const result = await pool
          .request()
          .input('userId', sql.Int, userId)
          .query(`
            SELECT p.id, p.name, p.subtitle, p.artist, p.imageUrl, p.userId, p.CreatedAt,
                   COUNT(pt.trackId) as trackCount
            FROM playlists p
            LEFT JOIN playlist_tracks pt ON p.id = pt.playlistId
            WHERE p.userId = @userId
            GROUP BY p.id, p.name, p.subtitle, p.artist, p.imageUrl, p.userId, p.CreatedAt
          `);
        
        return result.recordset;
      } catch (error) {
        console.error('Error in playlists query:', error);
        throw new GraphQLError('Failed to fetch playlists');
      }
    },
    
    featuredPlaylists: async () => {
      try {
        const pool = await sql.connect(dbConfig);
        const result = await pool.request().query(`
          SELECT TOP 6 p.id, p.name, p.subtitle, p.artist, p.imageUrl, p.userId, p.CreatedAt,
                 COUNT(pt.trackId) as trackCount
          FROM playlists p
          LEFT JOIN playlist_tracks pt ON p.id = pt.playlistId
          GROUP BY p.id, p.name, p.subtitle, p.artist, p.imageUrl, p.userId, p.CreatedAt
          ORDER BY p.CreatedAt DESC
        `);
        
        return result.recordset;
      } catch (error) {
        console.error('Error in featuredPlaylists query:', error);
        throw new GraphQLError('Failed to fetch featured playlists');
      }
    },
    
    newReleases: async () => {
      try {
        const pool = await sql.connect(dbConfig);
        const result = await pool.request().query(`
          SELECT TOP 6 p.id, p.name, p.subtitle, t.Artist as artist, t.CoverImageUrl as imageUrl, p.userId, p.CreatedAt,
                 COUNT(pt.trackId) as trackCount
          FROM playlists p
          JOIN playlist_tracks pt ON p.id = pt.playlistId
          JOIN Tracks t ON pt.trackId = t.ID
          GROUP BY p.id, p.name, p.subtitle, t.Artist, t.CoverImageUrl, p.userId, p.CreatedAt
          ORDER BY p.CreatedAt DESC
        `);
        
        return result.recordset;
      } catch (error) {
        console.error('Error in newReleases query:', error);
        throw new GraphQLError('Failed to fetch new releases');
      }
    },
    
    track: async (_, { trackId }, { userId }) => {
      console.log(`Запрос трека с ID: ${trackId}`);
      try {
        await sql.close();

        const pool = await sql.connect(dbConfig);
        const result = await pool
          .request()
          .input('trackId', sql.Int, trackId)
          .query(`
            SELECT 
              t.ID as id, 
              t.Name as name, 
              t.Artist as artist, 
              t.Genre as genre, 
              t.Duration as duration, 
              t.CoverImageUrl as coverImageUrl, 
              t.AudioFileUrl as audioFileUrl
            FROM Tracks t
            WHERE t.ID = @trackId
          `);

          console.log('Результат запроса:', result.recordset[0]);
        
        if (result.recordset.length === 0) {
          throw new GraphQLError('Track not found');
        }
        
        const track = result.recordset[0];
        
        if (userId) {
          const likedResult = await pool
            .request()
            .input('userId', sql.Int, userId)
            .input('trackId', sql.Int, trackId)
            .query('SELECT 1 FROM favorite_tracks WHERE userId = @userId AND trackId = @trackId');
          
          track.isLiked = likedResult.recordset.length > 0;
        } else {
          track.isLiked = false;
        }
        
        return track;
      } catch (error) {
        console.error('Error in track query:', error);
        throw new GraphQLError('Failed to fetch track data');
      }
    },
    
    tracks: async (_, { playlistId }, { userId }) => {
      try {
        const pool = await sql.connect(dbConfig);
        
        let query;
        let request = pool.request();
        
        if (playlistId) {
          query = `
            SELECT 
              t.ID as id, 
              t.Name as name, 
              t.Artist as artist, 
              t.Genre as genre, 
              t.Duration as duration, 
              t.CoverImageUrl as coverImageUrl, 
              t.AudioFileUrl as audioFileUrl
            FROM Tracks t
            JOIN playlist_tracks pt ON t.ID = pt.trackId
            WHERE pt.playlistId = @playlistId
          `;
          request.input('playlistId', sql.Int, playlistId);
        } else {
          query = `
            SELECT 
              ID as id, 
              Name as name, 
              Artist as artist, 
              Genre as genre, 
              Duration as duration, 
              CoverImageUrl as coverImageUrl, 
              AudioFileUrl as audioFileUrl
            FROM Tracks
          `;
        }
        
        const result = await request.query(query);
        const tracks = result.recordset;
      
        if (userId && tracks.length > 0) {
          const trackIds = tracks.map(track => track.id);
          
          const likedResult = await pool
            .request()
            .input('userId', sql.Int, userId)
            .query(`
              SELECT trackId 
              FROM favorite_tracks 
              WHERE userId = @userId AND trackId IN (${trackIds.join(',')})
            `);
          
          const likedTrackIds = new Set(likedResult.recordset.map(item => item.trackId));
          
          tracks.forEach(track => {
            track.isLiked = likedTrackIds.has(track.id);
          });
        } else {
          tracks.forEach(track => {
            track.isLiked = false;
          });
        }
        
        return tracks;
      } catch (error) {
        console.error('Error in tracks query:', error);
        throw new GraphQLError('Failed to fetch tracks');
      }
    },
    
    recentlyPlayed: async (_, { limit = 10 }, { userId }) => {
      if (!userId) throw new GraphQLError('Not authenticated');
      
      try {
        const pool = await sql.connect(dbConfig);
        const result = await pool
          .request()
          .input('userId', sql.Int, userId)
          .input('limit', sql.Int, limit)
          .query(`
            SELECT TOP (@limit)
              lh.id,
              lh.listenedAt,
              lh.completed,
              t.ID as 'track.id',
              t.Name as 'track.name',
              t.Artist as 'track.artist',
              t.Genre as 'track.genre',
              t.Duration as 'track.duration',
              t.CoverImageUrl as 'track.coverImageUrl',
              t.AudioFileUrl as 'track.audioFileUrl'
            FROM listening_history lh
            JOIN Tracks t ON lh.trackId = t.ID
            WHERE lh.userId = @userId
            ORDER BY lh.listenedAt DESC
          `);
        
        return result.recordset.map(record => ({
          id: record.id,
          listenedAt: record.listenedAt,
          completed: record.completed,
          track: {
            id: record['track.id'],
            name: record['track.name'],
            artist: record['track.artist'],
            genre: record['track.genre'],
            duration: record['track.duration'],
            coverImageUrl: record['track.coverImageUrl'],
            audioFileUrl: record['track.audioFileUrl']
          }
        }));
      } catch (error) {
        console.error('Error in recentlyPlayed query:', error);
        throw new GraphQLError('Failed to fetch recently played tracks');
      }
    },
    
    favoriteTracks: async (_, { userId }, context) => {
      const userIdToUse = userId || context.userId;
      
      if (!userIdToUse) throw new GraphQLError('Not authenticated');
      
      try {
        console.log(`Fetching favorite tracks for userId: ${userIdToUse}`);
        const pool = await sql.connect(dbConfig);
        const result = await pool
          .request()
          .input('userId', sql.Int, userIdToUse)
          .query(`
            SELECT 
              ft.id,
              ft.addedAt,
              t.ID as 'track.id',
              t.Name as 'track.name',
              t.Artist as 'track.artist',
              t.Genre as 'track.genre',
              t.Duration as 'track.duration',
              t.CoverImageUrl as 'track.coverImageUrl',
              t.AudioFileUrl as 'track.audioFileUrl'
            FROM favorite_tracks ft
            JOIN Tracks t ON ft.trackId = t.ID
            WHERE ft.userId = @userId
            ORDER BY ft.addedAt DESC
          `);
        
        console.log(`Found ${result.recordset.length} favorite tracks`);
        return result.recordset.map(record => ({
          id: record.id,
          addedAt: record.addedAt,
          track: {
            id: record['track.id'],
            name: record['track.name'],
            artist: record['track.artist'],
            genre: record['track.genre'],
            duration: record['track.duration'],
            coverImageUrl: record['track.coverImageUrl'],
            audioFileUrl: record['track.audioFileUrl'],
            isLiked: true
          }
        }));
      } catch (error) {
        console.error('Error in favoriteTracks query:', error);
        throw new GraphQLError('Failed to fetch favorite tracks');
      }
    },
    
    search: async (_, { query, type }, { userId }) => {
      try {
        const pool = await sql.connect(dbConfig);
        const searchTerm = `%${query}%`;
        const results = { tracks: [], playlists: [], artists: [] };
        
        if (!type || type === 'all' || type === 'track') {
          const tracksResult = await pool
            .request()
            .input('searchTerm', sql.NVarChar, searchTerm)
            .query(`
              SELECT 
                ID as id, 
                Name as name, 
                Artist as artist, 
                Genre as genre, 
                Duration as duration, 
                CoverImageUrl as coverImageUrl, 
                AudioFileUrl as audioFileUrl
              FROM Tracks
              WHERE Name LIKE @searchTerm OR Artist LIKE @searchTerm OR Genre LIKE @searchTerm
              ORDER BY Name
            `);
          
          const tracks = tracksResult.recordset;
          
          if (userId && tracks.length > 0) {
            const trackIds = tracks.map(track => track.id);
            
            const likedResult = await pool
              .request()
              .input('userId', sql.Int, userId)
              .query(`
                SELECT trackId 
                FROM favorite_tracks 
                WHERE userId = @userId AND trackId IN (${trackIds.length ? trackIds.join(',') : 0})
              `);
            
            const likedTrackIds = new Set(likedResult.recordset.map(item => item.trackId));
            
            tracks.forEach(track => {
              track.isLiked = likedTrackIds.has(track.id);
            });
          } else {
            tracks.forEach(track => {
              track.isLiked = false;
            });
          }
          
          results.tracks = tracks;
        }
        
        if (!type || type === 'all' || type === 'playlist') {
          const playlistsResult = await pool
            .request()
            .input('searchTerm', sql.NVarChar, searchTerm)
            .query(`
              SELECT p.id, p.name, p.subtitle, p.artist, p.imageUrl, p.userId, p.CreatedAt,
                     COUNT(pt.trackId) as trackCount
              FROM playlists p
              LEFT JOIN playlist_tracks pt ON p.id = pt.playlistId
              WHERE p.name LIKE @searchTerm OR p.artist LIKE @searchTerm
              GROUP BY p.id, p.name, p.subtitle, p.artist, p.imageUrl, p.userId, p.CreatedAt
              ORDER BY p.name
            `);
          
          results.playlists = playlistsResult.recordset;
        }
        
        if (!type || type === 'all' || type === 'artist') {
          const artistsResult = await pool
            .request()
            .input('searchTerm', sql.NVarChar, searchTerm)
            .query(`
              SELECT DISTINCT Artist as artist
              FROM Tracks
              WHERE Artist LIKE @searchTerm
              ORDER BY Artist
            `);
          
          results.artists = artistsResult.recordset.map(row => row.artist);
        }
        
        return results;
      } catch (error) {
        console.error('Error in search query:', error);
        throw new GraphQLError('Failed to perform search');
      }
    },
    
    getLocalizedStrings: async (_, { language }) => {
      try {
        const pool = await sql.connect(dbConfig);
        
        let langColumn;
        switch (language.toLowerCase()) {
          case 'ru': langColumn = 'ru_text'; break;
          case 'kk': langColumn = 'kk_text'; break;
          default: langColumn = 'en_text';
        }
        
        const result = await pool
          .request()
          .query(`
            SELECT key_name as key, ${langColumn} as value
            FROM localization
            WHERE ${langColumn} IS NOT NULL
          `);
        
        return result.recordset;
      } catch (error) {
        console.error('Error in getLocalizedStrings query:', error);
        throw new GraphQLError('Failed to fetch localized strings');
      }
    }
  },
  
  Mutation: {
    register: async (_, { name, email, password }) => {
      try {
        const pool = await sql.connect(dbConfig);
        
        const emailCheck = await pool
          .request()
          .input('email', sql.NVarChar, email)
          .query('SELECT 1 FROM users WHERE email = @email');
        
        if (emailCheck.recordset.length > 0) {
          throw new GraphQLError('Email already in use');
        }
        
        const hashedPassword = await hashPassword(password);
        
        const result = await pool
          .request()
          .input('name', sql.NVarChar, name)
          .input('email', sql.NVarChar, email)
          .input('password', sql.NVarChar, hashedPassword)
          .query(`
            INSERT INTO users (name, email, password_hash)
            OUTPUT INSERTED.user_id as id, INSERTED.name, INSERTED.email
            VALUES (@name, @email, @password)
          `);
        
        const newUser = result.recordset[0];
        
        await pool
          .request()
          .input('userId', sql.Int, newUser.id)
          .query(`
            INSERT INTO user_settings (userId, language, darkMode, audioQuality)
            VALUES (@userId, 'en', 1, 'normal')
          `);
        
        const token = generateToken(newUser);
        
        return { token, user: newUser };
      } catch (error) {
        console.error('Error in register mutation:', error);
        throw new GraphQLError('Registration failed');
      }
    },
    
    login: async (_, { email, password }) => {
      try {
        const pool = await sql.connect(dbConfig);
        
        const userResult = await pool
          .request()
          .input('email', sql.NVarChar, email)
          .query('SELECT user_id as id, name, email, password_hash FROM users WHERE email = @email');
        
        if (userResult.recordset.length === 0) {
          throw new GraphQLError('Invalid email or password');
        }
        
        const user = userResult.recordset[0];
        
        const passwordMatch = await comparePasswords(password, user.password_hash);
        if (!passwordMatch) {
          throw new GraphQLError('Invalid email or password');
        }
        
        const token = generateToken(user);
        
        return { 
          token, 
          user: { 
            id: user.id, 
            name: user.name, 
            email: user.email 
          } 
        };
      } catch (error) {
        console.error('Error in login mutation:', error);
        throw new GraphQLError('Login failed');
      }
    },
    
    updateProfile: async (_, { name, email }, { userId }) => {
      if (!userId) throw new GraphQLError('Not authenticated');
      
      try {
        const pool = await sql.connect(dbConfig);
        
        let updateQuery = 'UPDATE users SET ';
        const updates = [];
        const request = pool.request().input('userId', sql.Int, userId);
        
        if (name) {
          updates.push('name = @name');
          request.input('name', sql.NVarChar, name);
        }
        
        if (email) {
          const emailCheck = await pool
            .request()
            .input('email', sql.NVarChar, email)
            .input('userId', sql.Int, userId)
            .query('SELECT 1 FROM users WHERE email = @email AND user_id != @userId');
          
          if (emailCheck.recordset.length > 0) {
            throw new GraphQLError('Email already in use');
          }
          
          updates.push('email = @email');
          request.input('email', sql.NVarChar, email);
        }
        
        if (updates.length === 0) {
          throw new GraphQLError('No updates provided');
        }
        
        updateQuery += updates.join(', ');
        updateQuery += ' OUTPUT INSERTED.user_id as id, INSERTED.name, INSERTED.email WHERE user_id = @userId';
        
        const result = await request.query(updateQuery);
        
        if (result.recordset.length === 0) {
          throw new GraphQLError('User not found');
        }
        
        const settingsResult = await pool
          .request()
          .input('userId', sql.Int, userId)
          .query('SELECT language, darkMode, audioQuality FROM user_settings WHERE userId = @userId');
        
        const updatedUser = result.recordset[0];
        
        if (settingsResult.recordset.length > 0) {
          updatedUser.settings = settingsResult.recordset[0];
        } else {
          updatedUser.settings = {
            language: 'en',
            darkMode: true,
            audioQuality: 'normal'
          };
        }
        
        return updatedUser;
      } catch (error) {
        console.error('Error in updateProfile mutation:', error);
        throw new GraphQLError('Failed to update profile');
      }
    },
    
    updatePassword: async (_, { oldPassword, newPassword }, { userId }) => {
      if (!userId) throw new GraphQLError('Not authenticated');
      
      try {
        const pool = await sql.connect(dbConfig);
        
        const userResult = await pool
          .request()
          .input('userId', sql.Int, userId)
          .query('SELECT password_hash FROM users WHERE user_id = @userId');
        
        if (userResult.recordset.length === 0) {
          throw new GraphQLError('User not found');
        }
        
        const currentPasswordHash = userResult.recordset[0].password_hash;
        
        const passwordMatch = await comparePasswords(oldPassword, currentPasswordHash);
        if (!passwordMatch) {
          throw new GraphQLError('Current password is incorrect');
        }
        
        const newPasswordHash = await hashPassword(newPassword);
        
        await pool
          .request()
          .input('userId', sql.Int, userId)
          .input('passwordHash', sql.NVarChar, newPasswordHash)
          .query('UPDATE users SET password_hash = @passwordHash WHERE user_id = @userId');
        
        return true;
      } catch (error) {
        console.error('Error in updatePassword mutation:', error);
        throw new GraphQLError('Failed to update password');
      }
    },
    
    updateUserSettings: async (_, { language, darkMode, audioQuality }, { userId }) => {
      if (!userId) throw new GraphQLError('Not authenticated');
      
      try {
        const pool = await sql.connect(dbConfig);
        
        const checkResult = await pool
          .request()
          .input('userId', sql.Int, userId)
          .query('SELECT 1 FROM user_settings WHERE userId = @userId');
        
        const hasSettings = checkResult.recordset.length > 0;
        const request = pool.request().input('userId', sql.Int, userId);
        
        let updates = [];
        
        if (language !== undefined) {
          updates.push('language = @language');
          request.input('language', sql.NVarChar, language);
        }
        
        if (darkMode !== undefined) {
          updates.push('darkMode = @darkMode');
          request.input('darkMode', sql.Bit, darkMode ? 1 : 0);
        }
        
        if (audioQuality !== undefined) {
          updates.push('audioQuality = @audioQuality');
          request.input('audioQuality', sql.NVarChar, audioQuality);
        }
        
        if (updates.length === 0) {
          const settingsResult = await pool
            .request()
            .input('userId', sql.Int, userId)
            .query('SELECT language, darkMode, audioQuality FROM user_settings WHERE userId = @userId');
          
          return settingsResult.recordset.length > 0 
            ? settingsResult.recordset[0] 
            : { language: 'en', darkMode: true, audioQuality: 'normal' };
        }
        
        let query;
        if (hasSettings) {
          query = `
            UPDATE user_settings 
            SET ${updates.join(', ')} 
            OUTPUT INSERTED.language, INSERTED.darkMode, INSERTED.audioQuality 
            WHERE userId = @userId
          `;
        } else {
          const insertFields = [];
          const insertValues = [];
          
          insertFields.push('userId');
          insertValues.push('@userId');
          
          if (language !== undefined) {
            insertFields.push('language');
            insertValues.push('@language');
          } else {
            insertFields.push('language');
            insertValues.push("'en'");
          }
          
          if (darkMode !== undefined) {
            insertFields.push('darkMode');
            insertValues.push('@darkMode');
          } else {
            insertFields.push('darkMode');
            insertValues.push('1');
          }
          
          if (audioQuality !== undefined) {
            insertFields.push('audioQuality');
            insertValues.push('@audioQuality');
          } else {
            insertFields.push('audioQuality');
            insertValues.push("'normal'");
          }
          
          query = `
            INSERT INTO user_settings (${insertFields.join(', ')})
            OUTPUT INSERTED.language, INSERTED.darkMode, INSERTED.audioQuality
            VALUES (${insertValues.join(', ')})
          `;
        }
        
        const result = await request.query(query);
        return result.recordset[0];
      } catch (error) {
        console.error('Error in updateUserSettings mutation:', error);
        throw new GraphQLError('Failed to update user settings');
      }
    },
    
    createPlaylist: async (_, { name, subtitle, imageUrl }, { userId }) => {
      if (!userId) throw new GraphQLError('Not authenticated');
      
      try {
        const pool = await sql.connect(dbConfig);
        
        const result = await pool
          .request()
          .input('name', sql.NVarChar, name)
          .input('subtitle', sql.NVarChar, subtitle || null)
          .input('imageUrl', sql.NVarChar, imageUrl || null)
          .input('userId', sql.Int, userId)
          .query(`
            INSERT INTO playlists (name, subtitle, imageUrl, userId, CreatedAt)
            OUTPUT INSERTED.id, INSERTED.name, INSERTED.subtitle, INSERTED.imageUrl, INSERTED.userId, INSERTED.CreatedAt
            VALUES (@name, @subtitle, @imageUrl, @userId, GETDATE())
          `);
        
        const newPlaylist = result.recordset[0];
        newPlaylist.trackCount = 0;
        
        return newPlaylist;
      } catch (error) {
        console.error('Error in createPlaylist mutation:', error);
        throw new GraphQLError('Failed to create playlist');
      }
    },
    
    updatePlaylist: async (_, { playlistId, name, subtitle, imageUrl }, { userId }) => {
      if (!userId) throw new GraphQLError('Not authenticated');
      
      try {
        const pool = await sql.connect(dbConfig);
        
        const ownerCheck = await pool
          .request()
          .input('playlistId', sql.Int, playlistId)
          .input('userId', sql.Int, userId)
          .query('SELECT 1 FROM playlists WHERE id = @playlistId AND userId = @userId');
        
        if (ownerCheck.recordset.length === 0) {
          throw new GraphQLError('Playlist not found or you do not have permission to update it');
        }
        
        let updates = [];
        const request = pool.request()
          .input('playlistId', sql.Int, playlistId);
        
        if (name !== undefined) {
          updates.push('name = @name');
          request.input('name', sql.NVarChar, name);
        }
        
        if (subtitle !== undefined) {
          updates.push('subtitle = @subtitle');
          request.input('subtitle', sql.NVarChar, subtitle);
        }
        
        if (imageUrl !== undefined) {
          updates.push('imageUrl = @imageUrl');
          request.input('imageUrl', sql.NVarChar, imageUrl);
        }
        
        if (updates.length === 0) {
          throw new GraphQLError('No updates provided');
        }
        
        const query = `
          UPDATE playlists 
          SET ${updates.join(', ')} 
          OUTPUT INSERTED.id, INSERTED.name, INSERTED.subtitle, INSERTED.imageUrl, INSERTED.userId, INSERTED.CreatedAt
          WHERE id = @playlistId
        `;
        
        const result = await request.query(query);
        
        if (result.recordset.length === 0) {
          throw new GraphQLError('Playlist not found');
        }
        
        const countResult = await pool
          .request()
          .input('playlistId', sql.Int, playlistId)
          .query('SELECT COUNT(*) as count FROM playlist_tracks WHERE playlistId = @playlistId');
        
        const updatedPlaylist = result.recordset[0];
        updatedPlaylist.trackCount = countResult.recordset[0].count;
        
        return updatedPlaylist;
      } catch (error) {
        console.error('Error in updatePlaylist mutation:', error);
        throw new GraphQLError('Failed to update playlist');
      }
    },
    
    deletePlaylist: async (_, { playlistId }, { userId }) => {
      if (!userId) throw new GraphQLError('Not authenticated');
      
      try {
        const pool = await sql.connect(dbConfig);
        
        const ownerCheck = await pool
          .request()
          .input('playlistId', sql.Int, playlistId)
          .input('userId', sql.Int, userId)
          .query('SELECT 1 FROM playlists WHERE id = @playlistId AND userId = @userId');
        
        if (ownerCheck.recordset.length === 0) {
          throw new GraphQLError('Playlist not found or you do not have permission to delete it');
        }
        
        await pool
          .request()
          .input('playlistId', sql.Int, playlistId)
          .query('DELETE FROM playlists WHERE id = @playlistId');
        
        return true;
      } catch (error) {
        console.error('Error in deletePlaylist mutation:', error);
        throw new GraphQLError('Failed to delete playlist');
      }
    },
    
    addTrackToPlaylist: async (_, { playlistId, trackId }, { userId }) => {
      if (!userId) throw new GraphQLError('Not authenticated');
      
      try {
        const pool = await sql.connect(dbConfig);
        
        const ownerCheck = await pool
          .request()
          .input('playlistId', sql.Int, playlistId)
          .input('userId', sql.Int, userId)
          .query('SELECT 1 FROM playlists WHERE id = @playlistId AND userId = @userId');
        
        if (ownerCheck.recordset.length === 0) {
          throw new GraphQLError('Playlist not found or you do not have permission to modify it');
        }
        
        const trackCheck = await pool
          .request()
          .input('trackId', sql.Int, trackId)
          .query('SELECT 1 FROM Tracks WHERE ID = @trackId');
        
        if (trackCheck.recordset.length === 0) {
          throw new GraphQLError('Track not found');
        }
        
        const existsCheck = await pool
          .request()
          .input('playlistId', sql.Int, playlistId)
          .input('trackId', sql.Int, trackId)
          .query('SELECT 1 FROM playlist_tracks WHERE playlistId = @playlistId AND trackId = @trackId');
        
        if (existsCheck.recordset.length > 0) {
          throw new GraphQLError('Track is already in the playlist');
        }
        
        await pool
          .request()
          .input('playlistId', sql.Int, playlistId)
          .input('trackId', sql.Int, trackId)
          .query(`
            INSERT INTO playlist_tracks (playlistId, trackId, addedAt)
            VALUES (@playlistId, @trackId, GETDATE())
          `);
        
        return true;
      } catch (error) {
        console.error('Error in addTrackToPlaylist mutation:', error);
        throw new GraphQLError('Failed to add track to playlist');
      }
    },
    
    removeTrackFromPlaylist: async (_, { playlistId, trackId }, { userId }) => {
      if (!userId) throw new GraphQLError('Not authenticated');
      
      try {
        const pool = await sql.connect(dbConfig);
        
        const ownerCheck = await pool
          .request()
          .input('playlistId', sql.Int, playlistId)
          .input('userId', sql.Int, userId)
          .query('SELECT 1 FROM playlists WHERE id = @playlistId AND userId = @userId');
        
        if (ownerCheck.recordset.length === 0) {
          throw new GraphQLError('Playlist not found or you do not have permission to modify it');
        }
        
        await pool
          .request()
          .input('playlistId', sql.Int, playlistId)
          .input('trackId', sql.Int, trackId)
          .query('DELETE FROM playlist_tracks WHERE playlistId = @playlistId AND trackId = @trackId');
        
        return true;
      } catch (error) {
        console.error('Error in removeTrackFromPlaylist mutation:', error);
        throw new GraphQLError('Failed to remove track from playlist');
      }
    },
    
    likeTrack: async (_, { trackId }, { userId }) => {
      if (!userId) throw new GraphQLError('Not authenticated');
      
      try {
        const pool = await sql.connect(dbConfig);
        
        const trackCheck = await pool
          .request()
          .input('trackId', sql.Int, trackId)
          .query('SELECT 1 FROM Tracks WHERE ID = @trackId');
        
        if (trackCheck.recordset.length === 0) {
          throw new GraphQLError('Track not found');
        }
        
        const likeCheck = await pool
          .request()
          .input('userId', sql.Int, userId)
          .input('trackId', sql.Int, trackId)
          .query('SELECT 1 FROM favorite_tracks WHERE userId = @userId AND trackId = @trackId');
        
        if (likeCheck.recordset.length > 0) {
          return true; 
        }
        
        await pool
          .request()
          .input('userId', sql.Int, userId)
          .input('trackId', sql.Int, trackId)
          .query(`
            INSERT INTO favorite_tracks (userId, trackId, addedAt)
            VALUES (@userId, @trackId, GETDATE())
          `);
        
        return true;
      } catch (error) {
        console.error('Error in likeTrack mutation:', error);
        throw new GraphQLError('Failed to like track');
      }
    },
    
    unlikeTrack: async (_, { trackId }, { userId }) => {
      if (!userId) throw new GraphQLError('Not authenticated');
      
      try {
        const pool = await sql.connect(dbConfig);
        
        await pool
          .request()
          .input('userId', sql.Int, userId)
          .input('trackId', sql.Int, trackId)
          .query('DELETE FROM favorite_tracks WHERE userId = @userId AND trackId = @trackId');
        
        return true;
      } catch (error) {
        console.error('Error in unlikeTrack mutation:', error);
        throw new GraphQLError('Failed to unlike track');
      }
    },
    
    recordListening: async (_, { trackId, completed = false }, { userId }) => {
      if (!userId) throw new GraphQLError('Not authenticated');
      
      try {
        const pool = await sql.connect(dbConfig);
        
        const trackCheck = await pool
          .request()
          .input('trackId', sql.Int, trackId)
          .query('SELECT 1 FROM Tracks WHERE ID = @trackId');
        
        if (trackCheck.recordset.length === 0) {
          throw new GraphQLError('Track not found');
        }
        
        const result = await pool
          .request()
          .input('userId', sql.Int, userId)
          .input('trackId', sql.Int, trackId)
          .input('completed', sql.Bit, completed ? 1 : 0)
          .query(`
            INSERT INTO listening_history (userId, trackId, listenedAt, completed)
            OUTPUT INSERTED.id, INSERTED.listenedAt, INSERTED.completed, @trackId as trackId
            VALUES (@userId, @trackId, GETDATE(), @completed)
          `);
        
        if (result.recordset.length === 0) {
          throw new GraphQLError('Failed to record listening');
        }
        
        const record = result.recordset[0];
        
        const trackResult = await pool
          .request()
          .input('trackId', sql.Int, trackId)
          .query(`
            SELECT 
              ID as id, 
              Name as name, 
              Artist as artist, 
              Genre as genre, 
              Duration as duration, 
              CoverImageUrl as coverImageUrl, 
              AudioFileUrl as audioFileUrl
            FROM Tracks
            WHERE ID = @trackId
          `);
        
        return {
          id: record.id,
          listenedAt: record.listenedAt,
          completed: record.completed,
          track: trackResult.recordset[0]
        };
      } catch (error) {
        console.error('Error in recordListening mutation:', error);
        throw new GraphQLError('Failed to record listening history');
      }
    }
  },
  
  Playlist: {
    user: async (parent) => {
      try {
        const pool = await sql.connect(dbConfig);
        const result = await pool
          .request()
          .input('userId', sql.Int, parent.userId)
          .query('SELECT user_id as id, name, email FROM users WHERE user_id = @userId');
        
        return result.recordset.length > 0 ? result.recordset[0] : null;
      } catch (error) {
        console.error('Error resolving Playlist.user:', error);
        return null;
      }
    },
    
    tracks: async (parent, _, { userId }) => {
      try {
        const pool = await sql.connect(dbConfig);
        const result = await pool
          .request()
          .input('playlistId', sql.Int, parent.id)
          .query(`
            SELECT 
              t.ID as id, 
              t.Name as name, 
              t.Artist as artist, 
              t.Genre as genre, 
              t.Duration as duration, 
              t.CoverImageUrl as coverImageUrl, 
              t.AudioFileUrl as audioFileUrl
            FROM Tracks t
            JOIN playlist_tracks pt ON t.ID = pt.trackId
            WHERE pt.playlistId = @playlistId
            ORDER BY pt.addedAt DESC
          `);
        
        const tracks = result.recordset;
        
        if (userId && tracks.length > 0) {
          const trackIds = tracks.map(track => track.id);
          
          const likedResult = await pool
            .request()
            .input('userId', sql.Int, userId)
            .query(`
              SELECT trackId 
              FROM favorite_tracks 
              WHERE userId = @userId AND trackId IN (${trackIds.length ? trackIds.join(',') : 0})
            `);
          
          const likedTrackIds = new Set(likedResult.recordset.map(item => item.trackId));
          
          tracks.forEach(track => {
            track.isLiked = likedTrackIds.has(track.id);
          });
        } else {
          tracks.forEach(track => {
            track.isLiked = false;
          });
        }
        
        return tracks;
      } catch (error) {
        console.error('Error resolving Playlist.tracks:', error);
        return [];
      }
    }
  }
};
const app = express();

app.use('/static', express.static(path.join(__dirname, 'public')));

const server = new ApolloServer({
  typeDefs,
  resolvers,
  csrfPrevention: true,
});

async function startServer() {
  await server.start();
  
  app.use(
    '/graphql',
    cors(),
    bodyParser.json(),
    expressMiddleware(server, {
      context: async ({ req }) => {
        const token = req.headers.authorization || '';
        
        const userId = getUserIdFromToken(token.replace('Bearer ', ''));
        
        return { userId };
      },
    }),
  );
  
  const PORT = process.env.PORT || 4000;
  app.listen(PORT, () => {
    console.log(`🚀 Server ready at http://localhost:${PORT}`);
    console.log(`🚀 GraphQL endpoint available at http://localhost:${PORT}/graphql`);
  });
}

startServer().catch(error => {
  console.error('Error starting server:', error);
});
