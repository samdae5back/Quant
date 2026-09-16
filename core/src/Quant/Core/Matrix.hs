-- | A dense row-major matrix over unboxed, pinned storage.
--
-- This is the one Haskell type that knows the C layout convention:
-- element @(i, j)@ of an @r x c@ matrix lives at offset @i * c + j@.
-- Everything else in the project goes through this module.
module Quant.Core.Matrix
  ( Matrix (..)
  , rows
  , cols
  , fromRows
  , fromColumns
  , toRows
  , toColumns
  , fromList
  , generate
  , (!)
  , row
  , column
  , mapMatrix
  , transpose
  , identity
  , zeros
  , unsafeWithMatrix
  ) where

import qualified Data.Vector.Storable as VS
import Foreign.Ptr (Ptr)

-- | Row-major dense matrix. The invariant @VS.length mData == mRows * mCols@
-- is maintained by the smart constructors in this module.
data Matrix = Matrix
  { mRows :: !Int
  , mCols :: !Int
  , mData :: !(VS.Vector Double)
  }
  deriving (Eq, Show)

rows, cols :: Matrix -> Int
rows = mRows
cols = mCols

-- | Build from a list of equal-length rows. Ragged input is an error.
fromRows :: [[Double]] -> Matrix
fromRows [] = Matrix 0 0 VS.empty
fromRows rs@(r0 : _)
  | all ((== c) . length) rs = Matrix (length rs) c (VS.fromList (concat rs))
  | otherwise = error "Quant.Core.Matrix.fromRows: ragged rows"
  where c = length r0

-- | Build from a list of equal-length columns.
fromColumns :: [VS.Vector Double] -> Matrix
fromColumns [] = Matrix 0 0 VS.empty
fromColumns cs@(c0 : _)
  | all ((== r) . VS.length) cs =
      Matrix r k (VS.generate (r * k) (\i -> let (a, b) = i `quotRem` k in (cs !! b) VS.! a))
  | otherwise = error "Quant.Core.Matrix.fromColumns: ragged columns"
  where
    r = VS.length c0
    k = length cs

fromList :: Int -> Int -> [Double] -> Matrix
fromList r c xs
  | length xs == r * c = Matrix r c (VS.fromList xs)
  | otherwise = error "Quant.Core.Matrix.fromList: size mismatch"

generate :: Int -> Int -> (Int -> Int -> Double) -> Matrix
generate r c f = Matrix r c (VS.generate (r * c) (\i -> let (a, b) = i `quotRem` c in f a b))

toRows :: Matrix -> [VS.Vector Double]
toRows m = [row m i | i <- [0 .. mRows m - 1]]

toColumns :: Matrix -> [VS.Vector Double]
toColumns m = [column m j | j <- [0 .. mCols m - 1]]

infixl 9 !
(!) :: Matrix -> (Int, Int) -> Double
Matrix _ c v ! (i, j) = v VS.! (i * c + j)

-- | Zero-copy slice of row @i@.
row :: Matrix -> Int -> VS.Vector Double
row (Matrix _ c v) i = VS.slice (i * c) c v

-- | Copy of column @j@.
column :: Matrix -> Int -> VS.Vector Double
column (Matrix r c v) j = VS.generate r (\i -> v VS.! (i * c + j))

mapMatrix :: (Double -> Double) -> Matrix -> Matrix
mapMatrix f (Matrix r c v) = Matrix r c (VS.map f v)

transpose :: Matrix -> Matrix
transpose m@(Matrix r c _) = generate c r (\i j -> m ! (j, i))

identity :: Int -> Matrix
identity n = generate n n (\i j -> if i == j then 1 else 0)

zeros :: Int -> Int -> Matrix
zeros r c = Matrix r c (VS.replicate (r * c) 0)

-- | Pass the underlying buffer to C without copying.
unsafeWithMatrix :: Matrix -> (Ptr Double -> IO a) -> IO a
unsafeWithMatrix (Matrix _ _ v) = VS.unsafeWith v
