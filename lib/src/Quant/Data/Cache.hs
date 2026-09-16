-- | A flat-file cache: one CSV per series under a data directory.
--
-- Layout: @<dataDir>/fred/<SERIES>.csv@ and @<dataDir>/prices/<SYMBOL>.csv@.
-- The sample data shipped in @data/sample@ follows the same layout, so the
-- CLI can run offline against it.
module Quant.Data.Cache
  ( DataDir (..)
  , fredPath
  , pricePath
  , readCached
  , writeCached
  , withCache
  ) where

import qualified Data.ByteString.Lazy as BL
import qualified Data.Text as T
import System.Directory (createDirectoryIfMissing, doesFileExist)
import System.FilePath (takeDirectory, (<.>), (</>))

import Quant.Types

newtype DataDir = DataDir { unDataDir :: FilePath }
  deriving (Eq, Show)

fredPath :: DataDir -> SeriesId -> FilePath
fredPath (DataDir d) (SeriesId s) = d </> "fred" </> T.unpack s <.> "csv"

pricePath :: DataDir -> Symbol -> FilePath
pricePath (DataDir d) (Symbol s) = d </> "prices" </> T.unpack (T.toUpper s) <.> "csv"

readCached :: FilePath -> IO (Maybe BL.ByteString)
readCached path = do
  exists <- doesFileExist path
  if exists then Just <$> BL.readFile path else pure Nothing

writeCached :: FilePath -> BL.ByteString -> IO ()
writeCached path body = do
  createDirectoryIfMissing True (takeDirectory path)
  BL.writeFile path body

-- | Return the cached bytes if present, otherwise run the fetch action and
-- store its result. The fetch returns raw bytes so the cache stays a faithful
-- copy of the source.
withCache :: FilePath -> IO (Either String BL.ByteString) -> IO (Either String BL.ByteString)
withCache path fetch = do
  cached <- readCached path
  case cached of
    Just bs -> pure (Right bs)
    Nothing -> do
      r <- fetch
      case r of
        Right bs -> writeCached path bs >> pure (Right bs)
        Left e -> pure (Left e)
