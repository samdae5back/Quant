{-# LANGUAGE OverloadedStrings #-}
-- | quant: thin command line over the quant library.
--
--   quant fetch    --data DIR [--symbols SPY,BIL]        download indicators and prices into the cache
--   quant state    --data DIR --master SPY --out FILE    build the state panel and meta index
--   quant backtest --data DIR --strategy NAME ...        run a strategy and write a run directory
--
-- No strategy logic lives here; this file only wires configuration to the library.
module Main (main) where

import Control.Monad (forM, forM_, unless)
import qualified Data.Aeson as A
import qualified Data.ByteString.Lazy as BL
import Data.Maybe (fromMaybe)
import qualified Data.Text as T
import Data.Time.Calendar (Day)
import Data.Time.Clock (getCurrentTime, utctDay)
import Data.Time.Format (defaultTimeLocale, formatTime)
import qualified Data.Vector as V
import qualified Data.Vector.Storable as VS
import Network.HTTP.Client.TLS (newTlsManager)
import Options.Applicative
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)
import Text.Printf (printf)

import Quant.Backtest
import Quant.Core.Error (coreVersion)
import Quant.Core.Matrix (column)
import Quant.Data.Align (alignPanel)
import Quant.Data.Cache
import Quant.Data.Csv (parseDateValueCsv, parseCloseCsv, renderDateValueCsv, renderPanelCsv)
import Quant.Data.Fred (fetchFred)
import Quant.Data.Prices (fetchStooq)
import Quant.Indicator
import Quant.Indicators
import Quant.MetaIndex
import Quant.Metrics
import Quant.Report
import Quant.State (buildState)
import Quant.Strategies.BuyHold
import Quant.Strategies.RegimeTilt
import Quant.Strategies.TrendFilter
import Quant.Strategy
import Quant.Types

-- Options ----------------------------------------------------------------

data Cmd
  = Fetch FetchOpts
  | State StateOpts
  | Backtest BacktestOpts
  | Version

data FetchOpts = FetchOpts { fData :: FilePath, fSymbols :: [Symbol] }

data StateOpts = StateOpts
  { sData :: FilePath
  , sMaster :: Symbol
  , sWeighting :: Weighting
  , sOut :: FilePath
  }

data BacktestOpts = BacktestOpts
  { bData :: FilePath
  , bStrategy :: String
  , bConfig :: Maybe FilePath
  , bSymbols :: [Symbol]
  , bWeighting :: Weighting
  , bCostBps :: Double
  , bOut :: Maybe FilePath
  }

symbolsOpt :: Parser [Symbol]
symbolsOpt = map (Symbol . T.strip) . T.splitOn "," . T.pack
  <$> strOption (long "symbols" <> metavar "SYM,SYM" <> value "SPY,BIL" <> showDefault
                 <> help "comma separated tickers")

dataOpt :: Parser FilePath
dataOpt = strOption (long "data" <> metavar "DIR" <> value "data/sample" <> showDefault
                     <> help "data directory with fred/ and prices/ subdirectories")

weightingOpt :: Parser Weighting
weightingOpt = option (eitherReader parse)
  (long "weighting" <> metavar "equal|pca" <> value Equal <> help "meta index weighting (default: equal)")
  where
    parse "equal" = Right Equal
    parse "pca" = Right PCA
    parse other = Left ("unknown weighting: " ++ other)

cmdParser :: Parser Cmd
cmdParser = hsubparser
  ( command "fetch" (info (Fetch <$> (FetchOpts <$> dataOpt <*> symbolsOpt))
      (progDesc "Download the default indicators and the given tickers into the data directory"))
 <> command "state" (info (State <$> (StateOpts <$> dataOpt
        <*> (Symbol . T.pack <$> strOption (long "master" <> value "SPY" <> showDefault <> help "ticker whose dates form the index"))
        <*> weightingOpt
        <*> strOption (long "out" <> metavar "FILE" <> value "runs/state.csv" <> showDefault)))
      (progDesc "Build the standardized state panel and meta index, write them as CSV"))
 <> command "backtest" (info (Backtest <$> (BacktestOpts <$> dataOpt
        <*> strOption (long "strategy" <> metavar "buy-hold|regime-tilt" <> value "buy-hold" <> showDefault)
        <*> optional (strOption (long "config" <> metavar "FILE" <> help "JSON parameters for the strategy"))
        <*> symbolsOpt
        <*> weightingOpt
        <*> option auto (long "cost-bps" <> value 5 <> showDefault <> help "transaction cost for buy-hold")
        <*> optional (strOption (long "out" <> metavar "DIR" <> help "run directory (default: runs/<today>/<strategy>)"))))
      (progDesc "Run a strategy on cached data and report metrics"))
 <> command "version" (info (pure Version) (progDesc "Print library versions"))
  )

main :: IO ()
main = do
  cmd <- execParser (info (cmdParser <**> helper)
           (fullDesc <> header "quant - macro state vector, meta index and regime strategies"))
  case cmd of
    Version -> putStrLn ("quant 0.1.0, quant-core C library " ++ coreVersion)
    Fetch o -> runFetch o
    State o -> runState o
    Backtest o -> runBacktestCmd o

-- Fetch ------------------------------------------------------------------

runFetch :: FetchOpts -> IO ()
runFetch o = do
  mgr <- newTlsManager
  let dd = DataDir (fData o)
      inds = defaultIndicators
  forM_ (fredSeriesNeeded inds) $ \sid -> do
    r <- withCache (fredPath dd sid) (fmap (fmap fst) (fetchFred mgr sid))
    report ("FRED " ++ T.unpack (unSeriesId sid)) r
  forM_ (priceSymbolsNeeded inds ++ fSymbols o) $ \sym -> do
    r <- withCache (pricePath dd sym) (fmap (fmap fst) (fetchStooq mgr sym))
    report ("price " ++ T.unpack (unSymbol sym)) r
  where
    report label (Right _) = putStrLn ("ok    " ++ label)
    report label (Left e) = hPutStrLn stderr ("FAIL  " ++ label ++ ": " ++ e)

-- Shared loaders ---------------------------------------------------------

loadPriceSeries :: DataDir -> Symbol -> IO TimeSeries
loadPriceSeries dd sym = do
  bs <- readCached (pricePath dd sym)
  case bs of
    Nothing -> die' ("no cached prices for " ++ T.unpack (unSymbol sym) ++ "; run `quant fetch` first")
    Just b -> either (die' . (("prices " ++ T.unpack (unSymbol sym) ++ ": ") ++)) pure (parseCloseCsv b)

loadIndicatorSeries :: DataDir -> Indicator -> IO TimeSeries
loadIndicatorSeries dd ind = case indSource ind of
  Price sym -> loadPriceSeries dd sym
  Fred sid -> do
    bs <- readCached (fredPath dd sid)
    case bs of
      Nothing -> die' ("no cached FRED series " ++ T.unpack (unSeriesId sid) ++ "; run `quant fetch` first")
      Just b -> either (die' . (("FRED " ++ T.unpack (unSeriesId sid) ++ ": ") ++)) pure (parseDateValueCsv b)

-- | Price panel on the master symbol's dates, forward-filled by as-of join.
loadPricePanel :: DataDir -> [Symbol] -> IO Panel
loadPricePanel dd syms = do
  series <- forM syms (loadPriceSeries dd)
  case series of
    [] -> die' "no symbols given"
    (master : _) ->
      either die' pure (alignPanel (tsDates master) (zip (map unSymbol syms) series))

buildStatePanel :: DataDir -> V.Vector Day -> IO Panel
buildStatePanel dd dates = do
  pairs <- forM defaultIndicators $ \ind -> (,) ind <$> loadIndicatorSeries dd ind
  either die' pure (buildState dates pairs)

-- State ------------------------------------------------------------------

runState :: StateOpts -> IO ()
runState o = do
  let dd = DataDir (sData o)
  master <- loadPriceSeries dd (sMaster o)
  state <- buildStatePanel dd (tsDates master)
  w <- either (die' . show) pure (weights (sWeighting o) state)
  let meta = metaIndex w state
      metaTs = either error id (mkTimeSeries (zip (V.toList (pDates state)) (VS.toList meta)))
  BL.writeFile (sOut o) (renderPanelCsv state)
  BL.writeFile (sOut o ++ ".meta.csv") (renderDateValueCsv metaTs)
  putStrLn ("state panel: " ++ show (panelLength state) ++ " dates x " ++ show (V.length (pNames state))
            ++ " indicators -> " ++ sOut o)
  putStrLn "weights:"
  forM_ (zip (V.toList (pNames state)) (VS.toList w)) $ \(n, x) -> kv ("  " ++ T.unpack n) (printf "%8.4f" x)

-- Backtest ---------------------------------------------------------------

runBacktestCmd :: BacktestOpts -> IO ()
runBacktestCmd o = do
  let dd = DataDir (bData o)
  (strat, needsMeta) <- case bStrategy o of
    "buy-hold" -> pure (buyHold (bSymbols o) (Bps (bCostBps o)), False)
    "regime-tilt" -> do
      path <- maybe (die' "regime-tilt needs --config FILE") pure (bConfig o)
      params <- A.eitherDecodeFileStrict path >>= either (die' . ("config: " ++)) pure
      pure (regimeTilt params, True)
    "trend-filter" -> do
      path <- maybe (die' "trend-filter needs --config FILE") pure (bConfig o)
      params <- A.eitherDecodeFileStrict path >>= either (die' . ("config: " ++)) pure
      pure (trendFilter params, False)
    other -> die' ("unknown strategy: " ++ other)

  prices <- loadPricePanel dd (stratUniverse strat)
  meta <- if not needsMeta then pure Nothing else do
    state <- buildStatePanel dd (pDates prices)
    w <- either (die' . show) pure (weights (bWeighting o) state)
    pure (Just (metaIndex w state))

  result <- either (die' . show) pure (runBacktest strat (StrategyInput prices Nothing meta))
  let m = metrics (brEquity result) (brTurnover result)
  today <- utctDay <$> getCurrentTime
  let outDir = fromMaybe ("runs/" ++ formatTime defaultTimeLocale "%Y-%m-%d" today ++ "/" ++ bStrategy o) (bOut o)
  writeRun outDir result m

  kv "strategy" (T.unpack (brStrategy result))
  kv "period" (show (V.head (brDates result)) ++ " .. " ++ show (V.last (brDates result))
               ++ " (" ++ show (V.length (brDates result)) ++ " bars)")
  kv "total return" (pct (mTotalReturn m))
  kv "cagr" (pct (mCagr m))
  kv "ann. vol" (pct (mAnnualizedVol m))
  kv "sharpe" (printf "%8.2f" (mSharpe m))
  kv "max drawdown" (pct (mMaxDrawdown m))
  kv "avg turnover" (printf "%8.4f" (mAvgTurnover m))
  forM_ (zip [0 ..] (stratUniverse strat)) $ \(j, sym) ->
    kv ("avg w " ++ T.unpack (unSymbol sym)) (printf "%8.4f" (VS.sum (column (brWeights result) j) / fromIntegral (V.length (brDates result))))
  putStrLn ("written: " ++ outDir ++ "/equity.csv, summary.json")
  unless (VS.all (not . isNaN) (brEquity result)) $
    hPutStrLn stderr "warning: equity curve contains NaN; check for gaps in the price data"

kv :: String -> String -> IO ()
kv k v = putStrLn (k ++ replicate (max 1 (14 - length k)) ' ' ++ v)

pct :: Double -> String
pct x = printf "%8.2f%%" (100 * x)

die' :: String -> IO a
die' msg = hPutStrLn stderr ("error: " ++ msg) >> exitFailure
