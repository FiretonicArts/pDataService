--[[

This is a part of pDataService module script, this only configures the module nothing else.

]]

local Config = {}

-- Data store settings
Config.DataStoreKey = "CHANGE_ME" 
assert(Config.DataStoreKey ~= "CHANGE_ME", "DataStoreKey must be set!")

Config.DataVersion = "1.0.1" -- current version of module

-- Auto-saving settings
Config.AutoSaveInterval = 60 -- Time in seconds between automatic saves
Config.ProfileBackupInterval = 300 -- Time in seconds between backups

-- Request settings
Config.RequestRateLimit = 5 -- Minimum time in seconds between requests for the same player

-- Encryption settings
Config.EnableEncryption = true -- Enable or disable encryption
Config.EncryptionKey = 123 -- Key used for encryption/decryption (should be a number)
assert(type(Config.EncryptionKey) == "number", "EncryptionKey must be a number!")

-- Logging settings
Config.EnableLogging = true -- Enable or disable logging
Config.LogLevel = "INFO" -- Log level: INFO, WARNING, ERROR

-- Profile management settings
Config.MaxInactiveDuration = 3600 -- Maximum duration in seconds to keep inactive profiles in memory
Config.CleanupInterval = 600 -- Time in seconds between profile cleanup checks
Config.MaxBackupsPerPlayer = 5 -- Maximum number of backups to keep per player

Config.MaxRetries = 3 -- Maximum number of retries for saving/loading profiles
Config.UseBackup = true -- Whether to use backups for profiles
Config.BackupKeySuffix = "_backup" -- Suffix for backup keys
Config.CompressionEnabled = true -- Enable or disable data compression
Config.ProfileExpirationTime = 3600 -- Duration in seconds before profiles expire

return Config
