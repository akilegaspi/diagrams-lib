{-# LANGUAGE TypeFamilies #-}
-- , NoMonomorphismRestriction

-----------------------------------------------------------------------------
-- |
-- Module      :  Diagrams.TwoD.Polygon
-- Copyright   :  (c) Brent Yorgey, Dmitry Olshansky 2011
-- License     :  BSD-style (see LICENSE)
-- Maintainer  :  byorgey@cis.upenn.edu, olshanskydr@gmail.com
-- Stability   :  experimental
-- Portability :  portable
--
-- Different 2D convex polygons and stars.
--
-- * Information about polygons: <http://en.wikipedia.org/wiki/Polygon>
-----------------------------------------------------------------------------

module Diagrams.TwoD.Polygons(
        -- * Poligon's construction 
        polyPolar, polySides, polyCyclic, polyRegular
        -- * Poligon's centers
        -- $centers
        , centroid
        -- * Stars
        -- | Star is a polygon which self-intersects in a regular way.
        --   It could consist of one or more stars (like David's Star)
        , star, starSkip
        -- * Orientation of polygons
        , orientX, orientY
        -- * Rounded polygons
        -- * Regular poligons
        -- * Well-known stars
        , star5, star6, starDavid, starSolomon
        -- * Rendering to 'Diagram's
        , polyPath, polyDiagram
        -- * Typed interface
        , PolyData(..), StarGroup(..), Orientation(..), PolyOption(..), poDef, polyPoints
    ) where

import Data.Ord(comparing)
import Data.List
import Control.Arrow ((&&&), (***))
import Control.Monad(guard)

import Data.VectorSpace  -- ((^/), sumV, magnitude, magnitudeSq, (<.>))
import Data.Default

import Diagrams.TwoD.Types
import Diagrams.TwoD.Transform
import Graphics.Rendering.Diagrams
import Diagrams.Path(pathFromVertices, stroke)

data PolyData = PolyPolar [Angle] [Double] |
                PolySides [Angle] [Double] |
                PolyCyclic [Angle] |
                PolyRegular Int
data StarGroup = StarFun (Int->Int) |
                 StarSkip Int
data Orientation = OrientX | OrientY | OrientNone                 

data PolyOption = PolyOption {
        poPolyData      :: PolyData
      , poStarGroup     :: StarGroup
      , poOrientation   :: Orientation
      , poCenter        :: P2
    }

instance Default PolyOption where
    def = PolyOption (PolyRegular 3) (StarSkip 1) OrientX origin
    
polyPoints :: PolyOption -> [[P2]]
polyPoints po = sg
    where
        ps = case poPolyData po of
            PolyPolar ans szs -> polyPolar ans szs
            PolySides ans szs -> polySides' ans szs
            PolyCyclic ans -> polyCyclic ans
            PolyRegular n -> polyRegular n
        ori = case poOrientation po of 
            OrientX -> orientX ps
            OrientY -> orientY ps
        tr = ori -- translate (poCenter .-. centroid ori) ori
        sg = case poStarGroup po of
            StarFun f -> star f tr
            StarSkip n -> starSkip n tr

-- | Polygon from some center given by central angles and edges length. 
--   There are /(n-1)/ angle and /n/ lengths for /n/-polygon.
--   Extra angles or lengths are ignored.
polyPolar :: [Angle] -> [Double] -> [P2]
polyPolar _ [] = []
polyPolar ans (l:ls) = snd $ unzip xs
    where
        xs = (l, translateX l origin) : zipWith3 (\a s (s',x) -> (s, scale (s/s') $ rotate a x)) ans ls xs

-- | Polygon given by side-lengths and vertex-angles. 
--   There are /(n-2)/ angle and /(n-1)/ lengths for /n/-polygon.
--   Extra angles or lengths are ignored.
polySides' :: [Angle] -> [Double] -> [P2]
polySides' ans ls = scanl (\p v -> p .+^ v) origin $ map (.-. origin) $ flip polyPolar ls $ map (pi-) ans 

-- | Polygon is centered around 'origin'.
polySides :: [Angle] -> [Double] -> [P2]
polySides ans ls = let p0 = polySides' ans ls in translate (origin .-. centroid p0) p0
   
{-
angle :: (InnerSpace v, s ~ Scalar v, Floating s) => v -> v -> s
angle v1 v2
    | m == 0 = 0
    | otherwise = acos $ sqrt $ (v1 <.> v2)^2 / m
    where
        m = magnitudeSq v1 * magnitudeSq v2
-}

-- | Polygon with vertexes on circle given by central edges.
--   There are just /(n-1)/ angle for /n/-polygon.
polyCyclic :: [Angle] -> [P2]
polyCyclic ans = polyPolar ans $ repeat 1

-- | Regular /n/-polygon
polyRegular :: Int -> [P2]
polyRegular n = polyCyclic $ take (n-1) $ repeat $ 2*pi / fromIntegral n

-- | Center of /n/-polygon as sum of vertexes divided by /n/
centroid :: [P2] -> P2
centroid = (origin .+^). uncurry (^/) . (sumV &&& (fromIntegral . length)) . map (.-. origin)

groups :: (Int->Int) -> Int -> [[Int]]
groups f n = unfoldr (\xs -> guard (not $ null xs) >> return (let zs = g (head xs) in (zs, xs \\ zs))) [0..n-1]
    where
        g x0 = snd $ last $ takeWhile (\(_,ys) -> ys == nub ys) $ iterate (\(k,ys) -> (f k `mod` n, k:ys)) (x0, [])
    
-- | Generate star from the list of points by function in Zn-ring.
star :: (Int->Int) -> [P2] -> [[P2]]
star f xs = map (map (xs!!)) $ groups f (length xs)

-- | Generate regular star by taking every /k/ point in cyclic list
starSkip :: Int -> [P2] -> [[P2]]
starSkip k = star (+k)

orient :: (Ord a) => Bool -> (R2 -> a) -> (Double -> P2 -> P2) -> [P2] -> [P2]
orient _ _ _ []= []
orient isMax fc ft xs = rotate a xs
    where
        mm = if isMax then maximumBy else minimumBy
        (x1,x,x2) = mm (comparing (\(_,(P z),_)->fc z)) $  zip3 (tail xs ++ take 1 xs) xs (last xs : init xs)
        x' = mm (comparing (\(P z)->fc z)) [x1, x2]
        v = x' .-. x
        ex = ft 1 origin .-. origin
        a = acos ((v <.> ex) / magnitude v)

-- | takes lowermost vertex then take its lowermost neighbor and make this side horisontally
orientX :: [P2] -> [P2]
orientX = orient True snd translateX
        
-- | takes leftmost vertex then take its leftmost neighbor and make this side vertically
orientY :: [P2] -> [P2]
orientY = orient False fst translateY
    
-- | Rounded polygons
-- | Regular poligons
-- | Well-known stars
star5 = starSkip 5
star6 = starSkip 6
starDavid = star5
starSolomon = starDavid

-- | Rendering to 'Diagram's
polyPathes = map pathFromVertices . polyPoints
polyDiagram = stroke . polyPath
        
-- $centers        
--  * Centroid is calculated by <http://en.wikipedia.org/wiki/Centroid#Of_a_finite_set_of_points>
--