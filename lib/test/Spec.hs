module Main (main) where

import Test.Hspec

import qualified AlignSpec
import qualified BacktestSpec
import qualified CoreVsReferenceSpec
import qualified MetricsSpec
import qualified TechnicalSpec
import qualified TrendFilterSpec

main :: IO ()
main = hspec $ do
  CoreVsReferenceSpec.spec
  AlignSpec.spec
  MetricsSpec.spec
  BacktestSpec.spec
  TechnicalSpec.spec
  TrendFilterSpec.spec
